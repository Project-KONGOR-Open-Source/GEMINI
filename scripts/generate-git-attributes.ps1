<#
.SYNOPSIS
    Regenerates .gitattributes with one Git LFS rule per file at or above the threshold.
    Default threshold is 100 MB (GitHub's hard push limit).
    Files whose extension is in $AlwaysLFSExtensions are also LFS-tracked, regardless of size.
    Also emits a default LF line-ending policy and a per-extension binary/text classification discovered from the repository contents.

.DESCRIPTION
    Walks the repository, finds matching files, writes a grouped .gitattributes that LFS-tracks each by its repository-relative path.
    Each file extension seen under $ContentDirectory is classified by reading the first 8 KB of one representative file; any NUL byte marks the extension binary, otherwise it is treated as text.
    Output is grouped: a default line-ending policy; alphabetical lists of binary and text extensions; one section per always-LFS extension (in the order given), then a final section for files at or above the size threshold that don't match any extension. Sections are separated by a blank line; empty groups are skipped.
    Make sure to run before `git add` so the files actually go through the LFS filter on stage.
    The .gitattributes file is overwritten in full on every run.

.PARAMETER RepositoryRoot
    Repository root to scan. Defaults to the parent of this script's folder.

.PARAMETER ContentDirectory
    Subdirectory under the repository root whose extensions are classified as binary or text. Default: 'source'.

.PARAMETER FileSizeThreshold
    File size threshold. Default: 100MB.

.PARAMETER AlwaysLFSExtensions
    Extensions (with or without leading dot) to LFS-track regardless of size. Default: '.s2z'.

.EXAMPLE
    .\generate-git-attributes.ps1
    .\generate-git-attributes.ps1 -FileSizeThreshold 50MB
    .\generate-git-attributes.ps1 -AlwaysLFSExtensions '.s2z','.dll'
#>
[CmdletBinding()]
param(
    [string]   $RepositoryRoot      = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath,
    [string]   $ContentDirectory    = 'source',
    [long]     $FileSizeThreshold   = 100MB,
    [string[]] $AlwaysLFSExtensions = @('.s2z')
)

$ErrorActionPreference = 'Stop'

$attrFile      = Join-Path $RepositoryRoot '.gitattributes'
$sep           = [IO.Path]::DirectorySeparatorChar
$contentRoot   = (Resolve-Path -LiteralPath (Join-Path $RepositoryRoot $ContentDirectory)).ProviderPath
$contentPrefix = $contentRoot.TrimEnd('\','/') + $sep

function Sort-Ordinal {
    param([System.Collections.IEnumerable] $InputObject)
    $array = [string[]] @($InputObject)
    [System.Array]::Sort($array, [System.StringComparer]::Ordinal)
    return $array
}

$alwaysLFS = $AlwaysLFSExtensions |
    ForEach-Object { if ($_.StartsWith('.')) { $_ } else { '.' + $_ } } |
    Sort-Object -Unique

function Test-IsBinaryFile {
    param([string] $Path)

    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $buffer = New-Object byte[] 8000
            $read   = $stream.Read($buffer, 0, $buffer.Length)
            for ($i = 0; $i -lt $read; $i++) {
                if ($buffer[$i] -eq 0) { return $true }
            }
            return $false
        } finally {
            $stream.Dispose()
        }
    } catch {
        return $true
    }
}

$allFiles = Get-ChildItem -LiteralPath $RepositoryRoot -File -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName.Split($sep) -notcontains '.git' }

$extGroups  = [ordered]@{}
foreach ($ext in $alwaysLFS) { $extGroups[$ext] = [System.Collections.Generic.List[string]]::new() }
$largeFiles = [System.Collections.Generic.List[string]]::new()

$samplePerKey = [ordered]@{}

foreach ($file in $allFiles) {
    if ($file.Extension -cin $alwaysLFS -or $file.Length -ge $FileSizeThreshold) {
        $rel   = $file.FullName.Substring($RepositoryRoot.Length).TrimStart($sep) -replace '\\', '/'
        $entry = if ($rel -match '\s') { '"{0}"' -f $rel } else { $rel }
        if ($file.Extension -cin $alwaysLFS) { $extGroups[$file.Extension].Add($entry) }
        else                                 { $largeFiles.Add($entry) }
    }

    if (-not $file.FullName.StartsWith($contentPrefix, [StringComparison]::OrdinalIgnoreCase)) { continue }
    if ($file.Extension -cin $alwaysLFS) { continue }

    $key = $null
    if ($file.BaseName -eq '' -and $file.Name.StartsWith('.')) {
        $key = $file.Name
    } elseif ($file.Extension) {
        $key = '*' + $file.Extension.ToLowerInvariant()
    }
    if (-not $key) { continue }

    if (-not $samplePerKey.Contains($key)) {
        $samplePerKey[$key] = $file.FullName
    }
}

$binaryKeys = [System.Collections.Generic.List[string]]::new()
$textKeys   = [System.Collections.Generic.List[string]]::new()

foreach ($entry in $samplePerKey.GetEnumerator()) {
    if (Test-IsBinaryFile $entry.Value) { [void]$binaryKeys.Add($entry.Key) }
    else                                { [void]$textKeys.Add($entry.Key)   }
}

$binaryGlobs = Sort-Ordinal $binaryKeys
$textGlobs   = Sort-Ordinal $textKeys

$lines = @(
    '# Auto-Generated By "scripts/generate-git-attributes.ps1"'
    '# Re-Generate After Adding New Large Files'
    ''
    "# Generated: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"
    "# Threshold: $([math]::Round($FileSizeThreshold / 1MB, 0)) MB"
    ''
    '# Default Policy'
    '* text=auto eol=lf'
)

if ($binaryGlobs.Count -gt 0) {
    $lines += ''
    $lines += '# Binary Files'
    $lines += ($binaryGlobs | ForEach-Object { "$_ binary" })
}

if ($textGlobs.Count -gt 0) {
    $lines += ''
    $lines += '# Text Files'
    $lines += ($textGlobs | ForEach-Object { "$_ text" })
}

foreach ($ext in $alwaysLFS) {
    if ($extGroups[$ext].Count -eq 0) { continue }
    $lines += ''
    $lines += "# Files With Extension ""$ext"""
    $lines += (Sort-Ordinal $extGroups[$ext] | ForEach-Object { "$_ filter=lfs diff=lfs merge=lfs -text" })
}

if ($largeFiles.Count -gt 0) {
    $lines += ''
    $lines += "# Files At Or Above $([math]::Round($FileSizeThreshold / 1MB, 0)) MB"
    $lines += (Sort-Ordinal $largeFiles | ForEach-Object { "$_ filter=lfs diff=lfs merge=lfs -text" })
}

$content = ($lines -join "`n") + "`n"

[IO.File]::WriteAllText($attrFile, $content, [Text.UTF8Encoding]::new($false))

$total = $largeFiles.Count
foreach ($g in $extGroups.Values) { $total += $g.Count }
Write-Host ("{0} File(s) Flagged For LFS" -f $total)
Write-Host ("{0} Binary Glob(s), {1} Text Glob(s) Discovered" -f $binaryGlobs.Count, $textGlobs.Count)
Write-Host ("Wrote {0}" -f $attrFile)
