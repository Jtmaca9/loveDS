param(
  [Parameter(Mandatory=$true)]
  [string]$EngineRepoUrl,

  [Parameter(Mandatory=$true)]
  [string]$AndroidRepoUrl,

  [string]$EngineDir = "engine",
  [string]$AndroidDir = "android"
)

$ErrorActionPreference = "Stop"

function Assert-Git {
  $git = Get-Command git -ErrorAction SilentlyContinue
  if (-not $git) {
    throw "git not found in PATH."
  }
}

Assert-Git

if (-not (Test-Path $EngineDir)) {
  git submodule add $EngineRepoUrl $EngineDir
} else {
  Write-Host "Exists: $EngineDir (skipping add)"
}

if (-not (Test-Path $AndroidDir)) {
  git submodule add $AndroidRepoUrl $AndroidDir
} else {
  Write-Host "Exists: $AndroidDir (skipping add)"
}

git submodule update --init --recursive

Write-Host ""
Write-Host "Next steps:"
Write-Host "1) Copy template game: template\\game\\* -> android\\app\\src\\embed\\assets\\"
Write-Host "2) Open android\\ in Android Studio and run."

