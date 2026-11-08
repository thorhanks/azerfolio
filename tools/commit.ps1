# Commits staged or listed changes with a message from a file (PowerShell 5.1 mangles quotes
# in arguments, so messages always go through a file).
# Usage: powershell -File tools/commit.ps1 -MessageFile <path> [-Paths <path>,<path>...] [-All]
#   -Paths: git add these first. -All: git add -A for Azerfolio, AzerfolioDiag, tools, tests, docs,
#   mockups, art and the root docs (never the SavedVariables, which live outside the repo).
# Prints the new commit and a short status.
param(
    [Parameter(Mandatory = $true)][string]$MessageFile,
    [string[]]$Paths,
    [switch]$All
)
# Not "Stop": git writes warnings (LF/CRLF) to stderr, which PowerShell 5.1 turns into errors.
# Exit codes are checked instead.
$git = "C:\Users\thorh\AppData\Local\GitHubDesktop\app-3.6.10\resources\app\git\cmd\git.exe"
if (-not (Test-Path $git)) { Write-Error "git not found at $git (GitHub Desktop updated? fix the path here and in CLAUDE.md)"; exit 1 }
Set-Location (Split-Path $PSScriptRoot -Parent)
# -c core.safecrlf=false silences the LF/CRLF warnings.
$addPaths = @()
if ($All) {
    $roots = "Azerfolio", "AzerfolioDiag", "tools", "tests", "docs", "mockups", "art", "*.md", ".claude", ".gitignore"
    $addPaths += $roots | Where-Object { Test-Path $_ }
}
if ($Paths) { $addPaths += $Paths }
if ($addPaths.Count -gt 0) {
    & $git -c core.safecrlf=false add -A -- $addPaths
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
& $git commit -q -F $MessageFile
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $git log --oneline -1
& $git status --short
