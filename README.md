# Cyberpunk 2077 mods

Source and build scripts for my Cyberpunk 2077 mods. Each mod lives in its own folder with its own README.

| Mod | What it does | Nexus |
|---|---|---|
| [Receding Buzzcut](receding-buzzcut/) | New hairstyle for male V: short buzzcut with a rounded receding hairline. Tintable, facial-cyberware variant, replaces nothing. | [mods/38003](https://www.nexusmods.com/cyberpunk2077/mods/38003) |

## What is (and is not) in this repo

The repo contains scripts, documentation and the mods' own edited assets (for example a redrawn texture mask).
No original game files are committed: every build extracts what it needs from **your own installed copy of the
game**, so you need a legal install to rebuild anything.
Build outputs (`work/`, `dist/`, `*.archive`, `*.zip`) are git-ignored.

## Requirements

- **Windows** with **Windows PowerShell 5.1** (included in Windows 10/11). The scripts use C# through `Add-Type`
  and `System.Drawing`, so no Python or other runtime is needed.
- **Cyberpunk 2077** (built and tested on 2.5, Steam).
- **[WolvenKit CLI](https://github.com/WolvenKit/WolvenKit/releases)** 9.1.1 or newer. By default the scripts look for it in
  `tools/wolvenkit-cli/WolvenKit.CLI.exe` next to this repo's folders (git-ignored); pass `-WolvenKit <path>` to use another location.
- The runtime requirements of each mod installed in the game (for example **ArchiveXL** + **RED4ext**), because the
  build reads some of their files.

## Layout

```
cyberpunk-mods/
├── README.md               this file
├── tools/                  (not committed) WolvenKit CLI
└── <mod-name>/
    ├── README.md           what the mod does, how it works, how to build it
    ├── build.ps1           one-command build
    ├── scripts/            build steps
    └── release/            files shipped inside the release ZIP
```

## Building a mod

```powershell
cd <mod-name>
.\build.ps1 -Zip          # outputs go to <mod-name>\dist
```

If PowerShell refuses to run scripts, allow them for the current session first:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

## Legal

The scripts and documentation in this repo are released under the [MIT License](LICENSE). Game assets are not
included and remain the property of CD PROJEKT RED. Cyberpunk 2077 is a trademark of CD PROJEKT S.A. These mods are fan-made and not affiliated with or endorsed by
CD PROJEKT RED. They follow CDPR's [fan content guidelines](https://www.cdprojektred.com/en/fan-content).
