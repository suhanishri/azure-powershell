param (
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [guid] $ServicePrincipalTenantId,

    [Parameter(Mandatory, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [guid] $ServicePrincipalId,

    [Parameter(Mandatory, Position = 2)]
    [ValidateNotNullOrEmpty()]
    [string] $ServicePrincipalSecret,

    [Parameter(Mandatory, Position = 3)]
    [ValidateNotNullOrEmpty()]
    [string] $ClusterName,

    [Parameter(Mandatory, Position = 4)]
    [ValidateNotNullOrEmpty()]
    [string] $ClusterRegion,

    [Parameter(Mandatory, Position = 5)]
    [ValidateNotNullOrEmpty()]
    [string] $DatabaseName,

    [Parameter(Mandatory, Position = 6)]
    [ValidateNotNullOrEmpty()]
    [string] $LiveTestTableName,

    [Parameter(Mandatory, Position = 7)]
    [ValidateNotNullOrEmpty()]
    [string] $TestCoverageTableName,

    [Parameter(Mandatory, Position = 8)]
    [ValidateNotNullOrEmpty()]
    [string] $BuildId,

    [Parameter(Mandatory, Position = 9)]
    [ValidateNotNullOrEmpty()]
    [string] $OSVersion,

    [Parameter(Mandatory, Position = 10)]
    [ValidateNotNullOrEmpty()]
    [string] $PSVersion,

    [Parameter(Mandatory, Position = 11)]
    [ValidateNotNullOrEmpty()]
    [string] $DataLocation
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

Import-Module "./tools/TestFx/Utilities/KustoUtility.psd1" -Force

$liveTestDir = Join-Path -Path $DataLocation -ChildPath "LiveTestAnalysis" | Join-Path -ChildPath "Raw"
$liveTestResults = Get-ChildItem -Path $liveTestDir -Filter "*.csv" -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
if (![string]::IsNullOrWhiteSpace($liveTestResults) -and (Test-Path -LiteralPath $liveTestResults -PathType Leaf)) {
    FillLiveTestAdditionalInfo -CsvFile $liveTestResults -BuildId $BuildId -OSVersion $OSVersion -PSVersion $PSVersion
    Import-KustoDataFromCsv `
        -ServicePrincipalTenantId $ServicePrincipalTenantId `
        -ServicePrincipalId $ServicePrincipalId `
        -ServicePrincipalSecret $ServicePrincipalSecret `
        -ClusterName $ClusterName `
        -ClusterRegion $ClusterRegion `
        -DatabaseName $DatabaseName `
        -TableName $LiveTestTableName `
        -CsvFile $liveTestResults
}
else {
    Write-Host "##[warning]No live test data was found."
}

$testCoverageDir = Join-Path -Path $DataLocation -ChildPath "TestCoverageAnalysis" | Join-Path -ChildPath "Raw"
$testCoverageResults = Get-ChildItem -Path $testCoverageDir -Filter "*.csv" -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
if (![string]::IsNullOrWhiteSpace($testCoverageResults) -and (Test-Path -LiteralPath $testCoverageResults -PathType Leaf)) {
    FillTestCoverageAdditionalInfo -CsvFile $testCoverageResults -BuildId $BuildId -OSVersion $OSVersion -PSVersion $PSVersion
    Import-KustoDataFromCsv `
        -ServicePrincipalTenantId $ServicePrincipalTenantId `
        -ServicePrincipalId $ServicePrincipalId `
        -ServicePrincipalSecret $ServicePrincipalSecret `
        -ClusterName $ClusterName `
        -ClusterRegion $ClusterRegion `
        -DatabaseName $DatabaseName `
        -TableName $TestCoverageTableName `
        -CsvFile $testCoverageResults
}
else {
    Write-Host "##[warning]No test coverage data was found."
}
