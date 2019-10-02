<#
.VERSION 0.1.0

.DEPENDENCIES

 - vswhere.exe
 - msbuild.exe
 - nuget.exe

#>

param(
    [String]
    $Configuration = "Release"
)

$ErrorActionPreference = 'Stop'


<# Functions #>

function Get-VsWhereToolPath {
    $vswherePath = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
    if (!(Test-Path -Path $vswherePath)) {
        Write-Host "Can't find Visual Studio Installer, specifically 'vswhere' tool." -ForegroundColor Red
        break
    }
    return $vswherePath
}


function Get-VsInstancePath {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $VsWhereToolPath
    )
    Invoke-Expression "& '$VsWhereToolPath' -prerelease -latest -property installationPath"
}

function Import-DevShellModule {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $VsInstancePath
    )
    Push-Location

    $vsDevShellModulePath = Join-Path $VsInstancePath "Common7\Tools\Microsoft.VisualStudio.DevShell.dll"

    if (!(Test-Path -Path $vsDevShellModulePath)) {
        $vsDevShellModulePath = Join-Path $VsInstancePath "Common7\Tools\vsdevshell\Microsoft.VisualStudio.DevShell.dll"
    }
    if (!(Test-Path -Path $vsDevShellModulePath)) {
        Write-Host "Can't find Visual Studio DevShell module, specifically 'Microsoft.VisualStudio.DevShell.dll' file." -ForegroundColor Red
        break
    }

    Import-Module $vsDevShellModulePath
    $null = Enter-VsDevShell -VsInstallPath $VsInstancePath

    Pop-Location
}

function Install-SolutionPackages() {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $NugetPath,
        [Parameter(Mandatory = $true)]
        [String]
        $SolutionFilePath
    )
    Write-Host "Installing NuGet packages."
    $null = Invoke-Expression "$NugetPath restore $SolutionFilePath"
    Write-Host "Finished installing NuGet packages."
}

function Invoke-SolutionBuild() {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $MsBuildPath,
        [Parameter(Mandatory = $true)]
        [String]
        $SolutionFilePath,
        [Parameter(Mandatory = $true)]
        [String]
        $Configuration
    )
    Write-Host "Building $SolutionFilePath in $Configuration configuration."

    $null = Invoke-Expression -Command "& '$MsBuildPath' '$SolutionFilePath' -t:Rebuild -p:Configuration=$Configuration -p:Platform=x64"

    Write-Host "Finished building."
}


<# The script #>

# define paths
Push-Location ..
$SolutionFile = Join-Path (Get-Location) "project.sln"

# prepare environment
Import-DevShellModule -VsInstancePath (Get-VsInstancePath -VsWhereToolPath (Get-VsWhereToolPath))

# build
Install-SolutionPackages -NugetPath "nuget.exe" -SolutionFilePath $SolutionFile
Invoke-SolutionBuild -MsBuildPath "msbuild.exe" -SolutionFilePath $SolutionFile -Configuration $Configuration


Pop-Location
<# end of the script #>
