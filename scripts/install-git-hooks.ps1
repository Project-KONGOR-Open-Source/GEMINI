<#
.SYNOPSIS
    Wires repository-tracked hooks from .githooks/ into git for this clone.

.DESCRIPTION
    1. Sets `core.hooksPath` to .githooks via `git config` (per-clone setting; idempotent).
    2. Stages each file in .githooks/ with the executable bit set so the hooks run on every platform.

    Run once per fresh clone (and after authoring any new hook script).

.NOTES
    Hooks Wired:
      post-merge     - runs pull-resource-files.ps1 after `git pull` / `git merge`.
      post-checkout  - runs pull-resource-files.ps1 after `git checkout <branch>`.

    The very first clone cannot auto-run hooks because core.hooksPath is unset until this script runs.
#>
[CmdletBinding()] param()

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath
Push-Location $repoRoot
try {
    & git config core.hooksPath '.githooks'
    Write-Host "Set core.hooksPath = .githooks"

    $hooksDir = Join-Path $repoRoot '.githooks'
    if ([System.IO.Directory]::Exists($hooksDir)) {
        foreach ($f in [System.IO.Directory]::EnumerateFiles($hooksDir)) {
            $name = [System.IO.Path]::GetFileName($f)
            & git add --chmod=+x ".githooks/$name"
        }
        Write-Host "Hook Files Staged As Executable"
    }

    Write-Host ''
    Write-Host "DONE: S2Z Resources Will Sync On:"
    Write-Host "  - git pull / git merge   (post-merge hook)"
    Write-Host "  - git checkout <branch>  (post-checkout hook)"
    Write-Host ''
    Write-Host "NOTE: The Initial Clone Cannot Auto-Run Hooks (core.hooksPath Was Not Set Yet)"
    Write-Host "      Run 'pwsh -File scripts/pull-resource-files.ps1' Once Now To Populate Assets"
    Write-Host ''
    Write-Host "Commit Any Changes Shown By 'git status' So Other Clones Inherit The Executable Bits"
} finally {
    Pop-Location
}
