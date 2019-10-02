<#
.VERSION 0.1.0

.DEPENDENCIES

 - publish.ps1

#>

#Requires -RunAsAdministrator

param(
    [String]
    $OutputPath = (Join-Path (Get-Location) "build")
)

$ErrorActionPreference = 'Stop'


<# Functions #>


function Get-ServiceInfo() {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $ServiceName
    )
    
    $info = (Get-WmiObject win32_service | Where-Object { $_.Name -eq $ServiceName } | Select-Object Name, State, PathName)[0]
    $info.PathName = $info.PathName.Substring(1, $info.PathName.Length - 2)
    return $info
}

function Stop-SpecificService() {
    param (
        [Parameter(Mandatory = $true)]
        [Object]
        $ServiceInfo
    )

    if ($ServiceInfo.State -eq "Running") {
        Stop-Service -Name $ServiceInfo.Name
    }
}

function Clear-ServiceDirectory() {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Path
    )

    Remove-Item "$Path\*" -Filter "*.exe" -Force
    Remove-Item "$Path\*" -Filter "*.dll" -Force
    Remove-Item "$Path\*" -Filter "*.pdb" -Force
}

function Clear-SiteDirectory() {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Path
    )

    Remove-Item "$Path\**" -Exclude "Web.config" -Force -Recurse
    Remove-Item "$Path\Views" -Force -Recurse
}

function Copy-Artifacts() {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $SourcePath,
        [Parameter(Mandatory = $true)]
        [String]
        $TargetPath
    )
    Copy-Item "$SourcePath\*" -Destination $TargetPath -Recurse
}

function Start-SpecificService() {
    param (
        [Parameter(Mandatory = $true)]
        [Object]
        $ServiceInfo
    )

    if ($ServiceInfo.State -ne "Running") {
        Start-Service -Name $ServiceInfo.Name
    }
}

function Update-SpecificService() {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $ServiceName,
        [Parameter(Mandatory = $false)]
        [decimal]
        $StoppingWaitSeconds = 2
    )

    Write-Host "Updating service $ServiceName ..."

    $serviceOutputDir = Join-Path $OutputPath $ServiceName
    $serviceInfo = Get-ServiceInfo -ServiceName $ServiceName
    $serviceDir = Split-Path $serviceInfo.PathName

    Stop-SpecificService -ServiceInfo $serviceInfo

    # smells, may be another approach? On removing service executable file it can throw PermissionDenied
    Start-Sleep -Seconds $StoppingWaitSeconds

    Clear-ServiceDirectory -Path $serviceDir
    Copy-Artifacts -SourcePath $serviceOutputDir -TargetPath $serviceDir

    Write-Host "Finished the updating."
    Write-Host "Starting the updated service $ServiceName ..."
    
    Start-SpecificService -ServiceInfo (Get-ServiceInfo -ServiceName $ServiceName)
    
    Write-Host "$ServiceName service is running."
    Write-Host
}

function Update-Site() {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $SiteName
    )

    $siteOutputDir = Join-Path $OutputPath "WebApp"

    Write-Host "Updating site $SiteName ..."

    $sitePath = (Get-IISSite -Name $SiteName).Applications.VirtualDirectories.PhysicalPath
    Clear-SiteDirectory -Path $sitePath
    Copy-Artifacts -SourcePath $siteOutputDir -TargetPath $sitePath

    Write-Host "Finished the updating."
}


<# The script #>

# publish build locally
. ".\publish.ps1" -Configuration "Debug"

# define paths
Push-Location ..

Update-SpecificService -ServiceName "ExportService"
Update-SpecificService -ServiceName "NotificationService"

Write-Host "Stopping 'webAppPool' IIS application pool ..."
$appPool = Get-IISAppPool -Name webAppPool
$appPool.Stop()

Write-Host

Update-Site -SiteName webapp_instance1
Update-Site -SiteName webapp_instance2

$appPool.Start()

Remove-Item $OutputPath -Recurse -Force

Write-Host "Started 'webAppPool' IIS application pool."
Write-Host
Write-Host "Local deployment is finished successfully."

Pop-Location
<# end of the script #>
