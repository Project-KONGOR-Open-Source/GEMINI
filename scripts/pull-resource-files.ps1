<#
.SYNOPSIS
    Pulls .s2z files referenced in .gitattributes from a public CDN at the same relative paths.
    Skips files whose local MD5 already matches the remote ETag.

.DESCRIPTION
    For each entry in .gitattributes whose path ends in .s2z:
      1. HEAD the URL ($BaseURL + relative path) to read the ETag.
      2. If the ETag is a clean 32-char MD5 and the local file's MD5 matches, skip.
      3. Otherwise, download to the matching local path, creating directories as needed.
    A composite ETag (e.g. multipart upload, "<md5>-<n>") triggers a warning and a re-download because MD5 verification is not possible.
    Prints per-file progress, and at the end logs separate lists of pulled and skipped files.
    No authentication is used. The CDN bucket is expected to be publicly readable.

.PARAMETER RepositoryRoot
    Repository root. Defaults to the parent of this script's folder.

.PARAMETER BaseURL
    Public CDN base URL. A trailing slash is added if missing. Default: https://cdn.kongor.net/

.PARAMETER StripPrefix
    A leading directory in the repository-relative path that does not exist on the CDN, removed before the URL is formed.
    Defaults to 'source/' to match the current GEMINI layout (e.g. local 'source/lac/base/foo.s2z' -> CDN 'lac/base/foo.s2z').
    Pass '' to disable stripping.

.PARAMETER Force
    Always re-download even if the local file's MD5 matches the remote ETag.

.EXAMPLE
    .\pull-resource-files.ps1
    .\pull-resource-files.ps1 -BaseURL 'https://cdn.kongor.net/s2z/'
    .\pull-resource-files.ps1 -StripPrefix ''
    .\pull-resource-files.ps1 -Force
#>
[CmdletBinding()]
param(
    [string] $RepositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath,
    [string] $BaseURL        = 'https://cdn.kongor.net/',
    [string] $StripPrefix    = 'source/',
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$attrFile = Join-Path $RepositoryRoot '.gitattributes'
if (-not (Test-Path -LiteralPath $attrFile)) { throw "No .gitattributes File Found At $attrFile" }

if (-not $BaseURL.EndsWith('/')) { $BaseURL = $BaseURL + '/' }

$entries = Get-Content -LiteralPath $attrFile |
    Where-Object { $_ -and ($_ -notmatch '^\s*#') } |
    ForEach-Object {
        $line = $_.Trim()
        if ($line.StartsWith('"')) {
            $end = $line.IndexOf('"', 1)
            if ($end -gt 0) { $line.Substring(1, $end - 1) }
        } else {
            ($line -split '\s+', 2)[0]
        }
    } |
    Where-Object { $_ -and $_.EndsWith('.s2z', [StringComparison]::OrdinalIgnoreCase) }

if (-not $entries) {
    Write-Host "No .s2z Entries In .gitattributes File"
    return
}

$pulled  = [System.Collections.Generic.List[string]]::new()
$skipped = [System.Collections.Generic.List[string]]::new()
$failed  = [System.Collections.Generic.List[string]]::new()

function Get-FileMD5 {
    param([string] $Path)
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try {
        $fs = [System.IO.File]::OpenRead($Path)
        try { $bytes = $md5.ComputeHash($fs) } finally { $fs.Dispose() }
    } finally { $md5.Dispose() }
    return [BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()
}

foreach ($rel in $entries) {
    try {
        $urlPath = $rel -replace '\\', '/'
        if ($StripPrefix -and $urlPath.StartsWith($StripPrefix)) {
            $urlPath = $urlPath.Substring($StripPrefix.Length)
        }
        $url       = $BaseURL + $urlPath
        $localPath = [System.IO.Path]::Combine($RepositoryRoot, $rel.Replace('/', [System.IO.Path]::DirectorySeparatorChar))

        # HEAD to read the ETag
        try {
            $head = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -ErrorAction Stop
        } catch {
            Write-Warning ("HEAD Failed | {0} | {1}" -f $rel, $_.Exception.Message)
            $failed.Add($rel)
            continue
        }

        # extract ETag and treat it as a remote MD5 only if it's a clean 32-char hex
        # composite ETags (multipart uploads) look like "<md5>-<n>" and cannot be compared directly
        $remoteMd5 = $null
        $etagRaw   = @($head.Headers['ETag'])[0]
        if ($etagRaw) {
            $etag = ([string]$etagRaw).Trim('"', ' ')
            if ($etag -match '^[0-9a-fA-F]{32}$') { $remoteMd5 = $etag.ToLowerInvariant() }
            else { Write-Warning ("ETag Not A Plain MD5 | {0} | {1}" -f $rel, $etag) }
        } else {
            Write-Warning ("ETag Missing | {0}" -f $rel)
        }

        # MD5-based skip check (only when we have a usable remote MD5 and a local file)
        if (-not $Force -and $remoteMd5 -and [System.IO.File]::Exists($localPath)) {
            if ((Get-FileMD5 -Path $localPath) -eq $remoteMd5) {
                Write-Host ("SKIP | {0}" -f $rel)
                $skipped.Add($rel)
                continue
            }
        }

        $dir = [System.IO.Path]::GetDirectoryName($localPath)
        if ($dir -and -not [System.IO.Directory]::Exists($dir)) {
            [System.IO.Directory]::CreateDirectory($dir) | Out-Null
        }

        Write-Host ("PULL | {0}" -f $rel)
        $tmpPath = $localPath + '.tmp'
        try {
            $wc = [System.Net.WebClient]::new()
            try { $wc.DownloadFile($url, $tmpPath) } finally { $wc.Dispose() }
            if ([System.IO.File]::Exists($localPath)) { [System.IO.File]::Delete($localPath) }
            [System.IO.File]::Move($tmpPath, $localPath)
            $pulled.Add($rel)
        } catch {
            if ([System.IO.File]::Exists($tmpPath)) {
                try { [System.IO.File]::Delete($tmpPath) } catch { }
            }
            Write-Warning ("GET Failed | {0} | {1}" -f $rel, $_.Exception.Message)
            $failed.Add($rel)
        }
    } catch {
        Write-Warning ("Iteration Failed | {0} | At Line {1} | {2}: {3}" -f `
            $rel, $_.InvocationInfo.ScriptLineNumber, $_.Exception.GetType().Name, $_.Exception.Message)
        $failed.Add($rel)
    }
}

Write-Host ''
Write-Host ("PULLED ({0}):" -f $pulled.Count)
foreach ($p in $pulled) { Write-Host "  $p" }

Write-Host ''
Write-Host ("SKIPPED ({0}):" -f $skipped.Count)
foreach ($s in $skipped) { Write-Host "  $s" }

if ($failed.Count -gt 0) {
    Write-Host ''
    Write-Host ("FAILED ({0}):" -f $failed.Count)
    foreach ($f in $failed) { Write-Host "  $f" }
}
