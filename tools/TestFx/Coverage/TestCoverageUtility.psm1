# ----------------------------------------------------------------------------------
# Copyright Microsoft Corporation
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------------------------------------------------------------

$script:AzPSCommonParameters = @("-Break", "-Confirm", "-Debug", "-DefaultProfile", "-ErrorAction", "-ErrorVariable", "-HttpPipelineAppend", "-HttpPipelinePrepend", "-InformationAction", "-InformationVariable",
    "-OutBuffer", "-OutVariable", "-PassThru", "-PipelineVariable", "-Proxy", "-ProxyCredential", "-ProxyUseDefaultCredentials", "-Verbose", "-WarningAction", "-WarningVariable", "-WhatIf")

function Get-TestCoverageModuleDetails {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $Module
    )

    [hashtable] $ModuleDetails = @{}

    $Module
    $moduleCommands = $Module.ExportedCmdlets.Keys + $Module.ExportedFunctions.Keys
    $totalCommands = $moduleCommands.Count
    $moduleCommands

    $totalParameterSets = 0
    $totalParameters = 0
    $moduleCommands | ForEach-Object {
        $command = Get-Command -Name $_
        $totalParameterSets += $command.ParameterSets.Count

        $commandParams = $command.Parameters
        $commandParams.Keys | ForEach-Object {
            if ($_ -notin $script:AzPSCommonParameters) {
                $totalParameters += $commandParams[$_].ParameterSets.Count
            }
        }
    }

    $ModuleDetails = @{ TotalCommands = $totalCommands; TotalParameterSets = $totalParameterSets; TotalParameters = $totalParameters }
    $ModuleDetails
}

function Add-TestCoverageAdditionalInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ (Test-Path -LiteralPath $_ -PathType Leaf) -and ($_ -like "*.csv") })]
        [string[]] $CsvFile,

        [Parameter(Mandatory)]
        [ValidateSet("CITest", "SmokeTest", "LiveTest")]
        [string] $Source,

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
        $module = Get-Module -Name $moduleName
        Write-Host "Print loaded modules:"
        Get-Module
        $module | fl
        if ($null -eq $module) {
            Write-Host "Module $moduleName is null. Getting list available modules."
            Write-Host "Print list available modules:"
            Get-Module -ListAvailable
            $module = Get-Module -Name $moduleName -ListAvailable
            $module | fl
        }

        $moduleCommands = $module.ExportedCmdlets.Keys + $module.ExportedFunctions.Keys
        $totalCommands = $moduleCommands.Count
        $moduleCommands

        $totalParameterSets = 0
        $totalParameters = 0
        $moduleCommands | ForEach-Object {
            $command = Get-Command -Name $_
            $totalParameterSets += $command.ParameterSets.Count

            $commandParams = $command.Parameters
            $commandParams.Keys | ForEach-Object {
                if ($_ -notin $script:AzPSCommonParameters) {
                    $totalParameters += $commandParams[$_].ParameterSets.Count
                }
            }
        }

        $moduleDetails = @{ TotalCommands = $totalCommands; TotalParameterSets = $totalParameterSets; TotalParameters = $totalParameters }

        (Import-Csv -Path $_) |
        Select-Object `
        @{ Name = "Source"; Expression = { $Source } }, `
        @{ Name = "BuildId"; Expression = { "$BuildId" } }, `
        @{ Name = "OSVersion"; Expression = { "$OSVersion" } }, `
        @{ Name = "PSVersion"; Expression = { "$PSVersion" } }, `
        @{ Name = "Module"; Expression = { "$simpleModuleName" } }, `
        @{ Name = "CommandName"; Expression = { $_.CommandName } }, `
        @{ Name = "TotalCommands"; Expression = { "$($moduleDetails['TotalCommands'])" } }, `
        @{ Name = "ParameterSetName"; Expression = { $_.ParameterSetName } }, `
        @{ Name = "TotalParameterSets"; Expression = { "$($moduleDetails['TotalParameterSets'])" } }, `
        @{ Name = "Parameters"; Expression = { $_.Parameters } }, `
        @{ Name = "TotalParameters"; Expression = { "$($moduleDetails['TotalParameters'])" } }, `
        @{ Name = "SourceScript"; Expression = { $_.SourceScript } }, `
        @{ Name = "LineNumber"; Expression = { $_.LineNumber } }, `
        @{ Name = "StartDateTime"; Expression = { $_.StartDateTime } }, `
        @{ Name = "EndDateTime"; Expression = { $_.EndDateTime } }, `
        @{ Name = "IsSuccess"; Expression = { $_.IsSuccess } } |
        Export-Csv -Path $_ -Encoding utf8 -NoTypeInformation -Force
    }
}
