#requires -Version 5.1
# Ejecutar manualmente ANTES de montar el puente o arrancar el worker.
# Solo crea/protege directorios dentro de pset_2/.runtime; no lee secretos.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$runtime = Join-Path $root '.runtime'
$owner = [Security.Principal.WindowsIdentity]::GetCurrent().User
$system = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
foreach ($relative in @('', 'bridge', 'bridge\requests', 'bridge\results', 'batches')) {
    $path = if ($relative) { Join-Path $runtime $relative } else { $runtime }
    [void][IO.Directory]::CreateDirectory($path)
    if ((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Puente con reparse point: detener.' }
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetOwner($owner)
    $acl.SetAccessRuleProtection($true,$false)
    foreach ($sid in @($owner,$system)) {
        $rule = [Security.AccessControl.FileSystemAccessRule]::new(
            $sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow')
        $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $path -AclObject $acl
}
Write-Host 'Puente local preparado con acceso del usuario actual y SYSTEM. No hay puertos abiertos.'
