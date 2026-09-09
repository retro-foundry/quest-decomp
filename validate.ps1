param(
    [string]$BeebAsm
)

$ErrorActionPreference = 'Stop'
$expectedLength = 0x3F20
$expectedSha256 = 'D83EADF906C83A1B1244F4ED85F34147C754FFA1AC5528738CB967185BCB528B'
$payload = Join-Path $PSScriptRoot 'build\reconstruction\QUEST1'

$requiredStandaloneFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
@(
    'tools/reconstruction/apply_variant.py'
    'tools/reconstruction/make_start_room_variant.py'
    'tools/reconstruction/quest_addr.py'
    'tools/runtime_trace/find_start_point.py'
    'tools/reconstruction/variants/sector_e_level_1.json'
) | ForEach-Object { [void]$requiredStandaloneFiles.Add($_) }

# Keep prose and source references honest: any repository-relative tool path
# mentioned by the maintained files becomes a validation dependency.
$referenceInputs = @((Join-Path $PSScriptRoot 'README.md'))
$referenceInputs += Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'source_bbc') -File -Recurse |
    Select-Object -ExpandProperty FullName
$toolReferencePattern = 'tools/[A-Za-z0-9_./-]+\.(?:py|ps1|json)'
foreach ($inputPath in $referenceInputs) {
    $inputText = Get-Content -LiteralPath $inputPath -Raw
    foreach ($match in [regex]::Matches($inputText, $toolReferencePattern)) {
        [void]$requiredStandaloneFiles.Add($match.Value)
    }
}

foreach ($relativePath in $requiredStandaloneFiles) {
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
