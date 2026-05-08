<#
.SYNOPSIS
    Configures the `git sync` alias for this clone: runs `git pull` and then syncs .s2z resources from cdn.kongor.net.

.DESCRIPTION
    Sets a per-clone git alias that wraps `git pull` with a `pull-resource-files.ps1` step.
    Always re-checks resources against the CDN, even when `git pull` reports "Already up to date".
    Idempotent. Run once per fresh clone.

.NOTES
    After running, `git sync` is equivalent to:
      git pull && pwsh -NoProfile -File scripts/pull-resource-files.ps1

    Contributors must have PowerShell 7+ (pwsh) on PATH.
    Plain `git pull` is unchanged and still works for code-only updates.
#>
[CmdletBinding()] param()

$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath
Push-Location $repositoryRoot

try {
    $aliasBody = '!git pull && pwsh -NoProfile -File scripts/pull-resource-files.ps1'
    & git config 'alias.sync' $aliasBody
    Write-Host ("Set Git Alias 'sync' = {0}" -f $aliasBody)
    Write-Host ''
    Write-Host "DONE: Use 'git sync' To Pull Code And Sync Resources In One Step"
    Write-Host "Plain 'git pull' Still Works For Code-Only Updates"
} finally {
    Pop-Location
}
