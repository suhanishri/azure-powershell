param (
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string] $RepoLocation
)

$dataLocation = (Get-AzConfig -TestCoverageLocation).Value
if ([string]::IsNullOrWhiteSpace($dataLocation) -or !(Test-Path -LiteralPath $dataLocation -PathType Container)) {
    $dataLocation = Join-Path -Path $env:USERPROFILE -ChildPath ".Azure"
}

$srcDir = Join-Path -Path $RepoLocation -ChildPath "src"
$liveScenarios = Get-ChildItem -Path $srcDir -Recurse -Directory -Filter "LiveTests" | Get-ChildItem -Filter "TestLiveScenarios.ps1" -File

$rsp = [runspacefactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS + 1)
[void]$rsp.Open()

$liveJobs = $liveScenarios | ForEach-Object {
    $ps = [powershell]::Create()
    $ps.RunspacePool = $rsp
    $ps.AddScript({
            param (
                [string] $RepoLocation,
                [string] $DataLocation,
                [string] $LiveScenarioScriptFile
            )

            $moduleName = [regex]::match($LiveScenarioScriptFile, "[\\|\/]src[\\|\/](?<ModuleName>[a-zA-Z]+)[\\|\/]").Groups["ModuleName"].Value
            Import-Module "$RepoLocation/tools/TestFx/Assert.ps1" -Force
            Import-Module "$RepoLocation/tools/TestFx/Live/LiveTestUtility.psd1" -ArgumentList $moduleName,$DataLocation -Force
            . $LiveScenarioScriptFile
        }).AddParameter("RepoLocation", $RepoLocation).AddParameter("DataLocation", $dataLocation).AddParameter("LiveScenarioScriptFile", $_.FullName)

    [PSCustomObject]@{
        Id          = $ps.InstanceId
        Instance    = $ps
        AsyncResult = $ps.BeginInvoke()
    } | Add-Member State -MemberType ScriptProperty -PassThru -Value {
        $this.Instance.InvocationStateInfo.State
    }
}

do {
    Start-Sleep -Seconds 30
} while ($liveJobs.State -contains "Running")

$liveJobs | ForEach-Object {
    if ($null -ne $_.Instance) {
        Write-Host "##[group]Job $($_.Id) complete information:"
        $_.Instance.EndInvoke($_.AsyncResult)
        $_.Instance.Streams | Select-Object -Property @{ Name = "FullOutput"; Expression = { $_.Information, $_.Warning, $_.Error, $_.Debug } } | Select-Object -ExpandProperty FullOutput
        Write-Host "##[endgroup]"
        $_.Instance.Dispose()
    }
}
