param(
    [string]$BeebAsm
)

$ErrorActionPreference = 'Stop'
$expectedLength = 0x3F20
$expectedSha256 = 'D83EADF906C83A1B1244F4ED85F34147C754FFA1AC5528738CB967185BCB528B'
$payload = Join-Path $PSScriptRoot 'build\reconstruction\QUEST1'

$requiredStandaloneTools = @(
    'tools\reconstruction\apply_variant.py'
    'tools\reconstruction\make_start_room_variant.py'
    'tools\reconstruction\quest_addr.py'
    'tools\runtime_trace\find_start_point.py'
    'tools\reconstruction\variants\sector_e_level_1.json'
)
foreach ($relativePath in $requiredStandaloneTools) {
    $requiredPath = Join-Path $PSScriptRoot $relativePath
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Standalone source dependency is missing: $relativePath"
    }
}

$variantDefinitions = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'tools\reconstruction\variants') -Filter '*.json' -File
if ($variantDefinitions.Count -eq 0) {
    throw 'Standalone source has no reconstruction variant definitions.'
}

& (Join-Path $PSScriptRoot 'build.ps1') -BeebAsm $BeebAsm

$actualLength = (Get-Item -LiteralPath $payload).Length
if ($actualLength -ne $expectedLength) {
    throw ('QUEST1 has length ${0:X}, expected ${1:X}.' -f $actualLength, $expectedLength)
}

$actualSha256 = (Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash
if ($actualSha256 -ne $expectedSha256) {
    throw "QUEST1 SHA-256 is $actualSha256, expected $expectedSha256."
}

Write-Output ('Validated QUEST1: {0} bytes, SHA-256 {1}' -f $actualLength, $actualSha256)
