param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$ProjectName
)

# ==============================
# FIXED CONFIG (edit here if needed)
# ==============================
$ProjectsRoot = "YOUR_PROJECTFOLDER_ROOT"
$GitHubOwner  = "YOUR_GITHUB_USERNAME_OR_ORG"
$Branch       = "main"

# Default: HTTPS (SSL)
$RemoteUrl    = "https://github.com/$GitHubOwner/$ProjectName.git"

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ==============================
# Helpers
# ==============================
function Has-Cmd([string]$cmd) {
  return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Require-Cmd([string]$cmd) {
  if (-not (Has-Cmd $cmd)) {
    throw "Required command '$cmd' not found in PATH."
  }
}

function Prompt-YesNo {
  param(
    [string]$Question,
    [bool]$DefaultYes = $true
  )
  $suffix = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }
  $answer = Read-Host "$Question $suffix"
  if (-not $answer) { return $DefaultYes }

  $a = $answer.Trim().ToLower()
  if ($a -in @("y","yes","j","ja")) { return $true }
  if ($a -in @("n","no","nein"))    { return $false }

  return $DefaultYes
}

function Prompt-Visibility {
  $default = "public"
  $answer = Read-Host "GitHub repository visibility? [public/private] (default: $default)"
  if (-not $answer) { return $default }

  $a = $answer.Trim().ToLower()
  switch ($a) {
    { $_ -in @("private","priv","pvt","r") } { return "private" }
    { $_ -in @("public","pub","p") }        { return "public" }
    default {
      Write-Host "Invalid input. Using default: $default" -ForegroundColor Yellow
      return $default
    }
  }
}

function Ensure-Scaffold {
  # Create baseline files only if missing (keeps your project untouched if already prepared)

  if (-not (Test-Path ".gitignore")) {
@"
# OS / Editor
.DS_Store
Thumbs.db
.vscode/
.idea/

# Build artifacts
node_modules/
dist/
build/

# Logs
*.log
"@ | Set-Content -Encoding UTF8 ".gitignore"
    Write-Host "Created .gitignore" -ForegroundColor DarkGray
  }

  if (-not (Test-Path "README.md")) {
@"
# $ProjectName

Initial upload.
"@ | Set-Content -Encoding UTF8 "README.md"
    Write-Host "Created README.md" -ForegroundColor DarkGray
  }

  if (-not (Test-Path "LICENSE")) {
@"
MIT License

Copyright (c) $(Get-Date -Format yyyy) $GitHubOwner

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"@ | Set-Content -Encoding UTF8 "LICENSE"
    Write-Host "Created LICENSE (MIT)" -ForegroundColor DarkGray
  }
}

function Print-Summary {
  param(
    [string]$ProjectPath,
    [string]$Owner,
    [string]$Name,
    [string]$Remote,
    [string]$Branch,
    [bool]$GhAvailable,
    [string]$RepoStatus
  )

  Write-Host ""
  Write-Host "==================== Summary ====================" -ForegroundColor DarkGray
  Write-Host ("Project   : {0}" -f $Name)
  Write-Host ("Path      : {0}" -f $ProjectPath)
  Write-Host ("Owner     : {0}" -f $Owner)
  Write-Host ("Remote    : {0}" -f $Remote)
  Write-Host ("Branch    : {0}" -f $Branch)
  Write-Host ("gh CLI    : {0}" -f ($(if($GhAvailable){"available"}else{"missing"})))
  Write-Host ("Repo      : {0}" -f $RepoStatus)
  Write-Host "=================================================" -ForegroundColor DarkGray
  Write-Host ""
}

# ---------- GitHub repo helpers (optional 'gh') ----------
$GhAvailable = Has-Cmd gh

function Repo-Exists {
  param([string]$Owner,[string]$Name)
  & gh repo view "$Owner/$Name" --json name 1>$null 2>$null
  return ($LASTEXITCODE -eq 0)
}

function Ensure-Repo {
  param([string]$Owner,[string]$Name)

  if (-not $GhAvailable) { return "assumed existing (no gh)" }

  if (Repo-Exists -Owner $Owner -Name $Name) {
    return "exists (verified via gh)"
  }

  # Only prompt for visibility if repo is missing
  $vis = Prompt-Visibility

  Write-Host "GitHub repo not found: $Owner/$Name" -ForegroundColor Yellow
  Write-Host "Creating repo ($vis) ..." -ForegroundColor Cyan

  & gh repo create "$Owner/$Name" --$vis --confirm 1>$null 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Repo creation failed (gh). Check: gh auth login" -ForegroundColor Yellow
    return "not verified/created (gh issue)"
  }

  return "created via gh ($vis)"
}

# ==============================
# MAIN
# ==============================
Require-Cmd git

$projectPath = Join-Path $ProjectsRoot $ProjectName
if (-not (Test-Path $projectPath)) {
  throw "Project folder not found: $projectPath"
}

if (-not $GhAvailable) {
  Write-Host "GitHub CLI (gh) not found in PATH." -ForegroundColor Yellow
  Write-Host "Repo auto-create will be skipped. Install with:" -ForegroundColor Yellow
  Write-Host "  winget install GitHub.cli" -ForegroundColor DarkGray
  Write-Host "Then authenticate once:" -ForegroundColor Yellow
  Write-Host "  gh auth login" -ForegroundColor DarkGray
}

# Ensure remote repo exists (auto-create if possible)
$repoStatus = Ensure-Repo -Owner $GitHubOwner -Name $ProjectName

Push-Location $projectPath
try {
  # ------------------------------------------------------------
  # CASE A: Repo already initialized locally -> optional push mode
  # ------------------------------------------------------------
  if (Test-Path ".git") {
    Print-Summary -ProjectPath $projectPath -Owner $GitHubOwner -Name $ProjectName -Remote $RemoteUrl -Branch $Branch -GhAvailable $GhAvailable -RepoStatus $repoStatus

    $doPush = Prompt-YesNo -Question "This folder is already a git repository. Commit & push changes?" -DefaultYes $true
    if (-not $doPush) {
      throw "Aborted by user (repo already initialized)."
    }

    # Ensure origin remote exists and matches expected HTTPS URL
    $origin = ""
    try { $origin = (git remote get-url origin 2>$null).Trim() } catch { $origin = "" }

    if (-not $origin) {
      Write-Host "No 'origin' remote found. Adding origin..." -ForegroundColor Yellow
      git remote add origin $RemoteUrl | Out-Null
      $origin = $RemoteUrl
    } elseif ($origin -ne $RemoteUrl) {
      $fix = Prompt-YesNo -Question "Origin remote differs. Update origin to '$RemoteUrl'?" -DefaultYes $true
      if ($fix) {
        git remote set-url origin $RemoteUrl | Out-Null
        $origin = $RemoteUrl
        Write-Host "Origin updated." -ForegroundColor DarkGray
      } else {
        Write-Host "Keeping existing origin: $origin" -ForegroundColor Yellow
      }
    }

    # Ensure branch name
    git branch -M $Branch | Out-Null

    # Commit changes if needed
    git add -A
    $changes = (git status --porcelain)
    if ($changes) {
      $msg = Read-Host "Commit message (default: Update)"
      if (-not $msg) { $msg = "Update" }
      git commit -m $msg | Out-Null
      Write-Host "Committed changes." -ForegroundColor DarkGray
    } else {
      Write-Host "No local changes detected. Pushing current branch..." -ForegroundColor DarkGray
    }

    Write-Host "Pushing to origin/$Branch ..." -ForegroundColor Cyan
    git push -u origin $Branch

    Write-Host "`n✔ Done – pushed successfully" -ForegroundColor Green
    return
  }

  # ------------------------------------------------------------
  # CASE B: Fresh init -> initial commit + push
  # ------------------------------------------------------------
  Write-Host "`nInitializing git repository:" -ForegroundColor Cyan
  Write-Host "  $projectPath"

  git init | Out-Null
  Ensure-Scaffold

  git remote add origin $RemoteUrl | Out-Null
  Write-Host "Remote set to: $RemoteUrl" -ForegroundColor DarkGray

  git add -A
  if (-not (git status --porcelain)) {
    Print-Summary -ProjectPath $projectPath -Owner $GitHubOwner -Name $ProjectName -Remote $RemoteUrl -Branch $Branch -GhAvailable $GhAvailable -RepoStatus $repoStatus
    throw "Nothing to commit – folder is empty or ignored."
  }

  git commit -m "Initial commit" | Out-Null
  git branch -M $Branch | Out-Null

  Write-Host "Pushing to origin/$Branch ..." -ForegroundColor Cyan
  git push -u origin $Branch

  Print-Summary -ProjectPath $projectPath -Owner $GitHubOwner -Name $ProjectName -Remote $RemoteUrl -Branch $Branch -GhAvailable $GhAvailable -RepoStatus $repoStatus
  Write-Host "✔ Done – project uploaded successfully" -ForegroundColor Green
}
finally {
  Pop-Location
}
