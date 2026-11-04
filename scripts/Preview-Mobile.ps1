[CmdletBinding()]
param(
    [int]$Port = 4300,
    [string]$ApiBaseUrl = 'http://localhost:5278/',
    [string]$WebBaseUrl = 'http://localhost:4200/'
)
$ErrorActionPreference = 'Stop'
$api = [Uri]$ApiBaseUrl
$web = [Uri]$WebBaseUrl
if ($Port -lt 1 -or $Port -gt 65535 -or -not $api.IsAbsoluteUri -or
    -not $api.IsLoopback -or $api.Scheme -ne 'http' -or $api.AbsolutePath -ne '/' -or
    $api.UserInfo -or $api.Query -or $api.Fragment) {
    throw 'Informe uma porta valida e a URL raiz da API HTTP local.'
}
if (-not $web.IsAbsoluteUri -or $web.Scheme -notin @('http','https') -or
    $web.AbsolutePath -ne '/' -or $web.UserInfo -or $web.Query -or $web.Fragment) {
    throw 'Informe a URL raiz do site.'
}
$busy = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners() |
    Where-Object { $_.Port -eq $Port }
if ($busy) { throw "Porta $Port em uso. Abra a previa existente ou escolha -Port diferente." }
$root = Split-Path $PSScriptRoot -Parent
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutter = if ($flutterCommand) { $flutterCommand.Source } else {
    Join-Path $env:LOCALAPPDATA 'Programs\Flutter\bin\flutter.bat'
}
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) { throw 'Node.js e necessario para o servidor local de previa.' }
$previewUrl = 'http://localhost:{0}/' -f $Port
Push-Location $root
$oldPort = $env:PIM4_PREVIEW_PORT
$oldApi = $env:PIM4_PREVIEW_API
try {
    & {
        if (-not (Test-Path -LiteralPath $flutter)) { throw 'Flutter nao encontrado.' }
        & $flutter build web --profile --no-web-resources-cdn --base-href /app/ "--dart-define=API_BASE_URL=$previewUrl" "--dart-define=WEB_BASE_URL=$WebBaseUrl"
        if ($LASTEXITCODE -ne 0) { throw 'Falha no build web do Flutter.' }
    }
    if (-not (Test-Path -LiteralPath 'build\web\main.dart.js')) { throw 'Build web ausente. Execute Preview-Mobile.ps1 novamente.' }
    $env:PIM4_PREVIEW_PORT = [string]$Port
    $env:PIM4_PREVIEW_API = $api.AbsoluteUri
    & $node.Source (Join-Path $PSScriptRoot 'preview-server.cjs')
    if ($LASTEXITCODE -ne 0) { throw 'O servidor de previa encerrou com erro.' }
}
finally {
    $env:PIM4_PREVIEW_PORT = $oldPort
    $env:PIM4_PREVIEW_API = $oldApi
    Pop-Location
}

