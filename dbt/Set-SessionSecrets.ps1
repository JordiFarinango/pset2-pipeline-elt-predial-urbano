# Dot-source manualmente en la sesion donde se ejecutara dbt.
# No lee la clave ni los archivos .env. Entradas ocultas; no hay persistencia.
function Set-Pset2SecretEnv([string]$name,[string]$prompt) {
    $secure = Read-Host $prompt -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        [Environment]::SetEnvironmentVariable($name,[Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer),'Process')
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        $secure.Dispose()
    }
}
try {
    if (-not $env:DBT_ENV_SECRET_PRIVATE_KEY_PATH) {
        Set-Pset2SecretEnv 'DBT_ENV_SECRET_PRIVATE_KEY_PATH' 'Ruta absoluta privada de la clave cifrada existente (entrada oculta)'
    }
    $pset2PrivatePath = [IO.Path]::GetFullPath($env:DBT_ENV_SECRET_PRIVATE_KEY_PATH)
    $pset2Root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\') + '\'
    if (-not [IO.Path]::IsPathRooted($env:DBT_ENV_SECRET_PRIVATE_KEY_PATH) -or
        $pset2PrivatePath.StartsWith($pset2Root,[StringComparison]::OrdinalIgnoreCase)) {
        throw 'RUTA_NO_AUTORIZADA'
    }
    Set-Pset2SecretEnv 'DBT_ENV_SECRET_PRIVATE_KEY_PASSPHRASE' 'Passphrase de la clave cifrada Snowflake para dbt'
} catch {
    Remove-Item Env:DBT_ENV_SECRET_PRIVATE_KEY_PATH,Env:DBT_ENV_SECRET_PRIVATE_KEY_PASSPHRASE -ErrorAction SilentlyContinue
    throw 'No se pudo configurar la sesion privada. Revisar ruta absoluta fuera del proyecto y entrada segura.'
} finally {
    Remove-Variable pset2PrivatePath,pset2Root -ErrorAction SilentlyContinue
    Remove-Item Function:Set-Pset2SecretEnv -ErrorAction SilentlyContinue
}
