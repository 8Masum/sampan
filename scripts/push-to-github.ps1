<#
.SYNOPSIS
  Creates and pushes the public `sampan` repository to GitHub and triggers the
  v1.0.0 Android APK release workflow.

.PARAMETER Owner
  GitHub username or organization (e.g., "themasum-com" or "themasumiqbal").
  If omitted, uses the authenticated GitHub CLI user.

.PARAMETER Tag
  Release tag to push (defaults to "v1.0.0").
#>
param(
    [string]$Owner = "",
    [string]$RepoName = "sampan",
    [string]$Tag = "v1.0.0"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "⛵ Sampan (সাম্পান) — GitHub Repository Publisher" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# 1. Run pre-push verification suite
Write-Host "`n[1/4] Running automated verification suite..." -ForegroundColor Yellow
node scripts/verify-all.mjs
if ($LASTEXITCODE -ne 0) {
    throw "Verification suite failed. Aborting push."
}

# 2. Check GitHub CLI authentication
Write-Host "`n[2/4] Checking GitHub CLI authentication..." -ForegroundColor Yellow
$ghAuthed = $false
try {
    gh auth status *> $null
    if ($LASTEXITCODE -eq 0) {
        $ghAuthed = $true
    }
} catch {}

if (-not $ghAuthed) {
    Write-Host "GitHub CLI token is expired or not logged in. Launching 'gh auth login'..." -ForegroundColor Yellow
    gh auth login -h github.com -p https -w
}

if ([string]::IsNullOrWhiteSpace($Owner)) {
    $Owner = (gh api user --jq ".login").Trim()
}

$FullRepo = "$Owner/$RepoName"
$RemoteUrl = "https://github.com/$FullRepo.git"
Write-Host "Target Public Repository: https://github.com/$FullRepo" -ForegroundColor Green

# 3. Create public repo if it does not exist yet
Write-Host "`n[3/4] Ensuring public repository '$FullRepo' exists on GitHub..." -ForegroundColor Yellow
$repoExists = $false
try {
    gh repo view $FullRepo *> $null
    if ($LASTEXITCODE -eq 0) {
        $repoExists = $true
    }
} catch {}

if (-not $repoExists) {
    gh repo create $FullRepo `
        --public `
        --description "Sampan (সাম্পান) — Local-First, Zero-Cloud P2P Mesh for Travel & Co-Presence (BLE + SoftAP Hub)" `
        --source=. `
        --remote=origin
} else {
    $existingRemote = git remote get-url origin 2>$null
    if (-not $existingRemote) {
        git remote add origin $RemoteUrl
    } else {
        git remote set-url origin $RemoteUrl
    }
}

# 4. Push main branch and release tag
Write-Host "`n[4/4] Pushing branch and release tag ($Tag) to trigger APK build..." -ForegroundColor Yellow
$currentBranch = (git branch --show-current).Trim()
git push -u origin $currentBranch

if ($Tag) {
    $existingTag = git tag -l $Tag
    if (-not $existingTag) {
        git tag -a $Tag -m "Sampan $Tag — Initial Local-First P2P Mesh Release"
    }
    git push origin $Tag
}

Write-Host "`n======================================================" -ForegroundColor Green
Write-Host "✅ Successfully pushed Sampan to https://github.com/$FullRepo" -ForegroundColor Green
Write-Host "🚀 GitHub Actions is now building Sampan.apk: https://github.com/$FullRepo/actions" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
