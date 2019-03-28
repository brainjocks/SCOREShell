# Script to deploy Allegis Enterprise Layer update packages into local sandbox via NuGet
# Will only run once for the solution and every time a solutoin is opened in VS and PackageManager Console is opened

Param($installPath, $toolsPath, $package, $project)

$packages = [System.IO.Path]::GetFullPath((Join-Path $toolsPath "packages\"))
$packageinstaller = [System.IO.Path]::GetFullPath((Join-Path $toolsPath "installer\"))
$root = [System.IO.Path]::GetFullPath((Join-Path $installPath "..\.."))

# ***************************************************
# Powershell v 3.0 is required
# ***************************************************
function CheckVersion() 
{
    $major = $PSVersionTable.PSVersion.Major;
    $minor = $PSVersionTable.PSVersion.MinorRevision;

    if ( $major -lt 3) {
        Write-Host "Powershell version on this machine is ${major}.${minor}.  To run the scaffold script, you must update to Powershell version 3.0 or later." -BackgroundColor Red -ForegroundColor Black

    }
}

# ***************************************************
# Read the PropertyGroup into an object and calculate full path to the installed directory
# ***************************************************
function Get-SitecoreProperties() {

   param(
        [Parameter(Mandatory=$true)] 
        [System.Xml.XmlElement]$propertyGroup,
        [Parameter(Mandatory=$true)] 
        [System.IO.FileSystemInfo]$projectFile 
    )

    $deploymentPath = $null;
    if ([System.IO.Path]::IsPathRooted($propertyGroup.SitecoreDeployFolder))
    {
        $deploymentPath = $propertyGroup.SitecoreDeployFolder
    } else {
        $deploymentPath = [System.IO.Path]::GetFullPath((Join-Path $projectFile.Directory.FullName $propertyGroup.SitecoreDeployFolder))
    }
  
    return new-object PSObject -prop @{SitecoreWebUrl = $propertyGroup.SitecoreWebUrl;SitecoreDeployFolder = $deploymentPath;ProjectFile = $projectFile.FullName}
}

CheckVersion

# ***************************************************
#1. Detect Sitecore Deployment properties
# ***************************************************
Write-Host "Finding all TDS project files nested under $root..."

$projects = Get-ChildItem "$root\*.scproj" -Recurse -Exclude "*Rename.Me*"

$props = @()

Write-Host "Reading 'Sandbox' build profile of TDS projects for URL and deployment location..."

foreach ( $project in $projects ) {
   
    ([xml](Get-Content $project )).Project.PropertyGroup | 
        Where-Object { $_.Condition -like "*'Sandbox'*" -and $_.SitecoreDeployFolder -and $_.SitecoreWebUrl } | 
        Foreach-Object { $props = $props + ( Get-SitecoreProperties $_ $project ) }
}

if ($props.Count -eq 0) {
    Write-Error "Unable to find PropertyGroup within a TDS project scproj file that connects to Sitecore in build configuration 'Sandbox'" -Category InvalidData
    Exit 
}

$properties = $props[0]

if ( $props | Where-Object { $_.SitecoreWebUrl -ne $properties.SitecoreWebUrl -or $_.SitecoreDeployFolder -ne $_.SitecoreDeployFolder } ) {

    Write-Error "Cannot continue - 2 or more TDS projects have conflicting Sitecore deployment settings for Sandbox build configuration" -Category InvalidData
    $props | Format-Table
    Exit 
}

Write-Host "All TDS projects agree for 'Sandbox' Sitecore deployment configuration. URL $($properties.SitecoreWebUrl) Folder $($properties.SitecoreDeployFolder)"

$path = $properties.SitecoreDeployFolder

$url = $properties.SitecoreWebUrl


# ***************************************************
#2. Test if Sitecore installed in the sandbox
# ***************************************************
Write-Host "Detecting Sitecore in the local sandbox..."

If (!(Test-Path("$path\bin\Sitecore.Kernel.dll"))) 
{
    Write-Error "No Sitecore instance installed locally at $path" -Category NotInstalled 
    Exit
}


# ***************************************************
#3. Verify if installed version is older than the version being installed
# ***************************************************
Write-Host "Verifying if SCORE.Shell has already been installed on $url..."
Try
{
    $result = Invoke-WebRequest "$url/scoreshell/about/version?ts=$((Get-Date).ToFileTime())"
    
    $installed = [System.Version]::Parse((ConvertFrom-Json $result.Content).'SCORE.Shell'.Build)
    $tobeinstalled = [System.Version]::Parse("$($package.Version)")
    
    "Detected SCORE Shell version $installed. Attempting to install version $tobeinstalled"

    If ($installed.CompareTo($tobeinstalled) -ge 0) 
    {
        Write-Warning "$installed is same or newer than $tobeinstalled. Skipping deployment of $tobeinstalled" 
        Exit
    }
}
Catch
{
    # Write-Warning "Diagnostic: $($_.Exception.GetType().FullName) - $($_.Exception.Message)" 
    Write-Warning "No previously installed SCORE Shell version detected"
}


# ***************************************************
#4. Install SCORE Package Installer into the local Sitecore
# ***************************************************
Write-Host "Installing SCORE Package Installer to $url/_SCORE/ via $path (if not present)..."

if (!(Test-Path "$path\_SCORE" -PathType Container))
{
    New-Item -ItemType Directory -Path "$path\_SCORE" | Out-Null
}

if (!(Test-Path "$path\_SCORE\UpdatePackageInstaller.asmx") -or !(Test-Path "$path\_SCORE\Score.Automation.WebServices.dll"))
{
    Copy-Item -Path "$packageinstaller\UpdatePackageInstaller.asmx" -Destination "$path\_SCORE\" -Force
    Copy-Item -Path "$packageinstaller\Score.Automation.WebServices.dll" -Destination "$path\bin" -Force

    # Give Sitecore a few seconds to recycle 

    Start-Sleep -s 5    
}


# ***************************************************
#5. Deploy update packages
# ***************************************************
$installer = New-WebServiceProxy -Uri "$url/_SCORE/UpdatePackageInstaller.asmx?WSDL&ts=$((Get-Date).ToFileTime())"

# Default timeout is 100 seconds. We set it to 300 (SCORE-211)
$installer.Timeout = 5*60*1000

Write-Host "Deploying SCORE.Shell $($package.Version)..."

Try
{
    $installer.InstallPackage("$packages\SCORE.Shell.Master.update")
}
Catch
{
    Write-Warning "Diagnostic: $($_.Exception.GetType().FullName) - $($_.Exception.Message)" 
    Write-Error "Failed to deploy SCORE.Shell.Master.update. Please deploy manually from $packages" -Category NotInstalled
    Exit
}

# Give Sitecore a few seconds to recycle 

Start-Sleep -s 5

# ***************************************************
#6. Commit configuration changes
# ***************************************************
Write-Host "Committing configuration changes..."
$command = @{id = "SCORE.Shell.Master"}
Try
{
    $result = Invoke-WebRequest "$url/score/configuration/commit" -Method POST -Body $command
    Write-Host $result.Content
}
Catch 
{
    Write-Warning "Diagnostic: $($_.Exception.GetType().FullName) - $($_.Exception.Message)" 
    Write-Error "Failed to commit configuration files changes. Please do so manually" -Category NotInstalled
    Exit
}

Write-Host "All done."
Exit
