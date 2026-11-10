# Builds the standalone ArchiveXL hairstyle from the vanilla buzzcut files.
# Nothing in the base game is replaced: a new option is added to the male V hairstyle picker.
# Expects the vanilla files already extracted into $Work\raw and male_cco serialized into $Work\json (see ..\build.ps1).
param(
  [Parameter(Mandatory)][string]$Cli,          # WolvenKit.CLI.exe
  [Parameter(Mandatory)][string]$Game,         # Cyberpunk 2077 install folder
  [Parameter(Mandatory)][string]$Work,         # scratch folder with raw\ and json\
  [Parameter(Mandatory)][string]$Mask,         # edited cap mask (.xbm)
  [Parameter(Mandatory)][string]$Out,          # folder that becomes the .archive
  [Parameter(Mandatory)][string]$XlOut,        # path of the .archive.xl to write
  [string]$DisplayName = "Receding Buzzcut"    # label shown in the character creator
)
$ErrorActionPreference = 'Continue'
$appArc = "$Game\archive\pc\content\basegame_4_appearance.archive"
$raw  = "$Work\raw"
$js   = "$Work\json"
$tmp  = "$Work\ccxl_tmp"
$P    = "receding_buzzcut"                     # mod-owned depot folder

function Esc([string]$p) { $p.Replace('\', '\\') }   # path as written inside WolvenKit JSON
function Deser([string]$json, [string]$destRel) {
  # JSON -> game file, placed at its depot path inside $Out
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  New-Item -ItemType Directory -Force $tmp | Out-Null
  $name = [IO.Path]::GetFileName($destRel)
  [IO.File]::WriteAllText("$tmp\$name.json", $json, (New-Object Text.UTF8Encoding $false))
  & $Cli convert deserialize "$tmp\$name.json" -o $tmp 2>$null | Out-Null
  if (-not (Test-Path "$tmp\$name")) { throw "Could not convert $name" }
  $dest = Join-Path $Out $destRel
  New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
  Move-Item "$tmp\$name" $dest -Force
}
function Ser([string]$file) {
  New-Item -ItemType Directory -Force $js | Out-Null
  & $Cli convert serialize $file -o $js 2>$null | Out-Null
  Get-Content -Raw -Encoding UTF8 (Join-Path $js ([IO.Path]::GetFileName($file) + ".json"))
}

if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
New-Item -ItemType Directory -Force $Out | Out-Null

$vanMaskN = 'base\characters\common\hair\hh_999_ma__buzz_cap\textures\hh_999_ma__cap_mask.xbm'
$vanMaskA = 'base\characters\common\hair\hh_999_ma__buzz_cap\textures\hh_999_ma__afro_buzz_cap_mask.xbm'
$vanMaskW = 'base\characters\common\hair\hh_999_ma__buzz_cap\textures\hh_999_wa__cap_mask.xbm'
$newMask  = "$P\textures\cap_mask_receding.xbm"
$vanMeshN = 'base\characters\common\hair\hh_999_ma__buzz_cap\hh_999_ma__buzz_cap.mesh'
$vanMeshC = 'base\characters\common\hair\hh_999_ma__buzz_cap\hh_999_pma__buzz_cap_cyberware_01.mesh'
$newMeshN = "$P\meshes\buzz_cap_receding.mesh"
$newMeshC = "$P\meshes\buzz_cap_receding_cyberware_01.mesh"
$vanAppN  = 'base\characters\head\player_base_heads\appearances\hairs\hh_013_pma__hairs_999.app'
$vanAppC  = 'base\characters\head\player_base_heads\appearances\hairs\hh_013_pma__hairs_999_cyberware_01.app'
$newAppN  = "$P\appearances\receding_buzzcut.app"
$newAppC  = "$P\appearances\receding_buzzcut_cyberware_01.app"
$newInkcc = "$P\receding_buzzcut_male.inkcharcustomization"

# 1) mask
New-Item -ItemType Directory -Force (Split-Path "$Out\$newMask") | Out-Null
Copy-Item $Mask "$Out\$newMask" -Force
"1/7 mask"

# 2) colour materials: copies of the buzzcut .mi files pointing at the new mask (one per hair colour)
$meshJson = Ser "$raw\$vanMeshN"
$mis = ([regex]::Matches($meshJson, '"(base\\\\characters\\\\common\\\\hair\\\\hh_999_ma__buzz_cap\\\\textures\\\\[^"]+\.mi)"') | ForEach-Object { $_.Groups[1].Value.Replace('\\','\') }) | Sort-Object -Unique
$missing = $mis | Where-Object { -not (Test-Path "$raw\$_") }
if ($missing) {
  $rx = ($missing | ForEach-Object { [regex]::Escape([IO.Path]::GetFileName($_)) + '$' }) -join '|'
  & $Cli extract $appArc -o $raw -r $rx 2>$null | Out-Null
}
foreach ($mi in $mis) {
  $j = Ser "$raw\$mi"
  $j = $j.Replace((Esc $vanMaskN), (Esc $newMask)).Replace((Esc $vanMaskA), (Esc $newMask))
  $newMi = "$P\materials\" + [IO.Path]::GetFileName($mi)
  Deser $j $newMi
  $meshJson = $meshJson.Replace('"' + (Esc $mi) + '"', '"' + (Esc $newMi) + '"')
}
"2/7 materials: $($mis.Count)"

# 3) meshes
Deser $meshJson $newMeshN
$cwJson = Ser "$raw\$vanMeshC"
$cwJson = $cwJson.Replace((Esc $vanMaskN), (Esc $newMask)).Replace((Esc $vanMaskA), (Esc $newMask)).Replace((Esc $vanMaskW), (Esc $newMask))
Deser $cwJson $newMeshC
"3/7 meshes"

# 4) appearances (.app)
$a = (Ser "$raw\$vanAppN").Replace((Esc $vanMeshN), (Esc $newMeshN))
Deser $a $newAppN
$a = (Ser "$raw\$vanAppC").Replace((Esc $vanMeshC), (Esc $newMeshC))
Deser $a $newAppC
"4/7 appearances"

# 5) character creator option (.inkcharcustomization), derived from the vanilla male_cco
$src = Get-Content -Raw -Encoding UTF8 "$js\male_cco.inkcharcustomization.json" | ConvertFrom-Json
$opts = $src.Data.RootChunk.headCustomizationOptions
function FindOpt($name) { foreach ($o in $opts) { if ($o.Data.name.'$value' -eq $name) { return ($o.Data | ConvertTo-Json -Depth 60 | ConvertFrom-Json) } }; throw "Option $name not found" }
function CName($v) { [pscustomobject]@{ '$type'='CName'; '$storage'='string'; '$value'=$v } }

# hair colour pickers (one per variant); indices must be unique among all head options
$apN = FindOpt 'hair_color14'
$apN.name = CName 'receding_buzzcut'; $apN.resource.DepotPath.'$value' = $newAppN; $apN.index = 30001
$apC = FindOpt 'hair_color_cyberware_14'
$apC.name = CName 'receding_buzzcut_cw'; $apC.resource.DepotPath.'$value' = $newAppC; $apC.index = 30002

# hairstyle switchers: one new entry each; first person reuses the vanilla buzzcut (the hairline is not visible in FPP)
$swN = FindOpt 'hairstyle'
$optN = $swN.options | Where-Object { $_.localizedName -eq '14' } | Select-Object -First 1
$optN.localizedName = $DisplayName; $optN.index = 0
$optN.names = @((CName 'receding_buzzcut'), (CName 'hair_color_fpp_14'))
$swN.options = @($optN); $swN.name = CName 'None'; $swN.index = 0

$swC = FindOpt 'hairstyle_cyberware'
$optC = $swC.options | Where-Object { $_.localizedName -eq '14' } | Select-Object -First 1
$optC.localizedName = $DisplayName; $optC.index = 0
$optC.names = @((CName 'receding_buzzcut_cw'), (CName 'hair_color_fpp_14'))
$swC.options = @($optC); $swC.link = CName 'None'; $swC.index = 0

$rc = $src.Data.RootChunk
foreach ($k in 'armsCustomizationOptions','armsGroups','bodyCustomizationOptions','bodyGroups','excludedFromRandomize','headGroups','perspectiveInfo','uiPresets','versionUpdateInfo') { $rc.$k = @() }
# groups: "hairs" applies the hairstyle and its colour (without it the colour picker does nothing);
# "character_customization" is the editor's general group. ArchiveXL merges both into the vanilla groups.
function New-OptGroup($gname, $members) { [pscustomobject]@{ '$type'='gameuiOptionsGroup'; name=(CName $gname); options=@($members | ForEach-Object { CName $_ }) } }
$rc.headGroups = @((New-OptGroup 'hairs' @('receding_buzzcut','receding_buzzcut_cw')), (New-OptGroup 'character_customization' @('receding_buzzcut','receding_buzzcut_cw')))
$i = 0
$rc.headCustomizationOptions = @($apN, $apC, $swN, $swC) | ForEach-Object { [pscustomobject]@{ HandleId = "$i"; Data = $_ }; $i++ }
$src.Header.ArchiveFileName = ""
Deser ($src | ConvertTo-Json -Depth 100) $newInkcc
"5/7 character creator option"

# 6) ArchiveXL tint base material (CapBaseMaterial), copied with our mask
$axlArc = "$Game\red4ext\plugins\ArchiveXL\Bundle\ArchiveXL.archive"
$axlCapN = 'archive_xl\characters\common\hair\textures\hair_profiles\hh_999_ma__buzz_cap_cap.mi'
$axlCapC = 'archive_xl\characters\common\hair\textures\hair_profiles\hh_999_pma__buzz_cap_cyberware_01_cap.mi'
if (-not (Test-Path "$raw\$axlCapN") -or -not (Test-Path "$raw\$axlCapC")) { & $Cli extract $axlArc -o $raw -r "hh_999_(ma__buzz_cap|pma__buzz_cap_cyberware_01)_cap\.mi" 2>$null | Out-Null }
$newCapN = "$P\materials\cap_base_receding.mi"
$newCapC = "$P\materials\cap_base_receding_cyberware_01.mi"
foreach ($pair in @(@($axlCapN,$newCapN), @($axlCapC,$newCapC))) {
  $j = (Ser "$raw\$($pair[0])").Replace((Esc $vanMaskN), (Esc $newMask)).Replace((Esc $vanMaskA), (Esc $newMask)).Replace((Esc $vanMaskW), (Esc $newMask))
  Deser $j $pair[1]
}
"6/7 tint base materials"

# 7) .archive.xl: character creator entry + registration in ArchiveXL's hair tint system
$fixLines = Get-Content "$Game\red4ext\plugins\ArchiveXL\Bundle\PlayerCustomizationHairFix.xl"
function FixNames([string]$vanMesh) {
  $start = [Array]::IndexOf($fixLines, "    ${vanMesh}:")
  if ($start -lt 0) { throw "$vanMesh not found in PlayerCustomizationHairFix.xl" }
  $res = @(); for ($k = $start + 1; $k -lt $fixLines.Count; $k++) { if ($fixLines[$k] -match '^\s{6}context:') { break }; $res += $fixLines[$k] }
  return $res -join "`n"
}
$xl = @"
customizations:
  male: $newInkcc
resource:
  scope:
    player_ma_hair_cw_00.app:
      - $newAppN
    player_ma_hair_cw_01.app:
      - $newAppC
    player_ma_hair.mesh:
      - $newMeshN
      - $newMeshC
  fix:
    ${newMeshN}:
$(FixNames $vanMeshN)
      context:
        CapBaseMaterial: $newCapN
    ${newMeshC}:
$(FixNames $vanMeshC)
      context:
        CapBaseMaterial: $newCapC
"@
$xl = $xl.Replace("`r`n", "`n") + "`n"
[IO.File]::WriteAllText($XlOut, $xl, (New-Object Text.UTF8Encoding $false))
"7/7 .archive.xl"
