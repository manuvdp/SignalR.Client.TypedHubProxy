$ErrorActionPreference = "Stop"

function Patch-Xml($file, $value, $xpath, $namespaces)
{
	Write-Host "Patching $file"

	$doc = [xml](Get-Content $file -Raw)

	$ns = New-Object System.Xml.XmlNamespaceManager -ArgumentList (New-Object System.Xml.NameTable)
	$namespaces.GetEnumerator() | % { $ns.AddNamespace($_.Key, $_.Value) }
	$node = $doc.SelectSingleNode($xpath, $ns)
	$node.Value = $value

	Set-Content $file $doc.OuterXml
}

function Patch-AssemblyInfo($file, $version)
{
	Write-Host "Patching $file"

	$smallVersion = [Regex]::Match($version, "^\d+\.\d+").Value

	$code = Get-Content $file -Raw
	$code = [Regex]::Replace($code, 'AssemblyVersion\("[^"]*"\)', "AssemblyVersion(`"$smallVersion.0`")")
	$code = [Regex]::Replace($code, 'AssemblyFileVersion\("[^"]*"\)', "AssemblyFileVersion(`"$smallVersion.0`")")
	$code = [Regex]::Replace($code, 'AssemblyInformationalVersion\("[^"]*"\)', "AssemblyInformationalVersion(`"$version`")")

	Set-Content $file $code
}

function Patch-NuspecDependencies($nuspecFile)
{
	$filename = [System.IO.Path]::GetFileName($nuspecFile)
	
	Write-Host "Patching $filename ..."
	
	$packagesConfig = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($nuspecFile), 'packages.config')
	
	[xml]$packagesDoc = (Get-Content $packagesConfig -Raw)
	[xml]$nuspecDoc = (Get-Content $nuspecFile -Raw)
	
	$packageNodes = $packagesDoc.SelectNodes('/packages/package')
	$nuspecDepGroupNode = $nuspecDoc.SelectSingleNode('/package/metadata/dependencies/group[@targetFramework=".NETFramework4.5"]')
	
	# Remove all dependencies
	$deps = $nuspecDepGroupNode.SelectNodes('*')
	foreach($dep in $deps)
	{
		$dep.ParentNode.RemoveChild($dep) | Out-Null
	}

	# Add dependencies
	foreach($packageNode in $packageNodes) 
	{
		$newDependency = $nuspecDoc.CreateElement('dependency')
		$idAttr = $nuspecDoc.CreateAttribute('id')
		$idAttr.Value = $packageNode.id
		$versionAttr = $nuspecDoc.CreateAttribute('version')
		$versionAttr.Value = $packageNode.version
		
		$newDependency.Attributes.Append($idAttr) | Out-Null
		$newDependency.Attributes.Append($versionAttr) | Out-Null
		
		Write-Host "Added dependency $($packageNode.id) v$($packageNode.version)"
		$nuspecDepGroupNode.AppendChild($newDependency) | Out-Null
	}
	
	Set-Content $nuspecFile $nuspecDoc.OuterXml
}

function Get-VersionFromTag()
{
	$versionTag = git describe --tags --abbrev=0 #--exact-match
	if(-not ($versionTag -match "^(?:v)?\d+\.\d+\.\d+$"))
	{
		throw "Missing or invalid version tag"
	}

	$version = $versionTag.TrimStart("v")
	Write-Host "Current version is $version"
	echo $version
}