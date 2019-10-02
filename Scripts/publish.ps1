<#
.VERSION 0.1.0

.DEPENDENCIES

 - build.ps1
 - msbuild.exe

#>

param(
    [String]
    $Configuration = "Release",
    [String]
    $OutputPath = (Join-Path (Get-Location) "build")
)

$ErrorActionPreference = 'Stop'


<# Functions #>

function Publish-WebApp() {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $MsBuildPath,
        [Parameter(Mandatory = $true)]
        [String]
        $WebAppProjectFilePath,
        [Parameter(Mandatory = $true)]
        [String]
        $WebAppPublishFilePath
    )
    Write-Host "Publishing $WebAppProjectFilePath web application project using $WebAppPublishFilePath configuration."

    $null = Invoke-Expression -Command "& '$MsBuildPath' '$WebAppProjectFilePath' /p:DeployOnBuild=true /p:PublishProfile='$WebAppPublishFilePath'"

    Write-Host "Finished publishing."
}

function Copy-ProjectBinaries() {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $BinariesPath,
        [Parameter(Mandatory = $true)]
        [String]
        $OutputPath
    )
    Copy-Item "$BinariesPath\*" -Filter "*.exe" -Destination $OutputPath
    Copy-Item "$BinariesPath\*" -Filter "*.dll" -Destination $OutputPath
    Copy-Item "$BinariesPath\*" -Filter "*.pdb" -Destination $OutputPath
}


<# The script #>

# build
. ".\build.ps1" -Configuration $Configuration

# define paths
Push-Location ..

$SourcePath = Join-Path (Get-Location) "src"
$WebAppProjectFilePath = Join-Path $SourcePath "WebApp\WebApp.csproj"
$WebAppPublishProfilesPath = Join-Path $SourcePath "Configs\PublishProfiles"
$DeploySqlPath = Join-Path (Get-Location) "deploy\sql"

$WebAppOutputDir = Join-Path $OutputPath "WebApp"
$ExportServiceOutputDir = Join-Path $OutputPath "ExportService"
$NotificationServiceOutputDir = Join-Path $OutputPath "NotificationService"
$SqlOutputDir = Join-Path $OutputPath "SQL"


# collect binaries
if (Test-Path $OutputPath) {
    Remove-Item $OutputPath -Recurse -Force
}
$null = New-Item $OutputPath -ItemType Directory
$null = New-Item $WebAppOutputDir -ItemType Directory
$null = New-Item $ExportServiceOutputDir -ItemType Directory
$null = New-Item $NotificationServiceOutputDir -ItemType Directory

Copy-ProjectBinaries -BinariesPath (Join-Path $SourcePath "ExportService\bin\x64\$Configuration") -OutputPath $ExportServiceOutputDir
Copy-ProjectBinaries -BinariesPath (Join-Path $SourcePath "NotificationService\bin\x64\$Configuration") -OutputPath $NotificationServiceOutputDir

# publish web app
Publish-WebApp -MsBuildPath "msbuild.exe" -WebAppProjectFilePath $WebAppProjectFilePath -WebAppPublishFilePath (Join-Path $WebAppPublishProfilesPath ($Configuration + "Profile.pubxml"))

Remove-Item "$WebAppOutputDir\*" -Filter "*.config"
#Get-Childitem $WebAppOutputDir -File -Filter "*.config" | Foreach-Object {Remove-Item $_.FullName}

# copy additional SQL files
if (Test-Path $DeploySqlPath) {
    $null = New-Item $SqlOutputDir -ItemType Directory
    Copy-Item "$DeploySqlPath\*" -Filter "*.sql" -Destination $SqlOutputDir
}

Pop-Location
<# end of the script #>
