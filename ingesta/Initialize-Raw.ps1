#requires -Version 5.1
# Inicializacion MANUAL del destino con el propio rol de servicio.
# No consulta SQL Server y no ejecuta ingesta.
param([string]$Python = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$password = $null; $process = $null; $started = $false
try {
    if (-not $Python) { $Python = Join-Path $root '.venv\Scripts\python.exe' }
    if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) { throw 'PYTHON_NO_CONFIGURADO' }
    $password = Read-Host 'Passphrase de la clave privada Snowflake para preparar las tablas Raw' -AsSecureString
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = [IO.Path]::GetFullPath($Python)
    $info.Arguments = '-u "' + (Join-Path $PSScriptRoot 'load_raw.py') + '" --setup'
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.EnvironmentVariables['PYTHONDONTWRITEBYTECODE'] = '1'
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    try { $info.EnvironmentVariables['PSET2_SF_KEY_PASSWORD'] = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    [void]$process.Start()
    $started = $true
    $info.EnvironmentVariables.Remove('PSET2_SF_KEY_PASSWORD')
    $out = $process.StandardOutput.ReadToEndAsync()
    $err = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(180000)) { throw 'TIMEOUT' }
    $reply = $out.Result | ConvertFrom-Json
    if ($process.ExitCode -ne 0 -or $reply.status -ne 'success') { throw 'FALLO' }
    Write-Host 'Definiciones Raw preparadas y columnas comprobadas. No se extrajeron datos.'
} catch {
    Write-Host 'No se pudo preparar Raw. Revisar dependencia Python, ruta de clave cifrada y permisos CREATE TABLE del rol.'
    exit 1
} finally {
    if ($started -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
    if ($null -ne $process) { $process.Dispose() }
    if ($null -ne $password) { $password.Dispose() }
}
