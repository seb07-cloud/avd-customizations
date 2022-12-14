# Set ISO URL`s

$isos = @(
    "https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_CLIENTLANGPACKDVD_OEM_MULTI.iso",
    "https://software-download.microsoft.com/download/pr/19041.1.191206-1406.vb_release_amd64fre_FOD-PACKAGES_OEM_PT1_amd64fre_MULTI.iso",
    "https://software-download.microsoft.com/download/sg/19041.928.210407-2138.vb_release_svc_prod1_amd64fre_InboxApps.iso"
)

# Set Download Path
[string]$down_path = "C:\temp\"
[string]$language = "de-de"

if (!Test-Path $down_path) {
    New-Item -Path $down_path -ItemType Directory -Force
}

function Get-ISO {
    [CmdletBinding()]
    param (
        [string]$isourl,
        [string]$down_path
    )
    
    begin {
        $down_path = "$down_path$(($isourl -split "/")[(($isourl -split "/").length - 1)])"
    }
    
    process {
        $file = (New-Object System.Net.WebClient).DownloadFile($isourl, $down_path)
    }
    
    end {
        if (!$Error) {
            Write-Host "$file downloaded to $down_path" -ForegroundColor Green
        }
    }
}

#Download 
foreach ($i in $isos) {
    try {
        Get-ISO -isourl $i -down_path $down_path
    }
    catch {
        { 1:<#Do this if a terminating exception happens#> }
    }
    
}

##Mount ISO´s##
$drives = foreach ($item in Get-ChildItem -Path $down_path -Filter "*.iso") {
    Mount-DiskImage -ImagePath $item.FullName
}

########################################################
## Add Languages to running Windows Image for Capture ##
########################################################

$vol_LPLIP = (($drives | Get-Volume) | Where-Object { $_.FileSystemLabel -match "LPLIP" }).DriveLetter
$vol_FOD = (($drives | Get-Volume) | Where-Object { $_.FileSystemLabel -match "FOD" }).DriveLetter
$vol_CDL = (($drives | Get-Volume) | Where-Object { $_.FileSystemLabel -match "CDL" }).DriveLetter

##Install Lang Features // Set Language##
foreach ($vol in ($drives | Get-Volume)) {
    if ($vol.FileSystemLabel -match "LPLIP") {

        [string]$LIPContent = $vol_LPLIP + ":" + "\x64\langpacks\" + $language
        [string]$FODContent = $vol_FOD + ":"

        ##LIP##
        Add-AppProvisionedPackage -Online -PackagePath $LIPContent\LanguageExperiencePack.$language.Neutral.appx -LicensePath $LIPContent\License.xml
        Add-WindowsPackage -Online -PackagePath $LIPContent\Microsoft-Windows-Client-Language-Pack_x64_de-de.cab

        ##FOD##
        Add-WindowsPackage -Online -PackagePath $FODContent\Microsoft-Windows-LanguageFeatures-Basic-de-de-Package~31bf3856ad364e35~amd64~~.cab
        Add-WindowsPackage -Online -PackagePath $FODContent\Microsoft-Windows-LanguageFeatures-Handwriting-de-de-Package~31bf3856ad364e35~amd64~~.cab
        Add-WindowsPackage -Online -PackagePath $FODContent\Microsoft-Windows-LanguageFeatures-OCR-de-de-Package~31bf3856ad364e35~amd64~~.cab
        Add-WindowsPackage -Online -PackagePath $FODContent\Microsoft-Windows-LanguageFeatures-Speech-de-de-Package~31bf3856ad364e35~amd64~~.cab
        Add-WindowsPackage -Online -PackagePath $FODContent\Microsoft-Windows-LanguageFeatures-TextToSpeech-de-de-Package~31bf3856ad364e35~amd64~~.cab
        Add-WindowsPackage -Online -PackagePath $FODContent\Microsoft-Windows-NetFx3-OnDemand-Package~31bf3856ad364e35~amd64~de-de~.cab
        Add-WindowsPackage -Online -PackagePath $FODContent\Microsoft-Windows-InternetExplorer-Optional-Package~31bf3856ad364e35~amd64~de-de~.cab
        Add-WindowsPackage -Online -PackagePath $FODContent\Microsoft-Windows-MSPaint-FoD-Package~31bf3856ad364e35~amd64~de-de~.cab
        Add-WindowsPackage -Online -PackagePath $FODContent\Microsoft-Windows-Notepad-FoD-Package~31bf3856ad364e35~amd64~de-de~.cab
        Add-WindowsPackage -Online -PackagePath $FODContent\Microsoft-Windows-PowerShell-ISE-FOD-Package~31bf3856ad364e35~amd64~de-de~.cab
        Add-WindowsPackage -Online -PackagePath $FODContent\Microsoft-Windows-Printing-WFS-FoD-Package~31bf3856ad364e35~amd64~de-de~.cab
        Add-WindowsPackage -Online -PackagePath $FODContent\Microsoft-Windows-StepsRecorder-Package~31bf3856ad364e35~amd64~de-de~.cab
        Add-WindowsPackage -Online -PackagePath $LIPContent\Microsoft-Windows-WordPad-FoD-Package~31bf3856ad364e35~amd64~de-de~.cab
        $LanguageList = Get-WinUserLanguageList
        $LanguageList.Add($language)
        Set-WinUserLanguageList $LanguageList -Force
    }
}

##Disable Language Pack Cleanup##
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -TaskName "Pre-staged app cleanup"

#########################################
## Update Inbox Apps for Multi Language##
#########################################

##Set Inbox App Package Content Stores##
[string]$AppsContent = $vol_CDL + ":" + "\amd64fre"

##Update installed Inbox Store Apps##
foreach ($App in (Get-AppxProvisionedPackage -Online)) {
    $AppPath = $AppsContent + $App.DisplayName + '_' + $App.PublisherId
    Write-Host "Handling $AppPath"
    $licFile = Get-Item $AppPath*.xml
    if ($licFile.Count) {
        $lic = $true
        $licFilePath = $licFile.FullName
    }
    else {
        $lic = $false
    }
    $appxFile = Get-Item $AppPath*.appx*
    if ($appxFile.Count) {
        $appxFilePath = $appxFile.FullName
        if ($lic) {
            Add-AppxProvisionedPackage -Online -PackagePath $appxFilePath -LicensePath $licFilePath 
        }
        else {
            Add-AppxProvisionedPackage -Online -PackagePath $appxFilePath -SkipLicense
        }
    }
}