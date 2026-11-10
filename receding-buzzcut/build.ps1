# Builds the Receding Buzzcut mod from your own game files.
#   .\build.ps1                                   # build into .\dist
#   .\build.ps1 -Zip                              # also create the Nexus release ZIP
#   .\build.ps1 -Install                          # also copy the mod into the game
#   .\build.ps1 -TempleLine 280 -TopDensity 0.6   # generate a new hairline instead of the released one (see scripts\hairline_mask.ps1)
param(
  [string]$GamePath  = "C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077",
  [string]$WolvenKit = "$PSScriptRoot\..\tools\wolvenkit-cli\WolvenKit.CLI.exe",
  [string]$Version   = "1.0.0",
  [switch]$Zip,
  [switch]$Install,
  [switch]$Regenerate,   # generate the mask procedurally even without shape parameters
  # hairline shape (forwarded to scripts\hairline_mask.ps1). Passing any of these regenerates the mask.
  [double]$CenterLine = 70, [double]$TempleLine = 200, [double]$TempleX = 210, [double]$VPower = 1.15, [double]$Roundness = 1.0,
  [double]$SideFalloff = 110, [double]$EdgeSoft = 18,
  [double]$TopDensity = 0.5, [double]$TopWidth = 200, [double]$TopEndY = 520,
  [double]$FrontDensity = 0.85, [double]$FrontBand = 70, [double]$CrownThin = 0.10,
  [double]$Grain = 3, [int]$Seed = 1977
)
$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
$work = "$root\work"; $dist = "$root\dist"
$mod  = "receding_buzzcut"
if (-not (Test-Path $WolvenKit)) { throw "WolvenKit CLI not found at $WolvenKit (use -WolvenKit)" }
if (-not (Test-Path "$GamePath\archive\pc\content")) { throw "Game not found at $GamePath (use -GamePath)" }
if (-not (Test-Path "$GamePath\red4ext\plugins\ArchiveXL\Bundle\ArchiveXL.archive")) { throw "ArchiveXL is not installed in $GamePath" }
$content = "$GamePath\archive\pc\content"
$maskRel = "base\characters\common\hair\hh_999_ma__buzz_cap\textures"
New-Item -ItemType Directory -Force $work, $dist | Out-Null

# 1) vanilla files (extracted once, then cached in .\work)
if (-not (Test-Path "$work\uncooked\$maskRel\hh_999_ma__cap_mask.png")) {
  "Extracting the vanilla cap mask..."
  & $WolvenKit uncook $content -o "$work\uncooked" -r 'hh_999_ma__cap_mask\.xbm$' --uext png 2>$null | Out-Null
}
$need = @(
  'base\characters\common\hair\hh_999_ma__buzz_cap\hh_999_ma__buzz_cap.mesh',
  'base\characters\common\hair\hh_999_ma__buzz_cap\hh_999_pma__buzz_cap_cyberware_01.mesh',
  'base\characters\head\player_base_heads\appearances\hairs\hh_013_pma__hairs_999.app',
  'base\characters\head\player_base_heads\appearances\hairs\hh_013_pma__hairs_999_cyberware_01.app',
  'base\gameplay\gui\fullscreen\main_menu\male_cco.inkcharcustomization')
if ($need | Where-Object { -not (Test-Path "$work\raw\$_") }) {
  "Extracting vanilla meshes, appearances and the character creator file..."
  & $WolvenKit extract $content -o "$work\raw" -r 'hh_999_ma__buzz_cap\.mesh$|hh_999_pma__buzz_cap_cyberware_01\.mesh$|hh_013_pma__hairs_999(_cyberware_01)?\.app$|male_cco\.inkcharcustomization$' 2>$null | Out-Null
}
$missing = $need | Where-Object { -not (Test-Path "$work\raw\$_") }
if ($missing) { throw "Could not extract: $($missing -join ', ')" }
if (-not (Test-Path "$work\json\male_cco.inkcharcustomization.json")) {
  New-Item -ItemType Directory -Force "$work\json" | Out-Null
  & $WolvenKit convert serialize "$work\raw\$($need[4])" -o "$work\json" 2>$null | Out-Null
}
"1/4 vanilla files ready"

# 2) hairline mask: png -> xbm (re-using the vanilla xbm settings)
#    By default the released mask (assets\cap_mask_receding.png) is used, so the build reproduces the published mod.
#    Passing any hairline parameter (or -Regenerate) generates a new mask procedurally instead.
$maskPng = "$work\mask_raw\$maskRel\hh_999_ma__cap_mask.png"
New-Item -ItemType Directory -Force (Split-Path $maskPng), "$work\mask_red\$maskRel" | Out-Null
$shapeParams = 'CenterLine','TempleLine','TempleX','VPower','Roundness','SideFalloff','EdgeSoft','TopDensity','TopWidth','TopEndY','FrontDensity','FrontBand','CrownThin','Grain','Seed'
if ($Regenerate -or ($PSBoundParameters.Keys | Where-Object { $shapeParams -contains $_ })) {
  & "$root\scripts\hairline_mask.ps1" -In "$work\uncooked\$maskRel\hh_999_ma__cap_mask.png" -Out $maskPng -Preview "$dist\hairline_preview.png" `
    -CenterLine $CenterLine -TempleLine $TempleLine -TempleX $TempleX -VPower $VPower -Roundness $Roundness -SideFalloff $SideFalloff `
    -EdgeSoft $EdgeSoft -TopDensity $TopDensity -TopWidth $TopWidth -TopEndY $TopEndY -FrontDensity $FrontDensity -FrontBand $FrontBand `
    -CrownThin $CrownThin -Grain $Grain -Seed $Seed | Out-Null
  "   generated a new mask (preview: $dist\hairline_preview.png)"
} else {
  Copy-Item "$root\assets\cap_mask_receding.png" $maskPng -Force
  "   using the released mask (assets\cap_mask_receding.png)"
}
Copy-Item "$work\uncooked\$maskRel\hh_999_ma__cap_mask.xbm" "$work\mask_red\$maskRel\" -Force
& $WolvenKit import "$work\mask_raw" -o "$work\mask_red" -k 2>$null | Out-Null   # exit code 3 "No buffers found" is expected
"2/4 hairline mask"

# 3) mod files
& "$root\scripts\build_ccxl.ps1" -Cli $WolvenKit -Game $GamePath -Work $work -Mask "$work\mask_red\$maskRel\hh_999_ma__cap_mask.xbm" `
  -Out "$work\$mod" -XlOut "$dist\$mod.archive.xl" | Out-Null
& $WolvenKit pack "$work\$mod" -o $dist 2>$null | Out-Null
if (-not (Test-Path "$dist\$mod.archive")) { throw "Packing failed" }
"3/4 built: $dist\$mod.archive + .archive.xl"

# 4) release ZIP / install
if ($Zip) {
  Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
  $zipPath = "$dist\Receding_Buzzcut-$Version.zip"
  if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
  $readme = (Get-Content -Raw "$root\release\README.txt") -replace 'Version: .*', "Version: $Version"
  $z = [IO.Compression.ZipFile]::Open($zipPath, 'Create')
  [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($z, "$dist\$mod.archive", "archive/pc/mod/$mod.archive", 'Optimal')
  [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($z, "$dist\$mod.archive.xl", "archive/pc/mod/$mod.archive.xl", 'Optimal')
  $e = $z.CreateEntry('README.txt'); $w = New-Object IO.StreamWriter($e.Open()); $w.Write($readme); $w.Dispose()
  $z.Dispose()
  "ZIP: $zipPath"
}
if ($Install) {
  Copy-Item "$dist\$mod.archive", "$dist\$mod.archive.xl" "$GamePath\archive\pc\mod\" -Force -ErrorAction Stop
  "Installed into $GamePath\archive\pc\mod"
}
"4/4 done"

