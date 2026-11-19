param(
    [Parameter(Mandatory = $true)][string]$AppRoot,
    [int]$CallerPid = 0,
    [string]$LauncherExe = 'Telecamere.exe'
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

if ($LauncherExe -notin @('Telecamere.exe', 'Orwell.exe')) {
    $LauncherExe = 'Telecamere.exe'
}

$authPath = Join-Path $AppRoot 'bin\update-auth.json'
$usePrivateAuth = $false
$repo = 'daviidevvvv/orwell-updates'
$branch = 'main'
$token = $null

if (Test-Path -LiteralPath $authPath -PathType Leaf) {
    $auth = Get-Content -LiteralPath $authPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($auth.repo -and $auth.token) {
        $usePrivateAuth = $true
        $repo = [string]$auth.repo
        $branch = if ($auth.branch) { [string]$auth.branch } else { 'main' }
        $token = [string]$auth.token
    }
}

$tempZip = Join-Path $env:TEMP ("tb_update_{0}.zip" -f $PID)
$tempDir = Join-Path $env:TEMP ("tb_update_{0}" -f $PID)
if (Test-Path -LiteralPath $tempZip) { Remove-Item -LiteralPath $tempZip -Force }
if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }

try {
    if ($usePrivateAuth) {
        $headers = @{
            Authorization = "Bearer $token"
            Accept        = 'application/vnd.github+json'
            'User-Agent'  = 'Orwell-Updater'
        }
        $zipUrl = "https://api.github.com/repos/$repo/zipball/$branch"
        Invoke-WebRequest -UseBasicParsing -Uri $zipUrl -Headers $headers -OutFile $tempZip -TimeoutSec 60
    } else {
        $headers = @{
            'User-Agent' = 'Orwell-Updater'
        }
        $zipUrl = "https://github.com/$repo/archive/refs/heads/$branch.zip"
        Invoke-WebRequest -UseBasicParsing -Uri $zipUrl -Headers $headers -OutFile $tempZip -TimeoutSec 60
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $tempDir)
    $extractedRoot = Get-ChildItem -LiteralPath $tempDir -Directory | Select-Object -First 1
    if (-not $extractedRoot) {
        throw 'Archivio aggiornamento vuoto.'
    }
    $srcRoot = $extractedRoot.FullName

    # Sync non-locked static/text folders while preserving local presets.js customizations
    $presetsBackup = Join-Path $env:TEMP ("tb_presets_{0}.js" -f $PID)
    $localPresets = Join-Path $AppRoot 'web\presets.js'
    if (Test-Path -LiteralPath $localPresets -PathType Leaf) {
        Copy-Item -LiteralPath $localPresets -Destination $presetsBackup -Force
    }

    foreach ($sub in @('web', 'assets', 'docs', 'tools', 'src', 'tauri-ui')) {
        $fromSub = Join-Path $srcRoot $sub
        if (Test-Path -LiteralPath $fromSub -PathType Container) {
            $toSub = Join-Path $AppRoot $sub
            New-Item -ItemType Directory -Path $toSub -Force | Out-Null
            Copy-Item -Path (Join-Path $fromSub '*') -Destination $toSub -Recurse -Force
        }
    }

    if (Test-Path -LiteralPath $presetsBackup -PathType Leaf) {
        Copy-Item -LiteralPath $presetsBackup -Destination $localPresets -Force
        Remove-Item -LiteralPath $presetsBackup -Force -ErrorAction SilentlyContinue
    }

    foreach ($rootFile in @('Avvia_Telecamere.bat', 'Avvia_Orwell.bat', 'README.md', '.gitattributes', '.gitignore')) {
        $fromFile = Join-Path $srcRoot $rootFile
        if (Test-Path -LiteralPath $fromFile -PathType Leaf) {
            Copy-Item -LiteralPath $fromFile -Destination (Join-Path $AppRoot $rootFile) -Force
        }
    }

    $srcYaml = Join-Path $srcRoot 'bin\go2rtc.yaml'
    if (Test-Path -LiteralPath $srcYaml -PathType Leaf) {
        Copy-Item -LiteralPath $srcYaml -Destination (Join-Path $AppRoot 'bin\go2rtc.yaml') -Force
    }

    function Get-FileSha256Hex([string]$Path) {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $fs = [System.IO.File]::OpenRead($Path)
            try {
                return ([System.BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-', '')
            } finally {
                $fs.Dispose()
            }
        } finally {
            $sha.Dispose()
        }
    }

    # Check if compiled executables changed (need detached process swap + restart)
    $stagedMoves = @()
    $binaryChecks = @(
        @{ SrcRel = 'Telecamere.exe'; DstRel = 'Telecamere.exe'; Staged = (Join-Path $env:TEMP ("Telecamere.{0}.new.exe" -f $PID)) },
        @{ SrcRel = 'Orwell.exe'; DstRel = 'Orwell.exe'; Staged = (Join-Path $env:TEMP ("Orwell.{0}.new.exe" -f $PID)) },
        @{ SrcRel = 'bin\ClipExporter.exe'; DstRel = 'bin\ClipExporter.exe'; Staged = (Join-Path $env:TEMP ("ClipExporter.{0}.new.exe" -f $PID)) }
    )
    foreach ($bin in $binaryChecks) {
        Remove-Item -LiteralPath $bin.Staged -Force -ErrorAction SilentlyContinue
        $newBin = Join-Path $srcRoot $bin.SrcRel
        $curBin = Join-Path $AppRoot $bin.DstRel
        if ((Test-Path -LiteralPath $newBin -PathType Leaf) -and ((Get-Item -LiteralPath $newBin).Length -gt 8192)) {
            $newHash = Get-FileSha256Hex $newBin
            $curHash = if (Test-Path -LiteralPath $curBin -PathType Leaf) { Get-FileSha256Hex $curBin } else { '' }
            if ($newHash -ne $curHash) {
                Copy-Item -LiteralPath $newBin -Destination $bin.Staged -Force
                $stagedMoves += @{ Src = $bin.Staged; Dst = $curBin }
            }
        }
    }

    # Keep git index aligned on machines that also have git installed
    if ((Test-Path -LiteralPath (Join-Path $AppRoot '.git')) -and (Get-Command git.exe -ErrorAction SilentlyContinue)) {
        try {
            & git.exe -C $AppRoot fetch origin $branch 2>$null
            if ($LASTEXITCODE -eq 0) {
                & git.exe -C $AppRoot reset --hard "origin/$branch" 2>$null
            }
        } catch {
        }
    }

    if ($stagedMoves.Count -gt 0) {
        $swapScriptPath = Join-Path $env:TEMP ("tb_apply_exe_{0}.ps1" -f $PID)
        $restartTarget = Join-Path $AppRoot $LauncherExe
        $movesJson = ($stagedMoves | ConvertTo-Json -Compress)
        $escMoves = $movesJson.Replace("'", "''")
        $escRoot = $AppRoot.Replace("'", "''")
        $escTarget = $restartTarget.Replace("'", "''")
        $swapScript = @"
`$ErrorActionPreference = 'SilentlyContinue'
`$callerPid = $CallerPid
if (`$callerPid -gt 0) {
    for (`$i = 0; `$i -lt 6; `$i++) {
        if (-not (Get-Process -Id `$callerPid -ErrorAction SilentlyContinue)) { break }
        Start-Sleep -Milliseconds 200
    }
    Stop-Process -Id `$callerPid -Force -ErrorAction SilentlyContinue
}
Get-Process -Name 'Orwell', 'Telecamere', 'Telecamere_Tauri', 'go2rtc', 'ClipExporter' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
& taskkill.exe /F /IM Orwell.exe /IM Telecamere.exe /IM Telecamere_Tauri.exe /IM go2rtc.exe /IM ClipExporter.exe 2>`$null | Out-Null
for (`$i = 0; `$i -lt 15; `$i++) {
    if (-not (Get-Process -Name 'Orwell', 'Telecamere', 'Telecamere_Tauri' -ErrorAction SilentlyContinue)) { break }
    Start-Sleep -Milliseconds 200
}
Start-Sleep -Milliseconds 250

`$raw = '$escMoves' | ConvertFrom-Json
if (`$raw -isnot [System.Array]) { `$raw = @(`$raw) }
foreach (`$item in `$raw) {
    for (`$try = 0; `$try -lt 30; `$try++) {
        try {
            if (Test-Path -LiteralPath `$item.Src) {
                Move-Item -LiteralPath `$item.Src -Destination `$item.Dst -Force -ErrorAction Stop
            }
            break
        } catch {
            Start-Sleep -Milliseconds 300
        }
    }
}

Start-Process -FilePath '$escTarget' -WorkingDirectory '$escRoot'
Remove-Item -LiteralPath `$PSCommandPath -Force -ErrorAction SilentlyContinue
"@
        [System.IO.File]::WriteAllText($swapScriptPath, $swapScript, [System.Text.UTF8Encoding]::new($false))
        Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', $swapScriptPath) -WindowStyle Hidden
        exit 10
    }

    exit 0
} finally {
    Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
