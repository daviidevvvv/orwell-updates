param(
    [string]$RemoteRepo = 'daviidevvvv/orwell-updates',
    [string]$Checkout,
    [switch]$PrepareOnly
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$remote = "https://github.com/$RemoteRepo.git"
if (!$Checkout) { $Checkout = Join-Path $root 'dist\orwell-updates' }
$Checkout = [IO.Path]::GetFullPath($Checkout)

function Invoke-Git {
    & git @args
    if ($LASTEXITCODE -ne 0) { throw "Git fallito ($LASTEXITCODE)." }
}

$manifest = Get-Content -LiteralPath (Join-Path $root 'web\version.json') -Raw | ConvertFrom-Json
$orwell = Join-Path $root 'Orwell.exe'
$hash = (Get-FileHash -LiteralPath $orwell -Algorithm SHA256).Hash
if ($manifest.frontend -ne 'gpui' -or $manifest.sha256 -ne $hash -or !$manifest.version) {
    throw 'Esegui src\build-gpui-ui.ps1 per ottenere eseguibile e manifesto corrispondenti.'
}
if (!(Test-Path -LiteralPath (Join-Path $Checkout '.git'))) {
    Invoke-Git clone --branch main $remote $Checkout
}
if ((Invoke-Git -C $Checkout remote get-url origin) -ne $remote -or
    (Invoke-Git -C $Checkout branch --show-current) -ne 'main' -or
    (Invoke-Git -C $Checkout status --porcelain)) {
    throw 'Il checkout del canale pubblico deve essere pulito e sul ramo main.'
}
Invoke-Git -C $Checkout pull --ff-only origin main

$files = @(
    'Orwell.exe', 'Avvia_Orwell.bat',
    'web\version.json', 'web\presets.js',
    'tools\update-from-main.ps1', 'tools\publish-updates.ps1'
)
$retired = @(
    'Telecamere.exe', 'Avvia_Telecamere.bat', 'bin/ClipExporter.exe',
    'web/dashboard.html', 'web/stream.html', 'web/video-rtc.js', 'web/video-stream.js',
    'web/orwell-icon.png', 'web/orwell-logo.png', 'tools/Apri_Pannello_Diagnostica.bat',
    'tools/Chiudi_Telecamere.bat', 'tools/Test_Camera_1_BAR.bat'
)
Invoke-Git -C $Checkout rm --ignore-unmatch -- @retired
foreach ($item in $files) {
    $destination = Join-Path $Checkout $item
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root $item) -Destination $destination -Force
}
$license = Join-Path $Checkout 'assets\Outfit-OFL.txt'
New-Item -ItemType Directory -Path (Split-Path -Parent $license) -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'gpui-ui\assets\Outfit-OFL.txt') -Destination $license -Force
$brand = Join-Path $Checkout 'assets\brand'
New-Item -ItemType Directory -Path $brand -Force | Out-Null
Get-ChildItem -LiteralPath (Join-Path $root 'assets\brand') -File | Where-Object Extension -in @('.png','.webp','.ico') |
    ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $brand -Force }

$readme = @(
    '# Orwell App Updates', '',
    "Orwell $($manifest.version) usa il frontend desktop nativo GPUI. Gli utenti di Orwell possono aggiornare dal pulsante ↑. Il canale include il manifesto, l'eseguibile GPUI e i file per migrare le installazioni precedenti.", ''
) -join [Environment]::NewLine
[IO.File]::WriteAllText((Join-Path $Checkout 'README.md'), $readme, [Text.UTF8Encoding]::new($false))
$publish = $files + @('README.md', 'assets/brand', 'assets/Outfit-OFL.txt')
Invoke-Git -C $Checkout add -- @publish
# The public channel maintains these policy files in its own checkout.
$allowed = ($publish -replace '\\','/') + @('AGENTS.md', 'CI_RESOURCE_POLICY.md')
$unexpected = Invoke-Git -C $Checkout ls-files | Where-Object {
    $_ -notin $allowed -and $_ -notmatch '^assets/brand/[^/]+\.(png|webp|ico)$'
}
if ($unexpected) { throw 'Il checkout pubblico contiene file fuori dalla lista di distribuzione.' }
$changed = Invoke-Git -C $Checkout diff --cached --name-only
if ($changed) {
    Invoke-Git -C $Checkout -c user.name=daviidevvvv -c user.email=daviidevvvv@users.noreply.github.com commit -m "Update Orwell $($manifest.version) distribution (GPUI)"
}
if (!$PrepareOnly) {
    Invoke-Git -C $Checkout -c 'credential.https://github.com.helper=!gh auth git-credential' push origin main
}
Invoke-Git -C $Checkout log -1 --format='%h %s'
