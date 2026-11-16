#requires -Version 5.1
# Lanzador MANUAL. Nunca pone credenciales en argumentos ni muestra filas.
[CmdletBinding(DefaultParameterSetName='run')]
param(
    [Parameter(Mandatory=$true,ParameterSetName='run')][Guid]$LoteId,
    [Parameter(Mandatory=$true,ParameterSetName='setup')][switch]$PrepararTabla,
    [int]$EsperadasObligaciones = -1,
    [int]$EsperadosMovimientos = -1,
    [string]$Python = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$process = $null; $started = $false
try {
    if (-not $Python) { $Python = Join-Path $root '.venv\Scripts\python.exe' }
    if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) { throw 'PYTHON_NO_DISPONIBLE' }
    $runtime = Join-Path $root '.runtime'
    if (-not (Test-Path -LiteralPath $runtime -PathType Container)) { throw 'RUNTIME_PRIVADO_NO_PREPARADO' }
    if ((Get-Item -LiteralPath $runtime).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'RUNTIME_NO_SEGURO' }
    $acl = Get-Acl -LiteralPath $runtime
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if (-not $acl.AreAccessRulesProtected) { throw 'RUNTIME_NO_SEGURO' }
    foreach ($rule in $acl.Access) {
        if ($rule.AccessControlType -eq 'Allow' -and
            $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -notin @($sid,'S-1-5-18')) {
            throw 'RUNTIME_NO_SEGURO'
        }
    }
    if (-not $env:DBT_ENV_SECRET_PRIVATE_KEY_PATH -or -not $env:DBT_ENV_SECRET_PRIVATE_KEY_PASSPHRASE) {
        # Helper existente: solo solicita valores ocultos, no lee .env o la clave.
        . (Join-Path $root 'dbt\Set-SessionSecrets.ps1')
    }
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = [IO.Path]::GetFullPath($Python)
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $info.EnvironmentVariables['PYTHONIOENCODING'] = 'utf-8'
    $info.EnvironmentVariables['PYTHONDONTWRITEBYTECODE'] = '1'
    $arguments = '-u "' + (Join-Path $PSScriptRoot 'publish_obt.py') + '"'
    if ($PrepararTabla) { $arguments += ' --setup' }
    else {
        $arguments += ' --lote-id ' + $LoteId.ToString('D')
        if ($EsperadasObligaciones -ge 0) { $arguments += ' --expected-obligaciones ' + $EsperadasObligaciones }
        if ($EsperadosMovimientos -ge 0) { $arguments += ' --expected-movimientos ' + $EsperadosMovimientos }
    }
    $info.Arguments = $arguments
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    [void]$process.Start(); $started = $true
    $out = $process.StandardOutput.ReadToEndAsync()
    $err = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(1800000)) { throw 'TIEMPO_AGOTADO' }
    $result = $out.Result | ConvertFrom-Json
    # publish_obt publica exclusivamente un resumen, nunca el transporte de filas.
    if ($process.ExitCode -ne 0 -or $result.status -ne 'success') {
        $code = 'REVISAR_DEPENDENCIAS_CONFIGURACION_Y_PERMISOS'
        if ($result.error -match '^[A-Z][A-Z0-9_]{3,90}$') { $code = $result.error }
        Write-Host ('OBT no confirmada: ' + $code)
        exit 1
    }
    $result | ConvertTo-Json -Compress
} catch {
    Write-Host 'No se completo la OBT. Revisar runtime privado, Python, secretos de sesion y Docker Desktop.'
    exit 1
} finally {
    if ($started -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
    if ($null -ne $process) { $process.Dispose() }
}
