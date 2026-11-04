[CmdletBinding()]
param(
    [string]$ApiBaseUrl = 'http://10.0.2.2:5278/',
    [string]$WebBaseUrl = 'http://10.0.2.2:4200/'
)
$ErrorActionPreference = 'Stop'
foreach ($address in @($ApiBaseUrl, $WebBaseUrl)) {
    $uri = [Uri]$address
    if (-not $uri.IsAbsoluteUri -or $uri.Scheme -notin @('http', 'https') -or
        $uri.UserInfo -or $uri.Query -or $uri.Fragment -or $uri.AbsolutePath -ne '/') {
        throw 'Informe a URL raiz da API e do site, sem /api ou outros caminhos.'
    }
}
$root = Split-Path $PSScriptRoot -Parent
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterPath = if ($flutterCommand) { $flutterCommand.Source } else {
    Join-Path $env:LOCALAPPDATA 'Programs\Flutter\bin\flutter.bat'
}
if (-not (Test-Path -LiteralPath $flutterPath)) {
    throw 'Flutter nao encontrado. Instale o SDK e adicione flutter/bin ao PATH.'
}
Push-Location $root
try {
    & $flutterPath pub get
    if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel resolver as dependencias.' }
    & $flutterPath build apk --debug "--dart-define=API_BASE_URL=$ApiBaseUrl" "--dart-define=WEB_BASE_URL=$WebBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao gerar APK.' }
    Write-Output ('APK de teste: ' + (Join-Path $root 'build\app\outputs\flutter-apk\app-debug.apk'))
}
finally { Pop-Location }
