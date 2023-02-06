param (
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string] $DataLocation,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $BuildId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $OSVersion,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $PSVersion
)

function FillLiveTestAdditionalInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ (Test-Path -LiteralPath $_ -PathType Leaf) -and ($_ -like "*.csv") })]
        [string[]] $CsvFile,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $BuildId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $OSVersion,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PSVersion
    )

    $CsvFile | ForEach-Object {
        $moduleName = (Get-Item -Path $_).BaseName
        $simpleModuleName = $moduleName.Substring(3)

        (Import-Csv -LiteralPath $_) |
        Select-Object `
        @{ Name = "Source"; Expression = { "LiveTest" } }, `
        @{ Name = "BuildId"; Expression = { "$BuildId" } }, `
        @{ Name = "OSVersion"; Expression = { "$OSVersion" } }, `
        @{ Name = "PSVersion"; Expression = { "$PSVersion" } }, `
        @{ Name = "Module"; Expression = { "$simpleModuleName" } }, `
        @{ Name = "Name"; Expression = { $_.Name } }, `
        @{ Name = "Description"; Expression = { $_.Description } }, `
        @{ Name = "StartDateTime"; Expression = { $_.StartDateTime } }, `
        @{ Name = "EndDateTime"; Expression = { $_.EndDateTime } }, `
        @{ Name = "IsSuccess"; Expression = { $_.IsSuccess } },
        @{ Name = "Errors"; Expression = { $_.Errors } } |
        Export-Csv -LiteralPath $_ -Encoding utf8 -NoTypeInformation -Force
    }
}

function FillTestCoverageAdditionalInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $CsvFile,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $BuildId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $OSVersion,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PSVersion
    )

    Import-Module ($PSScriptRoot | Split-Path | Join-Path -ChildPath "Coverage" | Join-Path -ChildPath "TestCoverageUtility.psd1") -Force

    Add-TestCoverageAdditionalInfo -CsvFile $CsvFile -Source "LiveTest" -BuildId $BuildId -OSVersion $OSVersion -PSVersio $PSVersion
}


if ($PSVersion -eq "latest") {
    $PSVersion = (Get-Variable -Name PSVersionTable).Value.PSVersion.ToString()
}

$liveTestDir = Join-Path -Path $DataLocation -ChildPath "LiveTestAnalysis" | Join-Path -ChildPath "Raw"
$liveTestResult = Get-ChildItem -Path $liveTestDir -Filter "*.csv" -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
if ($null -ne $liveTestResult) {
    FillLiveTestAdditionalInfo -CsvFile $liveTestResult -BuildId $BuildId -OSVersion $OSVersion -PSVersion $PSVersion
}
else {
    Write-Host "##[warning]No live test data was found."
}

$testCoverageDir = Join-Path -Path $DataLocation -ChildPath "TestCoverageAnalysis" | Join-Path -ChildPath "Raw"
$testCoverageResult = Get-ChildItem -Path $testCoverageDir -Filter "*.csv" -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
if ($null -ne $testCoverageResult) {
    FillTestCoverageAdditionalInfo -CsvFile $testCoverageResult -BuildId $BuildId -OSVersion $OSVersion -PSVersion $PSVersion
}
else {
    Write-Host "##[warning]No test coverage data was found."
}
