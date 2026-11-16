#requires -Version 5.1
[CmdletBinding()]
param([string]$Python = '')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$contract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'contract.json') -Raw | ConvertFrom-Json
$invariant = [Globalization.CultureInfo]::InvariantCulture
$utf8 = [Text.UTF8Encoding]::new($false)
$runtime = Join-Path $root '.runtime'
$bridge = Join-Path $runtime 'bridge'
$requests = Join-Path $bridge 'requests'
$results = Join-Path $bridge 'results'
$batches = Join-Path $runtime 'batches'
$hmac = $null
$workerLock = $null
$credential = $null
$sfPassword = $null
$safeCodes = @(
    'CLAVE_NULA','ESQUEMA_FUENTE_CAMBIO','CONTEOS_NO_DISPONIBLES','SIN_OBLIGACIONES_EN_RANGO',
    'TOPE_LOCAL_EXCEDIDO','SOLICITUD_EXPIRADA','ORIGEN_DUPLICADO','CONTEOS_FUENTE_CAMBIARON',
    'SOLICITUD_INVALIDA','LOTE_INVALIDO','RANGO_INVALIDO','LIMITE_INVALIDO','LOTE_CON_OTRO_CONTRATO',
    'CARGADOR_SIN_RESPUESTA','CARGA_FALLIDA','PYTHON_NO_CONFIGURADO','RUTA_CLAVE_SNOWFLAKE_NO_CONFIGURADA',
    'TOPES_INVALIDOS','PREPARAR_PUENTE_PRIMERO','PUENTE_ACL_NO_RESTRINGIDA','PUENTE_REPARSE_NO_PERMITIDO',
    'CREDENCIAL_CANCELADA','HMAC_NO_REUTILIZAR_CREDENCIALES','HMAC_REQUIERE_32_BYTES',
    'PROTOCOLO_INCOMPLETO','VERSION_INVALIDA','KEY_TAG_INVALIDO','CAPTURA_NO_UTC','DESTINO_IDS_INVALIDOS',
    'DESTINO_HUERFANOS','ID_NULO','ID_INVALIDO','ANIO_INVALIDO','IMPORTE_INVALIDO','FECHA_INVALIDA',
    'CODIGO_INVALIDO','ESQUEMA_RAW_CAMBIO','CLAVE_DEBE_ESTAR_FUERA_DEL_PROYECTO',
    'CONTEXTO_DESTINO_INVALIDO','CAMBIO_HMAC_REQUIERE_NUEVA_VERSION','LEDGER_DUPLICADO',
    'REINTENTO_NO_RECONCILIA','FILAS_SIN_LEDGER','CAPTURA_NO_DECLARADA',
    'CONTEOS_FUENTE_NO_COINCIDEN','ORIGEN_HUERFANOS','PROYECCION_NO_PERMITIDA',
    'CONTEOS_DESTINO_NO_COINCIDEN','CARGA_FALLIDA_REVISAR_CONFIGURACION_Y_PERMISOS',
    'EXTRACCION_SELECT_FALLIDA','SQL_TRANSITORIO','SQL_AUTENTICACION_FALLIDA'
)

function Unseal([Security.SecureString]$secure) {
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}
function Id([object[]]$parts) {
    # JSON de un array de cadenas tipadas: sin concatenaciones ambiguas.
    $canonical = ConvertTo-Json -InputObject @($parts) -Compress -Depth 4
    $bytes = $utf8.GetBytes($canonical)
    $hash = $hmac.ComputeHash($bytes)
    return ([BitConverter]::ToString($hash)).Replace('-','').ToLowerInvariant()
}
function Key-Parts($reader) {
    foreach ($column in $contract.obligation_pk) {
        $value = $reader['U_' + $column]
        if ($value -is [DBNull]) { throw 'CLAVE_NULA' }
        switch ($column) {
            'CLAVE_CATASTRAL' { 'varchar'; [string]$value }
            'AVA_FECHA' { 'datetime'; $value.ToString('yyyy-MM-ddTHH:mm:ss.fffffff', $invariant) }
            default { 'numeric16_0'; $value.ToString('0', $invariant) }
        }
    }
}
function Write-JsonAtomic([string]$path, $value) {
    $temp = $path + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    [IO.File]::WriteAllText($temp, (ConvertTo-Json -InputObject $value -Depth 10 -Compress), $utf8)
    Move-Item -LiteralPath $temp -Destination $path -Force
}
function Send($process, $value) {
    # Escribir UTF-8 directamente: no depender de la pagina de codigos Windows
    # ni de StandardInputEncoding (no disponible en algunos .NET Framework).
    $json = ConvertTo-Json -InputObject $value -Depth 10 -Compress
    $bytes = $utf8.GetBytes($json + [char]10)
    $process.StandardInput.BaseStream.Write($bytes,0,$bytes.Length)
    $process.StandardInput.BaseStream.Flush()
}
function Read-Child($process) {
    $task = $process.StandardOutput.ReadLineAsync()
    if (-not $task.Wait(120000)) { throw 'CARGADOR_SIN_RESPUESTA' }
    if ([string]::IsNullOrWhiteSpace($task.Result)) { throw 'CARGADOR_SIN_RESPUESTA' }
    return ($task.Result | ConvertFrom-Json)
}
function Command($connection, [string]$sql, $manifest) {
    $cmd = $connection.CreateCommand()
    $cmd.CommandTimeout = 60
    $cmd.CommandText = $sql
    [void]$cmd.Parameters.Add('@desde', [Data.SqlDbType]::DateTime)
    [void]$cmd.Parameters.Add('@hasta', [Data.SqlDbType]::DateTime)
    [void]$cmd.Parameters.Add('@take', [Data.SqlDbType]::Int)
    $cmd.Parameters['@desde'].Value = [datetime]::ParseExact($manifest.fiscal_desde,'yyyy-MM-dd',$invariant)
    $cmd.Parameters['@hasta'].Value = [datetime]::ParseExact($manifest.fiscal_hasta,'yyyy-MM-dd',$invariant)
    $cmd.Parameters['@take'].Value = if ($manifest.limite -eq 0) { $maxU + 1 } else { $manifest.limite }
    return $cmd
}
function Check-Schema($reader) {
    $schema = $reader.GetSchemaTable()
    foreach ($prefix in @('U','P')) {
        $source = if ($prefix -eq 'U') { $contract.source.obligaciones } else { $contract.source.movimientos }
        foreach ($column in $source) {
            $ordinal = $reader.GetOrdinal($prefix + '_' + $column)
            $field = $schema.Rows[$ordinal]
            if ($column -eq 'CLAVE_CATASTRAL') { $expected = [string]; $width = 30 }
            elseif ($column -eq 'TIPO_DOC') { $expected = [string]; $width = 2 }
            elseif ($column -match '(ESTADO|CONDICION|TIPO)$') { $expected = [string]; $width = 1 }
            elseif ($column -match 'FECHA') { $expected = [datetime]; $width = 0 }
            else { $expected = [decimal]; $width = 0 }
            if ($reader.GetFieldType($ordinal) -ne $expected) { throw 'ESQUEMA_FUENTE_CAMBIO' }
            if ($expected -eq [string] -and $field.ColumnSize -ne $width) { throw 'ESQUEMA_FUENTE_CAMBIO' }
            if ($expected -eq [decimal]) {
                $scale = if ($column -in @('PRO_CODIGO','SECUENCIAL_AR','IMP_CODIGO')) { 0 } else { 2 }
                if ($field.NumericPrecision -ne 16 -or $field.NumericScale -ne $scale) { throw 'ESQUEMA_FUENTE_CAMBIO' }
            }
        }
    }
}
function Payload($reader, [string]$prefix, [string]$kind, [string]$obligation, [string]$movement) {
    $data = [ordered]@{}
    foreach ($field in $contract.raw.$kind) {
        switch ($field.name) {
            'OBLIGACION_ID' { $value = $obligation }
            'MOVIMIENTO_ID' { $value = $movement }
            'ANIO_FISCAL' { $value = [int]$reader['U_AVA_FECHA'].Year }
            default {
                $value = $reader[$prefix + '_' + $field.name]
                if ($value -is [DBNull]) { $value = $null }
                elseif ($field.type -eq 'money') { $value = $value.ToString('0.00',$invariant) }
                elseif ($field.type -eq 'date') { $value = $value.ToString('yyyy-MM-dd',$invariant) }
                else { $value = [string]$value }
            }
        }
        $data[$field.name] = $value
    }
    return @{kind=$kind;data=$data}
}
function Extract($manifest, $process) {
    $connection = $null; $reader = $null; $cmd = $null
    try {
        $builder = [Data.SqlClient.SqlConnectionStringBuilder]::new()
        $builder['Data Source'] = 'tcp:172.23.7.22,1433'
        $builder['Initial Catalog'] = 'sim2001'
        $builder['Encrypt'] = $true
        $builder['TrustServerCertificate'] = $true
        $builder['Pooling'] = $false
        $builder['Connect Timeout'] = 15
        $builder['ApplicationIntent'] = 'ReadOnly'
        $connection = [Data.SqlClient.SqlConnection]::new($builder.ConnectionString,
            [Data.SqlClient.SqlCredential]::new('sim2001',$credential.Password))
        $connection.Open()
        $columns = @($contract.source.obligaciones | ForEach-Object { '[' + $_ + ']' }) -join ','
        $order = @($contract.obligation_pk | ForEach-Object { '[' + $_ + ']' }) -join ','
        $cte = "WITH elegidas AS (SELECT TOP (@take) $columns FROM dbo.IMPUESTOS WHERE AVA_FECHA>=@desde AND AVA_FECHA<@hasta ORDER BY $order) "
        $join = @($contract.obligation_pk | ForEach-Object { "p.[$_]=u.[$_]" }) -join ' AND '
        # Ambas instrucciones son exclusivamente SELECT; no hay tablas temporales,
        # funciones municipales, procedimientos, NOLOCK ni configuracion de sesion.
        $countSql = $cte + "SELECT (SELECT COUNT_BIG(*) FROM elegidas) AS obligaciones, (SELECT COUNT_BIG(*) FROM elegidas u JOIN dbo.IMPUESTOS_PAGADOS p ON $join) AS movimientos"
        $cmd = Command $connection $countSql $manifest
        $reader = $cmd.ExecuteReader()
        if (-not $reader.Read()) { throw 'CONTEOS_NO_DISPONIBLES' }
        $expectedU = [long]$reader['obligaciones']; $expectedP = [long]$reader['movimientos']
        $reader.Dispose(); $reader = $null; $cmd.Dispose(); $cmd = $null
        if ($expectedU -eq 0) { throw 'SIN_OBLIGACIONES_EN_RANGO' }
        if ($expectedU -gt $maxU -or $expectedP -gt $maxP) { throw 'TOPE_LOCAL_EXCEDIDO' }
        $selectU = @($contract.source.obligaciones | ForEach-Object { "u.[$_] AS [U_$_]" }) -join ','
        $selectP = @($contract.source.movimientos | ForEach-Object { "p.[$_] AS [P_$_]" }) -join ','
        $sql = $cte + "SELECT $selectU,$selectP FROM elegidas u LEFT JOIN dbo.IMPUESTOS_PAGADOS p ON $join ORDER BY " +
            (@($contract.obligation_pk | ForEach-Object { "u.[$_]" }) -join ',') + ',p.IMP_CODIGO,p.IMP_FECHA_PAGO'
        $cmd = Command $connection $sql $manifest
        $reader = $cmd.ExecuteReader()
        Check-Schema $reader
        $uIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $pIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        while ($reader.Read()) {
            if ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -ge $manifest.expires) { throw 'SOLICITUD_EXPIRADA' }
            # Siempre canonizar las claves del padre SQL, no las variantes de
            # texto de la FK que SQL puede comparar con otra collation/espacios.
            $oid = Id (@($contract.id_version,'obligacion') + @(Key-Parts $reader))
            if ($uIds.Add($oid)) {
                if ($uIds.Count -gt $maxU) { throw 'TOPE_LOCAL_EXCEDIDO' }
                Send $process (Payload $reader 'U' 'obligaciones' $oid '')
            }
            if ($reader['P_IMP_CODIGO'] -isnot [DBNull]) {
                $paid = $reader['P_IMP_FECHA_PAGO']
                if ($paid -is [DBNull]) { throw 'CLAVE_NULA' }
                $mid = Id @($contract.id_version,'movimiento','obligacion_id',$oid,
                    'numeric16_0',$reader['P_IMP_CODIGO'].ToString('0',$invariant),
                    'datetime',$paid.ToString('yyyy-MM-ddTHH:mm:ss.fffffff',$invariant))
                if (-not $pIds.Add($mid)) { throw 'ORIGEN_DUPLICADO' }
                if ($pIds.Count -gt $maxP) { throw 'TOPE_LOCAL_EXCEDIDO' }
                Send $process (Payload $reader 'P' 'movimientos' $oid $mid)
            }
        }
        if ($uIds.Count -ne $expectedU -or $pIds.Count -ne $expectedP) { throw 'CONTEOS_FUENTE_CAMBIARON' }
        Send $process @{kind='end';obligaciones=$expectedU;movimientos=$expectedP}
    }
    catch {
        # No propagar mensajes del servidor, valores originales o SQL.
        $safe = $_.Exception.Message
        $cause = $_.Exception
        while ($cause -isnot [Data.SqlClient.SqlException] -and $null -ne $cause.InnerException) {
            $cause = $cause.InnerException
        }
        if ($cause -is [Data.SqlClient.SqlException]) {
            $numbers = @($cause.Errors | ForEach-Object { [int]$_.Number })
            # Timeout, deadlock, espera de bloqueo y cortes TCP conocidos.
            # Un error desconocido, certificado o permiso NO se reintenta.
            $transientNumbers = @(-2,1205,1222,10053,10054,10060)
            if ($numbers -contains 18456) { $safe = 'SQL_AUTENTICACION_FALLIDA' }
            elseif ($numbers.Count -gt 0 -and @($numbers | Where-Object { $_ -notin $transientNumbers }).Count -eq 0) {
                $safe = 'SQL_TRANSITORIO'
            }
        }
        if ($safeCodes -cnotcontains $safe) { $safe = 'EXTRACCION_SELECT_FALLIDA' }
        throw $safe
    }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
        if ($null -ne $cmd) { $cmd.Dispose() }
        if ($null -ne $connection) { $connection.Dispose() }
    }
}
function Process-Request($job) {
    if ((@($job.PSObject.Properties.Name | Sort-Object) -join ',') -ne 'expires,fiscal_desde,fiscal_hasta,limite,lote_id,request_id') { throw 'SOLICITUD_INVALIDA' }
    if ($job.request_id -notmatch '^[A-Za-z0-9_-]{1,80}$') { throw 'SOLICITUD_INVALIDA' }
    if ($job.lote_id -cne ([Guid]::Parse($job.lote_id).ToString('D'))) { throw 'LOTE_INVALIDO' }
    foreach ($field in @('fiscal_desde','fiscal_hasta')) {
        if ($job.$field -notmatch '^\d{4}-\d{2}-\d{2}$') { throw 'RANGO_INVALIDO' }
        $date = [datetime]::ParseExact($job.$field,'yyyy-MM-dd',$invariant)
        if ($date.Year -lt 1900 -or $date.Year -gt 2100) { throw 'RANGO_INVALIDO' }
    }
    if ($job.fiscal_desde -ge $job.fiscal_hasta) { throw 'RANGO_INVALIDO' }
    $limit = [int]$job.limite
    if ($limit -lt 0 -or $limit -gt $maxU) { throw 'LIMITE_INVALIDO' }
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ([long]$job.expires -le $now -or [long]$job.expires -gt ($now+1800)) { throw 'SOLICITUD_EXPIRADA' }
    $manifestPath = Join-Path $batches ($job.lote_id + '.json')
    if (Test-Path -LiteralPath $manifestPath) {
        $m = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        if ($m.fiscal_desde -ne $job.fiscal_desde -or $m.fiscal_hasta -ne $job.fiscal_hasta -or
            $m.limite -ne $limit -or $m.key_tag -cne $keyTag -or
            $m.id_version -ne $contract.id_version -or $m.contrato_version -ne $contract.version) { throw 'LOTE_CON_OTRO_CONTRATO' }
    } else {
        $m = [pscustomobject]@{
            lote_id=$job.lote_id; fiscal_desde=$job.fiscal_desde; fiscal_hasta=$job.fiscal_hasta; limite=$limit
            capturado_en=[datetime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fff'Z'",$invariant)
            id_version=$contract.id_version; contrato_version=$contract.version; key_tag=$keyTag
        }
        Write-JsonAtomic $manifestPath $m
    }
    # El manifiesto conserva la captura de inicio del lote aun si se reintenta.
    $m | Add-Member -NotePropertyName expires -NotePropertyValue ([long]$job.expires) -Force
    $m | Add-Member -NotePropertyName max_obligaciones -NotePropertyValue $maxU -Force
    $m | Add-Member -NotePropertyName max_movimientos -NotePropertyValue $maxP -Force
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $Python
    $info.Arguments = '-u "' + (Join-Path $PSScriptRoot 'load_raw.py') + '"'
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = $utf8
    $info.EnvironmentVariables['PYTHONIOENCODING'] = 'utf-8'
    $info.EnvironmentVariables['PYTHONDONTWRITEBYTECODE'] = '1'
    $info.EnvironmentVariables['PSET2_SF_KEY_PASSWORD'] = Unseal $sfPassword
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    $started = $false
    try {
        [void]$process.Start()
        $started = $true
        $info.EnvironmentVariables.Remove('PSET2_SF_KEY_PASSWORD')
        # Consumir stderr para que no bloquee; nunca copiarlo a logs/archivos.
        $stderr = $process.StandardError.ReadToEndAsync()
        Send $process $m
        $reply = Read-Child $process
        if ($reply.status -eq 'ready') {
            # Solo si no existe commit previo: registrar el inicio real de esta
            # captura. Un lote confirmado conserva su instante original.
            $m.capturado_en = [datetime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fff'Z'",$invariant)
            Write-JsonAtomic $manifestPath ($m | Select-Object lote_id,fiscal_desde,fiscal_hasta,limite,capturado_en,id_version,contrato_version,key_tag)
            Send $process @{kind='capture';capturado_en=$m.capturado_en}
            Extract $m $process
            $process.StandardInput.BaseStream.Close()
            $reply = Read-Child $process
        }
        if (-not $process.WaitForExit(120000)) { throw 'CARGADOR_SIN_RESPUESTA' }
        if ($process.ExitCode -ne 0 -or $reply.status -ne 'success') {
            if ($reply.PSObject.Properties.Name -contains 'error' -and $reply.error -match '^[A-Z][A-Z0-9_]{3,80}$') { throw $reply.error }
            throw 'CARGA_FALLIDA'
        }
        return $reply
    }
    finally {
        if ($started -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose()
    }
}

try {
    if ([string]::IsNullOrEmpty($Python)) { $Python = Join-Path $root '.venv\Scripts\python.exe' }
    if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) { throw 'PYTHON_NO_CONFIGURADO' }
    $Python = [IO.Path]::GetFullPath($Python)
    if ([string]::IsNullOrWhiteSpace($env:SNOWFLAKE_PRIVATE_KEY_FILE)) { throw 'RUTA_CLAVE_SNOWFLAKE_NO_CONFIGURADA' }
    $maxU = if ($env:PSET2_MAX_OBLIGACIONES) { [int]$env:PSET2_MAX_OBLIGACIONES } else { 10000 }
    $maxP = if ($env:PSET2_MAX_MOVIMIENTOS) { [int]$env:PSET2_MAX_MOVIMIENTOS } else { 100000 }
    if ($maxU -lt 1 -or $maxU -gt 1000000 -or $maxP -lt 1 -or $maxP -gt 10000000) { throw 'TOPES_INVALIDOS' }
    if (-not (Test-Path -LiteralPath $runtime -PathType Container)) { throw 'PREPARAR_PUENTE_PRIMERO' }
    $acl = Get-Acl -LiteralPath $runtime
    $ownerSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if (-not $acl.AreAccessRulesProtected) { throw 'PUENTE_ACL_NO_RESTRINGIDA' }
    foreach ($rule in $acl.Access) {
        $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
        if ($rule.AccessControlType -eq 'Allow' -and $sid -notin @($ownerSid,'S-1-5-18')) { throw 'PUENTE_ACL_NO_RESTRINGIDA' }
    }
    foreach ($directory in @($runtime,$bridge,$requests,$results,$batches)) {
        if (-not (Test-Path -LiteralPath $directory -PathType Container)) { throw 'PREPARAR_PUENTE_PRIMERO' }
        if ((Get-Item -LiteralPath $directory).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'PUENTE_REPARSE_NO_PERMITIDO' }
    }
    # Bloqueo exclusivo durante toda la vida del unico escritor local.
    $workerLock = [IO.File]::Open((Join-Path $runtime 'worker.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $credential = Get-Credential -UserName 'sim2001' -Message 'SQL Server de pruebas: solo SELECT'
    if ($null -eq $credential) { throw 'CREDENCIAL_CANCELADA' }
    $credential.Password.MakeReadOnly()
    $sfPassword = Read-Host 'Passphrase de la clave privada cifrada Snowflake (no se guarda)' -AsSecureString
    $keySecure = Get-Content -LiteralPath (Join-Path $HOME '.pset2_hmac_v1.dpapi') | ConvertTo-SecureString
    try {
        $keyText = Unseal $keySecure
        if ($keyText -ceq (Unseal $sfPassword) -or $keyText -ceq (Unseal $credential.Password)) { throw 'HMAC_NO_REUTILIZAR_CREDENCIALES' }
        $keyBytes = [Convert]::FromBase64String($keyText)
    } finally { $keySecure.Dispose(); $keyText = $null }
    if ($keyBytes.Length -ne 32) { throw 'HMAC_REQUIERE_32_BYTES' }
    $hmac = [Security.Cryptography.HMACSHA256]::new($keyBytes)
    [Array]::Clear($keyBytes,0,$keyBytes.Length)
    $keyTag = Id @($contract.id_version,'key-check')
    Write-Host 'Worker armado. Solo procesa solicitudes del Flow. Ctrl+C para detener entre lotes.'
    while ($true) {
        foreach ($file in Get-ChildItem -LiteralPath $requests -Filter '*.json' -File | Sort-Object LastWriteTimeUtc) {
            if ($file.BaseName -notmatch '^[A-Za-z0-9_-]{1,80}$' -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
            $resultPath = Join-Path $results ($file.BaseName + '.json')
            if (Test-Path -LiteralPath $resultPath) { continue }
            $timer = [Diagnostics.Stopwatch]::StartNew()
            try {
                if ($file.Length -gt 16384) { throw 'SOLICITUD_INVALIDA' }
                $job = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
                if ($job.request_id -cne $file.BaseName) { throw 'SOLICITUD_INVALIDA' }
                $reply = Process-Request $job
                $result = [ordered]@{
                    status='success'; lote_id=$job.lote_id; reutilizado=[bool]$reply.reutilizado
                    obligaciones=[long]$reply.obligaciones; movimientos=[long]$reply.movimientos
                    ids_nulos=0; duplicados=0; huerfanos=0
                    segundos=[math]::Round($timer.Elapsed.TotalSeconds,3)
                }
            } catch {
                $code = $_.Exception.Message
                if ($safeCodes -cnotcontains $code) { $code = 'WORKER_FALLO_SIN_DETALLE_SENSIBLE' }
                # Process-Request ya cerro lector/conexion y termino el hijo antes
                # de publicar este resultado. No reintentar resultados ambiguos.
                $result = @{status='failed';error=$code;retryable=($code -ceq 'SQL_TRANSITORIO');segundos=[math]::Round($timer.Elapsed.TotalSeconds,3)}
            }
            Write-JsonAtomic $resultPath $result
            Write-Host ('Solicitud ' + $file.BaseName + ': ' + $result.status)
        }
        Start-Sleep -Seconds 2
    }
} catch {
    # Sin mensajes internos, stack traces ni valores de configuracion.
    $code = $_.Exception.Message
    if ($safeCodes -cnotcontains $code) { $code = 'REVISAR_CONFIGURACION_DEPENDENCIAS_O_BLOQUEO' }
    Write-Host ('Worker detenido: ' + $code)
    exit 1
} finally {
    if ($null -ne $workerLock) { $workerLock.Dispose() }
    if ($null -ne $hmac) { $hmac.Dispose() }
    if ($null -ne $credential) { $credential.Password.Dispose() }
    if ($null -ne $sfPassword) { $sfPassword.Dispose() }
}
