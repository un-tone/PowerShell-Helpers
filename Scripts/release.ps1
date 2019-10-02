<#
.VERSION 0.1.0

.DEPENDENCIES

 - publish.ps1
 - 7z

#>

param(
    [String]
    $OutputPath = (Join-Path (Get-Location) "build")
)

$ErrorActionPreference = 'Stop'


<# Functions #>


function Publish-Archive() {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $OutputPath,
        [Parameter(Mandatory = $true)]
        [String]
        $FileName
    )
    Write-Host "Packaging build into archive..."

    $null = Invoke-Expression "7z a $FileName -t7z $OutputPath\*"

    Write-Host "Finished packaging build."
}

function Send-ToDropbox() {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $ArchiveFileName
    )
    Write-Host "Uploading the build package to Dropbox..."

    $arg = '{ "path": "/_PUBLISH/' + $ArchiveFileName + '", "mode": "add", "autorename": true, "mute": false }'
    $authorization = "Bearer " + (get-item env:DROPBOX_RELEASE_TOKEN).Value
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", $authorization)
    $headers.Add("Dropbox-API-Arg", $arg)
    $headers.Add("Content-Type", 'application/octet-stream')
     
    $null = Invoke-RestMethod -Uri https://content.dropboxapi.com/2/files/upload -Method Post -InFile $ArchiveFileName -Headers $headers    

    Write-Host "Finished uploading."
}


<# The script #>

# publish build locally
. ".\publish.ps1" -Configuration "Release"

# define paths
Push-Location ..

# make an archive package
$_archiveFile = "{0:yyyyMMdd-HHmm}.7z" -f (Get-Date)

Publish-Archive -OutputPath $OutputPath -FileName $_archiveFile
Remove-Item $OutputPath -Recurse -Force

# publish to the storage
Send-ToDropbox -ArchiveFileName $_archiveFile
Remove-Item $_archiveFile

# get the info
Write-Output "Artifact: $_archiveFile"


Pop-Location
<# end of the script #>
