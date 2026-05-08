<h3>
    <p align="center">GEMINI</p>
    <p>A collection of Heroes Of Newerth distribution files.</p>
</h3>

<hr/>

<br/>

Regenerate .GITATTRIBUTES

```powershell
# use after adding new resource files or new large files
.\scripts\generate-git-attributes.ps1
```

<br/>

Pull Resource Files Manually (from cdn.kongor.net)

```powershell
# use this to manually hydrate the distributions with resource files from object storage
# alternatively, use "install-git-aliases.ps1" to set up "git sync" which does this together with "git pull"
# this script needs to be executed every time resource files need to be pulled
.\scripts\pull-resource-files.ps1
```

<br/>

Install The `git sync` Alias

```powershell
# use this to install the "git sync" alias which pulls code and resource files in one step
# alternatively, use "pull-resource-files.ps1" if you prefer to pull resources manually
# this script needs to be executed only once per clone, for the alias to be active in the repository
.\scripts\install-git-aliases.ps1
```

<br/>

Pull Code And Resource Files Together (with `git sync`)

```powershell
# use this instead of "git pull" to pull both code and resource files in one step
# requires "install-git-aliases.ps1" to have been run once first
# the regular "git pull" still works for code-only updates
git sync
```

<br/>

Mirror Tracked Files To R2 (Automatic, On Push)

```powershell
# tracked files under "source/" are automatically mirrored to the "project-kongor" R2 bucket by a GitHub Actions workflow on every push to "main"
# the workflow uses "rclone sync" with credentials from repository secrets (R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_ENDPOINT)
# resource files (".s2z") are excluded from the mirror; they remain under control of the separate upload pipeline
# to re-trigger manually (after fixing the workflow or for an out-of-band re-sync), use the "Run workflow" button in the repository's Actions tab
git push
```

<br/>
