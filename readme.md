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
# alternatively, use "install-git-hooks.ps1" for hooks which do this automatically on pull and checkout
# this script needs to be executed every time resource files need to be pulled
.\scripts\pull-resource-files.ps1
```

<br/>

Pull Resource Files Automatically (from cdn.kongor.net)

```powershell
# use this to install hooks which automatically hydrate the distributions with resource files from object storage on pull and checkout
# alternatively, use "pull-resource-files.ps1" if you prefer to do this manually
# this script needs to be executed only once per clone, for the hooks to be active in the repository
.\scripts\install-git-hooks.ps1
```

<br/>
