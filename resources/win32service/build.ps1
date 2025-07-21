[CmdletBinding()]
param (
    [switch]
    $InstallDsc,

    [switch]
    $Bootstrap,

    [switch]
    $OnlyPsModules,

    [switch]
    $Test,

    [switch]
    $Build,

    [switch]
    $MakeAppx,

    [switch]
    $Publish,

    [string]
    $GitHubToken
)

$errorActionPreference = 'Stop'

$root = Split-Path (Split-Path -Parent $PSScriptRoot) -Parent

# dot-source the common build helpers
. (Join-Path $root 'sharedScripts' 'buildHelpers' 'common.ps1')

Write-Verbose -Message "Root directory: $root"

if ($OnlyPsModules.IsPresent) {
    # Install Pester
    Install-RequiredPsModule -ModuleName 'Pester' -Version '5.7.1' -TrustRepository

    # Install ChangelogManagement
    Install-RequiredPsModule -ModuleName 'ChangelogManagement' -Version '3.1.0' -TrustRepository

    # Install GitHub module
    Install-RequiredPsModule -ModuleName 'GitHub' -Version '0.28.1' -TrustRepository
}

if ($InstallDsc.IsPresent) {
        Install-RequiredPsModule -ModuleName 'PSDSC' -Version '1.2.4' -TrustRepository

        Install-DscExe
    }


if ($Bootstrap.IsPresent) {
    $architecture = [System.Environment]::Is64BitOperatingSystem ? '64' : '32'
    $assetName = "gettext0.25.1-iconv1.17-static-$architecture.zip"

    # Install the gettext-iconv-windows tool for translation messages
    Invoke-DownloadGitHubAsset -Repository 'mlocati/gettext-iconv-windows' `
        -AssetName $assetName `
        -ToolDir (Join-Path $root 'tools') `
        -Extract `
        -AddToPath "bin"

    # Install upx
    $upxAssetName = "upx-5.0.1-win$architecture.zip"
    Invoke-DownloadGitHubAsset -Repository 'upx/upx' `
        -AssetName $upxAssetName `
        -ToolDir (Join-Path $root 'tools') `
        -Extract `
        -AddToPath "upx-5.0.1-win$architecture"

    # Install UV
    Install-UvPackageManager

    # Check if Git is installed
    if ($IsWindows -and -not (Get-Command git -CommandType Application -ErrorAction Ignore)) {
        Write-Verbose -Message "Installing Git"
        winget install --id Git.Git -e --silent
    }
}

if ($Build.IsPresent) {
    $projectToBuild = Join-Path $root 'resources' 'win32service'

    Build-PythonProject -ProjectPath $projectToBuild

    $resourceManifest = Join-Path $projectToBuild 'win32service.dsc.resource.json'
    Copy-Item -Path $resourceManifest -Destination (Join-Path $projectToBuild 'output') -Force -ErrorAction Stop
}

if ($Test.IsPresent) {
    $pathToTest = Join-Path $root 'resources' 'win32service' 'tests'

    $env:Path += [System.IO.Path]::PathSeparator + (Join-Path $root 'resources' 'win32service' 'output')
    Invoke-Pester -Path $pathToTest -Output Detailed -ErrorAction Stop
}

if ($Publish.IsPresent) {
    if (-not $GitHubToken) {
        Write-Error "GitHub token is required for publishing releases."
        return
    }

    Connect-GitHubAccount -Token $GitHubToken -ErrorAction Stop

    $projectRoot = Join-Path $root 'resources' 'win32service'

    $changelogPath = Join-Path $projectRoot 'CHANGELOG.md'

    if (-not (Test-Path -Path $changelogPath)) {
        Write-Error "Changelog file not found at $changelogPath"
        return
    }

    $repoDetails = Get-GitRepositoryInfo

    if ($repoDetails.CurrentBranch -ne 'main') {
        Write-Warning "You must be on the main branch to publish a release."
        return
    }

    $getReleaseData = Get-ChangelogData -Path $changelogPath -ErrorAction Stop
    $latestVersion = $getReleaseData.Released | Select-Object -First 1 -Property Version, RawData

    $toBeReleased = Get-GitHubRelease -Repository $repoDetails.RepositoryName -Owner $repoDetails.Owner -Tag "v$($latestVersion.Version)"

    if (!$toBeReleased) {
        # No existing release found, create a new one
        Write-Verbose -Message "Creating new release for version $($latestVersion.Version)"
        $release = New-GitHubRelease -Repository $repoDetails.RepositoryName `
            -Owner $repoDetails.Owner `
            -Tag "v$($latestVersion.Version)" `
            -Notes $latestVersion.RawData `
            -Latest:$false

        Write-Verbose -Message "Release created with ID: $($release.Id)"

        $releaseAssets = Get-ChildItem -Path (Join-Path $projectRoot 'output') -Include 'win32service.exe', 'win32service.dsc.resource.json' -File -Recurse 
        if ($null -eq $releaseAssets) {
            Write-Error "No assets found in output directory. Please build the project first."
            return
        }

        $archive = Compress-Archive -Path $releaseAssets.FullName `
            -DestinationPath "$projectRoot\output\win32service-v$($latestVersion.Version).zip" `
            -Force -PassThru

        $release | Add-GitHubReleaseAsset -Path $archive `
            -Name "win32service-v$($latestVersion.Version).zip" `
            -ContentType "application/zip" `
            -ErrorAction Ignore

        Remove-Item -Path $archive.FullName -Force -ErrorAction Ignore
        Write-Verbose -Message "Assets uploaded successfully."
    }
    else {
        Write-Warning "Release for version $($latestVersion.Version) already exists. Make sure to update the version in the changelog before publishing."
    }
}

# if ($MakeAppx.IsPresent) {
#     $appxPath = Find-MakeAppx
#     if ($null -eq $appxPath) {
#         Write-Verbose -Message "Installing Windows SDK"
#         Install-WindowsSdk

#         $appxPath = Find-MakeAppx   
#     }

#     Write-Verbose -Message "Using $appxPath"
# }