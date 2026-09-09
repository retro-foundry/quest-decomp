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
    'analysis/runtime_memory_map.json'
) | ForEach-Object { [void]$requiredStandaloneFiles.Add($_) }

# Keep prose and source references honest: any repository-relative tools or
# source path mentioned by the maintained files becomes a validation dependency.
$referenceInputs = @((Join-Path $PSScriptRoot 'README.md'))
$referenceInputs += Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'source_bbc') -File -Recurse |
    Select-Object -ExpandProperty FullName
$referenceInputs += Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'tools') -File -Recurse |
    Where-Object { $_.Extension -in @('.py', '.ps1', '.json', '.md') } |
    Select-Object -ExpandProperty FullName
$standaloneReferencePattern = '(?:tools|source_bbc)/[A-Za-z0-9_./-]+\.(?:py|ps1|json|md|asm|inc)'
foreach ($inputPath in $referenceInputs) {
    $inputText = Get-Content -LiteralPath $inputPath -Raw
    foreach ($match in [regex]::Matches($inputText, $standaloneReferencePattern)) {
        [void]$requiredStandaloneFiles.Add($match.Value)
    }
}

foreach ($relativePath in $requiredStandaloneFiles) {
    $requiredPath = Join-Path $PSScriptRoot $relativePath
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Standalone source dependency is missing: $relativePath"
    }
}

$asciiInputs = @(
    (Join-Path $PSScriptRoot 'README.md')
    (Join-Path $PSScriptRoot 'build.ps1')
    (Join-Path $PSScriptRoot 'validate.ps1')
)
$asciiExtensions = @('.asm', '.inc', '.json', '.md', '.ps1', '.py')
$asciiInputs += Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'source_bbc') -File -Recurse |
    Where-Object { $_.Extension -in $asciiExtensions } |
    Select-Object -ExpandProperty FullName
$asciiInputs += Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'tools') -File -Recurse |
    Where-Object { $_.Extension -in $asciiExtensions } |
    Select-Object -ExpandProperty FullName
foreach ($asciiPath in $asciiInputs) {
    $nonAsciiByte = [System.IO.File]::ReadAllBytes($asciiPath) |
        Where-Object { $_ -gt 0x7F } |
        Select-Object -First 1
    if ($null -ne $nonAsciiByte) {
        throw "Standalone maintained file is not ASCII-only: $asciiPath"
    }
}

# Executable operands must use named constants or labels. Raw values remain
# appropriate in data declarations and exact layout assertions, but not in the
# reconstructed 6502 instruction stream.
$assemblySource = Join-Path $PSScriptRoot 'source_bbc\quest1.asm'
$assemblyText = Get-Content -LiteralPath $assemblySource -Raw
$numericInstructionPattern = '(?im)^\s*(?:ADC|AND|ASL|BIT|CMP|CPX|CPY|DEC|EOR|INC|JMP|JSR|LDA|LDX|LDY|LSR|ORA|ROL|ROR|SBC|STA|STX|STY)\s+#?(?:&[0-9A-F]+|\$[0-9A-F]+|%[01]+|[0-9]+)(?:\s*,\s*[XY])?\s*(?:;.*)?$'
$numericInstructions = [regex]::Matches($assemblyText, $numericInstructionPattern)
if ($numericInstructions.Count -ne 0) {
    $firstNumericInstruction = $numericInstructions[0].Value.Trim()
    throw "Raw numeric operand in quest1.asm; use a named constant or label: $firstNumericInstruction"
}
$relativeNumericOperandPattern = '(?im)^\s*(?:ADC|AND|ASL|BIT|CMP|CPX|CPY|DEC|EOR|INC|JMP|JSR|LDA|LDX|LDY|LSR|ORA|ROL|ROR|SBC|STA|STX|STY)\s+.*[A-Z_][A-Z0-9_]*[+-][0-9]+(?:\s*,\s*[XY])?\s*(?:;.*)?$'
$relativeNumericOperands = [regex]::Matches($assemblyText, $relativeNumericOperandPattern)
if ($relativeNumericOperands.Count -ne 0) {
    $firstRelativeNumericOperand = $relativeNumericOperands[0].Value.Trim()
    throw "Raw symbol-relative operand in quest1.asm; use a named offset or alias: $firstRelativeNumericOperand"
}

$variantDefinitions = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'tools\reconstruction\variants') -Filter '*.json' -File
if ($variantDefinitions.Count -eq 0) {
    throw 'Standalone source has no reconstruction variant definitions.'
}

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCommand) {
    throw 'Python is required to validate the bundled reconstruction tools.'
}

$pythonTools = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'tools') -Filter '*.py' -File -Recurse
foreach ($pythonTool in $pythonTools) {
    & $pythonCommand.Source -c "import ast, pathlib, sys; ast.parse(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))" $pythonTool.FullName
    if ($LASTEXITCODE -ne 0) {
        throw "Python syntax validation failed: $($pythonTool.FullName)"
    }
}

foreach ($variantDefinition in $variantDefinitions) {
    try {
        Get-Content -LiteralPath $variantDefinition.FullName -Raw | ConvertFrom-Json | Out-Null
    }
    catch {
        throw "Invalid reconstruction variant JSON: $($variantDefinition.FullName): $_"
    }
}

& (Join-Path $PSScriptRoot 'build.ps1') -BeebAsm $BeebAsm

$variantSmokeOutput = Join-Path $PSScriptRoot 'build\reconstruction\QUEST1-validation-variant'
& $pythonCommand.Source (Join-Path $PSScriptRoot 'tools\reconstruction\apply_variant.py') `
    --variant sector_e_level_1 --output-payload $variantSmokeOutput | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'Bundled reconstruction variant smoke test failed.'
}
if (-not (Test-Path -LiteralPath $variantSmokeOutput -PathType Leaf)) {
    throw 'Bundled reconstruction variant smoke test produced no payload.'
}
Remove-Item -LiteralPath $variantSmokeOutput

$actualLength = (Get-Item -LiteralPath $payload).Length
if ($actualLength -ne $expectedLength) {
    throw ('QUEST1 has length ${0:X}, expected ${1:X}.' -f $actualLength, $expectedLength)
}

$actualSha256 = (Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash
if ($actualSha256 -ne $expectedSha256) {
    throw "QUEST1 SHA-256 is $actualSha256, expected $expectedSha256."
}

Write-Output ('Validated QUEST1: {0} bytes, SHA-256 {1}' -f $actualLength, $actualSha256)
