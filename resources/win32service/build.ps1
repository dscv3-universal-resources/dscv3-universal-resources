[CmdletBinding()]
param (
    [switch]
    $InstallDsc,

    [switch]
    $Test,

    [switch]
    $SkipBuild,

    [switch]
    $MakeAppx,

    [switch]
    $Publish
)

function Find-MakeAppx() {
    $makeappx = Get-Command makeappx -CommandType Application -ErrorAction Ignore
    if ($null -eq $makeappx) {
        # try to find
        if (!$UseX64MakeAppx -and $architecture -eq 'aarch64-pc-windows-msvc') {
            $arch = 'arm64'
        }
        else {
            $arch = 'x64'
        }

        $makeappx = Get-ChildItem -Recurse -Path (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin\*\' $arch) -Filter makeappx.exe -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
        if ($null -eq $makeappx) {
            return $Null
        }
    }

    $makeappx
}

function Install-WindowsSdk {
    Write-Verbose -Message "Installing Windows SDK"

    Write-Verbose "Downloading..."
    $exePath = "$env:temp\wdksetup.exe"
    (New-Object Net.WebClient).DownloadFile('https://go.microsoft.com/fwlink/?linkid=2317808', $exePath)

    Write-Verbose "Installing..."
    cmd /c start /wait $exePath /features + /quiet

    Remove-Item $exePath
    Write-Verbose "Installed"
}

function Get-GetTextAsset {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Repository = "mlocati/gettext-iconv-windows",

        [Parameter()]
        [string]
        $ToolDir = 'tools'
    )

    $releaseApiUrl = "https://api.github.com/repos/$Repository/releases/latest"

    if (-not (Test-Path -Path $ToolDir)) {
        New-Item -Path $ToolDir -ItemType Directory -Force | Out-Null
    }

    try {
        Write-Verbose "Fetching release data from $releaseApiUrl"
        $releases = Invoke-RestMethod -Uri $releaseApiUrl

        if ($releases.assets) {
            # Filter assets based on filename pattern
            $architecture = [System.Environment]::Is64BitOperatingSystem ? '64' : '86'
            $targetAsset = $releases.assets | Where-Object { $_.name -like "*gettext*-iconv*-static-$architecture.zip" }

            if ($targetAsset) {
                Write-Verbose "Found matching asset: $($targetAsset.name)"
                $filePath = Join-Path $ToolDir $targetAsset.name
                Invoke-RestMethod -Uri $targetAsset.browser_download_url -OutFile $filePath -ErrorAction Stop

                Expand-Archive -Path $filePath -DestinationPath $ToolDir -Force -ErrorAction Stop
                Write-Verbose "Extracted to $ToolDir"
            }
        }
    }
    catch {
        Write-Error "Failed to fetch release info: $_"
    }
}

function Get-GitRepositoryInfo {
    [CmdletBinding()]
    param()
    
    $root = Split-Path -Path $PSScriptRoot -Parent
    $gitFile = Join-Path $root '.git'

    if (-not (Test-Path -Path $gitFile)) {
        Write-Error "No .git directory found in the current path"
        return
    }

    # Get repository information
    $repoInfo = [PSCustomObject]@{
        RemoteUrl = (git config --get remote.origin.url)
        CurrentBranch = (git rev-parse --abbrev-ref HEAD)
        LastCommitHash = (git rev-parse HEAD)
        LastCommitShortHash = (git rev-parse --short HEAD)
        LastCommitDate = (git log -1 --format=%cd)
        LastCommitMessage = (git log -1 --pretty=%B)
        RepositoryRoot = (git rev-parse --show-toplevel)
        Owner = $null
        RepositoryName = $null
    }
    
    # Extract owner and repository name from remote URL
    if ($repoInfo.RemoteUrl) {
        if ($repoInfo.RemoteUrl -match "github\.com[:/](?<owner>[^/]+)/(?<repo>[^/\.]+)(\.git)?") {
            $repoInfo.Owner = $matches.owner
            $repoInfo.RepositoryName = $matches.repo -replace '\.git$', ''
        }
    }
    
    return $repoInfo
}

if ($InstallDsc) {
    if (-not (Get-Command dsc.exe -Type Application -ErrorAction Ignore)) {
        Write-Verbose -Message "Installing dsc using PowerShell Gallery"
        Install-PSResource -Name PSDSC -Repository PSGallery -TrustRepository

        Install-DscExe 
    }
}

if (-not (Get-Command uv.exe -Type Application -ErrorAction Ignore)) {
    Write-Verbose -Message "Installing uv"
    Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression

    $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
}

if (-not (Get-Command upx.exe -Type Application -ErrorAction Ignore)) {
    Write-Verbose -Message "Installing upx"

    $architecture = [System.Environment]::Is64BitOperatingSystem ? 'win64' : 'win32'
    $upxVersion = '5.0.0'
    $fileName = "upx-$upxVersion-$architecture.zip"
    $upxUrl = "https://github.com/upx/upx/releases/download/v$upxVersion/$fileName"

    Invoke-WebRequest -Uri $upxUrl -OutFile $fileName -UseBasicParsing -ErrorAction Stop

    $destinationPath = Join-Path $PSScriptRoot 'upx'
    if (-not (Test-Path -Path $destinationPath)) {
        New-Item -Path $destinationPath -ItemType Directory -Force -ErrorAction Stop
    }
    Expand-Archive -Path $fileName -DestinationPath $destinationPath -Force -ErrorAction Stop

    $env:Path += [System.IO.Path]::PathSeparator + $destinationPath

    Remove-Item -Path $fileName -Force -ErrorAction Ignore
}

if (-not $SkipBuild) {
    Write-Verbose -Message "Building the project"
    
    $projectPath = Join-Path $PSScriptRoot 'src'
    $outputDir = Join-Path $PSScriptRoot 'output'

    $upxPath = Join-Path $PSScriptRoot 'upx'

    $env:Path += [System.IO.Path]::PathSeparator + $outputDir

    try {
        Push-Location -Path $projectPath -ErrorAction Stop
        
        # Create virtual environment
        & uv venv 

        # Active it
        & .\.venv\Scripts\activate.ps1

        # Sync all the dependencies
        & uv sync @arguments

        # Translate all messages
        Get-GetTextAsset 

        # Add path variable
        $toolsPath = Join-Path $PSScriptRoot 'src' 'tools' 'bin'
        $env:Path += [System.IO.Path]::PathSeparator + $toolsPath

        $poFiles = Get-ChildItem -Path $PSScriptRoot -Filter '*.po' -Recurse
        foreach ($poFile in $poFiles) {
            $moFile = [System.IO.Path]::ChangeExtension($poFile.FullName, '.mo')
            & msgfmt.exe -o $moFile $poFile.FullName --verbose
        }

        # Add locales directory to the path
        $localesPath = Join-Path $PSScriptRoot 'locales'
        $localesSpec = "$localesPath;locales"

        Write-Verbose -Message "Using locales spec: $localesSpec"

        # Build the project
        & pyinstaller.exe main.py -F --clean --distpath $outputDir --name win32service --icon NONE --upx-dir $upxPath --add-data $localesSpec

        # Move the resource manifest
        $resourceManifest = Join-Path $PSScriptRoot 'win32service.dsc.resource.json'
        Copy-Item -Path $resourceManifest -Destination $outputDir -Force -ErrorAction Stop

    }
    finally {
        deactivate
        Pop-Location -ErrorAction Ignore
    }
}

if ($Test) {
    if (-not (Get-Module -ListAvailable -Name Pester)) {
        Install-PSResource Pester -Repository PSGallery -TrustRepository -ErrorAction Ignore
    }

    Invoke-Pester -ErrorAction Stop -Output Detailed
}

if ($Publish.IsPresent) {
    if (-not (Get-Module ChangelogManagement -ListAvailable -ErrorAction Ignore)) {
        Install-PSResource -Name ChangelogManagement -Repository PSGallery -TrustRepository -Scope CurrentUser
    }

    if (-not (Get-Module GitHub -ListAvailable -ErrorAction Ignore)) {
        Install-PSResource -Name GitHub -Repository PSGallery -TrustRepository -Scope CurrentUser
    }

    $changelogPath = Join-Path $PSScriptRoot 'CHANGELOG.md'
    if (-not (Test-Path -Path $changelogPath)) {
        Write-Error "Changelog file not found at $changelogPath"
        return
    }

    if ($IsWindows -and -not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Verbose -Message "Installing Git"
        winget install --id Git.Git -e --silent
    }

    $repositoryDetails = Get-GitRepositoryInfo

    if ($repositoryDetails.CurrentBranch -ne 'main') {
        Write-Error "You must be on the main branch to publish a release."
        return
    }

    $getReleaseData = Get-ChangelogData -Path $changelogPath -ErrorAction Stop

    $latestVersion = $getReleaseData.Released | Select-Object -First 1 -Property Version, RawData

    $toBeReleased = Get-GitHubRelease -Repository $repositoryDetails.RepositoryName -Owner $repositoryDetails.Owner -Tag "v$($latestVersion.Version)"

    if (!$toBeReleased) {
        # No existing release found, create a new one
        Write-Verbose -Message "Creating new release for version $($latestVersion.Version)"
        $release = New-GitHubRelease -Repository $repositoryDetails.RepositoryName `
            -Owner $repositoryDetails.Owner `
            -Tag "v$($latestVersion.Version)" `
            -Notes $latestVersion.RawData

        Write-Verbose -Message "Release created with ID: $($release.Id)"

        $releaseAssets = Get-ChildItem -Path "$PSScriptRoot\output\*"
        if ($null -eq $releaseAssets) {
            Write-Error "No assets found in output directory."
            return
        }

        # Before compression, copy the manifest
        $manifestPath = Join-Path $PSScriptRoot 'win32service.dsc.resource.json'
        $destinationPath = Join-Path $PSScriptRoot 'output'

        Copy-Item -Path $manifestPath -Destination $destinationPath -Force -ErrorAction Stop

        $archive = Compress-Archive -Path "$($releaseAssets[0].DirectoryName)\*" -DestinationPath "$PSScriptRoot\output\win32service-v$($latestVersion.Version).zip" -Force -PassThru
 
        $release | Add-GitHubReleaseAsset -Path $archive `
            -Name "win32service-v$($latestVersion.Version).zip" `
            -ContentType "application/zip" `
            -ErrorAction Ignore

        Remove-Item -Path $archive.FullName -Force -ErrorAction Ignore
        Write-Verbose -Message "Assets uploaded successfully."
    } else {
        Write-Warning "Release for version $($latestVersion.Version) already exists. Make sure to update the version in the changelog before publishing."
    }
}

if ($MakeAppx.IsPresent) {
    $appxPath = Find-MakeAppx
    if ($null -eq $appxPath) {
        Write-Verbose -Message "Installing Windows SDK"
        Install-WindowsSdk

        $appxPath = Find-MakeAppx   
    }

    Write-Verbose -Message "Using $appxPath"
}