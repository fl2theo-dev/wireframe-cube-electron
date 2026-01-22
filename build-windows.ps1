Param(
  [ValidateSet('x64','ia32','both')]
  [string]$Arch = 'x64'
)

Write-Host "== Wireframe Cube: Windows build script =="

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Script dir: $ScriptDir"

# Resolve standalone source (one level up)
$standalonePath = Join-Path $ScriptDir '..\wireframe-cube-standalone'
try { $standalonePath = (Resolve-Path $standalonePath).ProviderPath } catch { $standalonePath = $null }

if (-not (Test-Path (Join-Path $ScriptDir 'app'))) {
    if ($standalonePath) {
        Write-Host "Copying standalone webassets from $standalonePath to $ScriptDir\app"
        New-Item -ItemType Directory -Path (Join-Path $ScriptDir 'app') -Force | Out-Null
        robocopy $standalonePath (Join-Path $ScriptDir 'app') /E /NFL /NDL /NJH /NJS | Out-Null
    } else {
        Write-Warning "No standalone folder found at ../wireframe-cube-standalone and no app/ directory exists. Ensure your webassets are in $ScriptDir\app"
    }
} else {
    Write-Host "app/ already exists. Skipping copy."
}

Write-Host "Checking toolchain: node, npm, git, makensis"
if (Get-Command node -ErrorAction SilentlyContinue) { node -v } else { Write-Warning "node not found in PATH" }
if (Get-Command npm -ErrorAction SilentlyContinue) { npm -v } else { Write-Warning "npm not found in PATH" }
if (Get-Command git -ErrorAction SilentlyContinue) { git --version } else { Write-Warning "git not found in PATH" }
if (-not (Get-Command makensis -ErrorAction SilentlyContinue)) { Write-Warning "makensis (NSIS) not found in PATH — installer build will fail without it. Install NSIS (e.g. choco install nsis)" } else { Write-Host "makensis found" }

Write-Host "Installing dependencies in $ScriptDir"
Push-Location $ScriptDir
try {
    if (Test-Path package-lock.json) {
        Write-Host "package-lock.json found — running npm ci"
        npm ci
    } else {
        Write-Host "No lockfile — running npm install"
        npm install
    }
} catch {
    Write-Error "Dependency install failed: $_"
    Pop-Location
    exit 1
}

# Build args
switch ($Arch) {
    'x64' { $archArgs = '--win --x64' }
    'ia32' { $archArgs = '--win --ia32' }
    'both' { $archArgs = '--win --x64 --ia32' }
}

Write-Host "Running electron-builder ($archArgs)"
try {
    npm run dist -- -- $archArgs
} catch {
    Write-Error "Build command failed: $_"
    Pop-Location
    exit 2
}

Pop-Location

$distDir = Join-Path $ScriptDir 'dist'
if (-not (Test-Path $distDir)) { Write-Warning "No dist/ directory created."; exit 3 }

Write-Host "Artifacts in $distDir:"
Get-ChildItem -Path $distDir -Recurse | Where-Object {!$_.PSIsContainer} | ForEach-Object {
    $hash = Get-FileHash -Path $_.FullName -Algorithm SHA256
    Write-Host " - $($_.FullName)  size=$($_.Length)  sha256=$($hash.Hash)"
}

Write-Host "Done."
exit 0
