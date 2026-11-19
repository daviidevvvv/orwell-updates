param(
    [string]$RemoteRepo = 'daviidevvvv/orwell-updates'
)

$ErrorActionPreference = 'Stop'
$toolsDir = $PSScriptRoot
$root = Split-Path -Parent $toolsDir
$stage = Join-Path $env:TEMP ("orwell_pub_{0}" -f $PID)

if (Test-Path -LiteralPath $stage) {
    Remove-Item -LiteralPath $stage -Recurse -Force
}
New-Item -ItemType Directory -Path $stage -Force | Out-Null

try {
    foreach ($f in @('Orwell.exe', 'Avvia_Orwell.bat', 'Telecamere.exe', 'Avvia_Telecamere.bat')) {
        $src = Join-Path $root $f
        if (Test-Path -LiteralPath $src -PathType Leaf) {
            Copy-Item -LiteralPath $src -Destination (Join-Path $stage $f) -Force
        }
    }

    $binStage = Join-Path $stage 'bin'
    New-Item -ItemType Directory -Path $binStage -Force | Out-Null
    $clipExe = Join-Path $root 'bin\ClipExporter.exe'
    if (Test-Path -LiteralPath $clipExe -PathType Leaf) {
        Copy-Item -LiteralPath $clipExe -Destination (Join-Path $binStage 'ClipExporter.exe') -Force
    }

    foreach ($dirName in @('web', 'tools')) {
        $srcDir = Join-Path $root $dirName
        if (Test-Path -LiteralPath $srcDir -PathType Container) {
            Copy-Item -LiteralPath $srcDir -Destination $stage -Recurse -Force
        }
    }

    $brandSrc = Join-Path $root 'assets\brand'
    if (Test-Path -LiteralPath $brandSrc -PathType Container) {
        $assetsStage = Join-Path $stage 'assets'
        New-Item -ItemType Directory -Path $assetsStage -Force | Out-Null
        Copy-Item -LiteralPath $brandSrc -Destination $assetsStage -Recurse -Force
    }

    # Never include secrets/NVR config/auth tokens in public update mirror
    Remove-Item -LiteralPath (Join-Path $stage 'bin\go2rtc.yaml'), (Join-Path $stage 'bin\update-auth.json') -Force -ErrorAction SilentlyContinue

    $readmeText = @"
# Orwell App Updates

Canale pubblico per gli aggiornamenti dell'interfaccia e degli eseguibili desktop di **Orwell** (privo di credenziali o configurazioni NVR).
"@
    [System.IO.File]::WriteAllText((Join-Path $stage 'README.md'), $readmeText, [System.Text.UTF8Encoding]::new($false))

    Push-Location $stage
    try {
        & git init -b main | Out-Null
        & git config user.name "daviidevvvv"
        & git config user.email "daviidevvvv@users.noreply.github.com"
        & git add -A
        & git commit -m "Publish Orwell app update bundle" | Out-Null
        $remoteUrl = "https://github.com/$RemoteRepo.git"
        & git remote add origin $remoteUrl
        & git push -f origin main
        if ($LASTEXITCODE -ne 0) {
            throw "Push verso $remoteUrl fallito ($LASTEXITCODE)"
        }
    } finally {
        Pop-Location
    }

    Write-Output "Canale pubblico aggiornamenti pubblicato su https://github.com/$RemoteRepo"
} finally {
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    }
}
