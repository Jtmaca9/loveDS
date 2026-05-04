param(
  [string]$AndroidDir = "android",
  [string]$EngineRepoUrl = "",
  [string]$LoveSubmodulePath = "app/src/main/cpp/love"
)

$ErrorActionPreference = "Stop"

function Assert-Git {
  $git = Get-Command git -ErrorAction SilentlyContinue
  if (-not $git) { throw "git not found in PATH." }
}

Assert-Git

$androidPath = Resolve-Path $AndroidDir

if ([string]::IsNullOrWhiteSpace($EngineRepoUrl)) {
  # Best-effort default: use the superproject's origin URL.
  $EngineRepoUrl = (git config --get remote.origin.url)
}

Write-Host "Pointing $AndroidDir/$LoveSubmodulePath -> $EngineRepoUrl"

git -C $androidPath submodule set-url $LoveSubmodulePath $EngineRepoUrl
git -C $androidPath submodule update --init --recursive $LoveSubmodulePath

Write-Host "Done."

