. .\tools\utils.ps1

$buildNumber = ($env:APPVEYOR_BUILD_NUMBER, "0" -ne $null)[0]
$version = Get-VersionFromTag

Update-AppveyorBuild -Version "$version.$buildNumber"

if($env:APPVEYOR_REPO_BRANCH -ne "latest_release") {
	$version = "$version-pre$buildNumber"
}

# Patch nuspec version
Patch-Xml ".\SignalR.Client.TypedHubProxy\SignalR.Client.TypedHubProxy.nuspec" $version "/package/metadata/version/text()" @{ }

# Patch nuspec dependencies
Patch-NuspecDependencies ".\SignalR.Client.TypedHubProxy\SignalR.Client.TypedHubProxy.nuspec"

# Patch assemblyinfo version
Patch-AssemblyInfo ".\SignalR.Client.TypedHubProxy\Properties\AssemblyInfo.cs" $version