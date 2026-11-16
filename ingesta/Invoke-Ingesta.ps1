#requires -Version 5.1
# Disparo manual de la ORQUESTACION; no ejecuta extractor ni SQL directamente.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][Guid]$LoteId,
    [string]$FiscalDesde = '2024-01-01',
    [string]$FiscalHasta = '2025-01-01',
    [ValidateRange(0,1000000)][int]$Limite = 10,
    [Parameter(Mandatory=$true)][string]$KestraEmail,
    [ValidateRange(1,65535)][int]$Port = 8080
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
$handler = $null; $client = $null; $credential = $null; $form = $null
try {
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $from = [datetime]::ParseExact($FiscalDesde,'yyyy-MM-dd',$culture)
    $until = [datetime]::ParseExact($FiscalHasta,'yyyy-MM-dd',$culture)
    if ($from -ge $until) { throw 'RANGO_INVALIDO' }
    $credential = Get-Credential -UserName $KestraEmail -Message 'Autenticacion local Kestra'
    if ($null -eq $credential) { throw 'CANCELADO' }
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.Credentials = $credential.GetNetworkCredential()
    $handler.PreAuthenticate = $true
    $handler.AllowAutoRedirect = $false
    $handler.UseProxy = $false
    $client = [Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(30)
    $form = [Net.Http.MultipartFormDataContent]::new()
    $values = @{lote_id=$LoteId.ToString('D');fiscal_desde=$FiscalDesde;fiscal_hasta=$FiscalHasta;limite=[string]$Limite}
    foreach ($key in $values.Keys) { $form.Add([Net.Http.StringContent]::new($values[$key]),$key) }
    $uri = "http://127.0.0.1:$Port/api/v1/main/executions/usfq.pset2/ingesta_raw_urbano"
    $response = $client.PostAsync($uri,$form).GetAwaiter().GetResult()
    if (-not $response.IsSuccessStatusCode) {
        Write-Host ('No se pudo iniciar el Flow. HTTP ' + [int]$response.StatusCode + '. Revisar importacion, puerto y autenticacion.')
        exit 1
    }
    $execution = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json
    Write-Host ('Ejecucion Kestra iniciada: ' + $execution.id)
    Write-Host ('Lote solicitado: ' + $LoteId.ToString('D') + '. Revisar estado final y resumen.json en Kestra.')
} catch {
    Write-Host 'No se pudo iniciar la ejecucion. Revisar parametros, credenciales locales y API de Kestra.'
    exit 1
} finally {
    if ($null -ne $form) { $form.Dispose() }
    if ($null -ne $client) { $client.Dispose() }
    if ($null -ne $handler) { $handler.Dispose() }
    if ($null -ne $credential) { $credential.Password.Dispose() }
}
