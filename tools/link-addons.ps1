# Links the repo's addon folders into the WoW Forever AddOns folder using directory junctions
# (no admin rights needed). Safe to re-run. Pass -Unlink to remove the links.
param(
    [string]$AddOns = 'C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns',
    [switch]$Unlink
)

$repo = Resolve-Path (Join-Path $PSScriptRoot '..')
$addonNames = @('Azerfolio', 'AzerfolioDiag')   # note: PowerShell names are case-insensitive; don't reuse $AddOns

foreach ($name in $addonNames) {
    $source = Join-Path $repo $name
    $target = Join-Path $AddOns $name
    $existing = Get-Item $target -ErrorAction SilentlyContinue

    if ($Unlink) {
        if ($existing -and $existing.LinkType -eq 'Junction') {
            $existing.Delete()   # removes the junction only, never the repo folder
            Write-Output "Unlinked $name"
        }
        continue
    }

    if (-not (Test-Path $source)) { Write-Output "Skip $name (not in repo yet)"; continue }
    if ($existing) {
        if ($existing.LinkType -eq 'Junction') { Write-Output "Already linked: $name"; continue }
        Write-Output "Skip $name - a real folder already exists at $target; remove it manually first"
        continue
    }
    New-Item -ItemType Junction -Path $target -Target $source | Out-Null
    Write-Output "Linked $name -> $source"
}
