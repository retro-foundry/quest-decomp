param(
    [string]$BeebAsm
)

$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot
$outputDirectory = Join-Path $repoRoot 'build\reconstruction'
$source = Join-Path $repoRoot 'source_bbc\quest1.asm'
$payload = Join-Path $outputDirectory 'QUEST1'
$labels = Join-Path $outputDirectory 'quest1.labels'

if (-not $BeebAsm) {
    $beebAsmCommand = Get-Command beebasm -ErrorAction SilentlyContinue
    if (-not $beebAsmCommand) {
        throw 'BeebAsm is required. Put beebasm on PATH or pass -BeebAsm <path>.'
    }
    $BeebAsm = $beebAsmCommand.Source
}

$BeebAsm = [System.IO.Path]::GetFullPath($BeebAsm)
if (-not (Test-Path -LiteralPath $BeebAsm -PathType Leaf)) {
    throw "BeebAsm executable does not exist: $BeebAsm"
}

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

Push-Location $repoRoot
try {
    & $BeebAsm -i $source -d -labels $labels
    if ($LASTEXITCODE -ne 0) {
        throw "BeebAsm failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $payload -PathType Leaf)) {
    throw "BeebAsm completed without producing the expected payload: $payload"
}

Write-Output "Rebuilt payload: $payload"
Write-Output "Labels:          $labels"
