
function Get-WaykNowUpdate
{
	$products_url = "https://devolutions.net/products.htm"
	$products_htm = Invoke-RestMethod -Uri $products_url -Method 'GET' -ContentType 'text/plain'
	$matches = $($products_htm | Select-String -AllMatches -Pattern "Wayk.Version=(\S+)").Matches
	$version = $matches.Groups[1].Value
	$download_base = "https://cdn.devolutions.net/download"
	$download_url_x64 = "$download_base/$version/WaykNow-x64-$version.msi"
	$download_url_x86 = "$download_base/$version/WaykNow-x86-$version.msi"
	$download_url_mac = "$download_base/Mac/Wayk/$version/Wayk.Mac.$version.dmg"
	$download_url_deb = "$download_base/Linux/Wayk/$version/wayk-now_${version}_amd64.deb"

	Write-Host $version
	Write-Host $download_url_x64
	Write-Host $download_url_x86
	Write-Host $download_url_mac
	Write-Host $download_url_deb

	$download_url = $null

	if ($IsWindows) {
		if ([System.Environment]::Is64BitOperatingSystem) {
			$download_url = $download_url_x64
		} else {
			$download_url = $download_url_x86
		}
	} elseif ($IsMacOS) {
		$download_url = $download_url_mac
	} elseif ($IsLinux) {
		$download_url = $download_url_deb
	}
 
	$download_file = Split-Path -Path $download_url -Leaf
	Write-Host $download_url
	Write-Host $download_file

	(New-Object System.Net.WebClient).DownloadFile($download_url, $download_file)
	Remove-Item -Path $download_file -Force
}
