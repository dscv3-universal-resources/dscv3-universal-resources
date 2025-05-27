function Find-MakeAppx() {
    $makeappx = Get-Command makeappx -CommandType Application -ErrorAction Ignore

    $arch = 'x64'
    # TODO: Optitionally support ARM64
    $makeappx = Get-ChildItem -Recurse -Path (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin\*\' $arch) -Filter makeappx.exe -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
    if ($null -eq $makeappx) {
        return $Null
    }

    $makeappx
}

function Install-WindowsSdk() {
    Write-Verbose -Message "Installing Windows SDK"

    Write-Verbose "Downloading..."
    $exePath = "$env:temp\wdksetup.exe"
    (New-Object Net.WebClient).DownloadFile('https://go.microsoft.com/fwlink/?linkid=2317808', $exePath)

    Write-Verbose "Installing..."
    cmd /c start /wait $exePath /features + /quiet

    Remove-Item $exePath
    Write-Verbose "Installed"
}

function New-PathIfNotExists {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
        Write-Verbose "Created directory: $Path"
    }
}

function Invoke-DownloadGitHubAsset {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Repository,

        [Parameter(Mandatory = $true)]
        [string]
        $AssetName,

        [Parameter(Mandatory = $true)]
        [string]
        $ToolDir,

        [Parameter(Mandatory = $true)]
        [string]
        $AddToPath,

        [Parameter()]
        [switch]
        $Extract
    )

    begin {
        Write-Verbose -Message ("Starting function: {0}" -f $MyInvocation.MyCommand.Name)
        $releaseApiUrl = "https://api.github.com/repos/$Repository/releases/latest"
    }

    process {
        # Create tool directory
        New-PathIfNotExists -Path $ToolDir

        $releases = Invoke-RestMethod -Uri $releaseApiUrl

        if ($releases.assets) {
            $targetAsset = $releases.assets | Where-Object -Property name -EQ $assetName | Select-Object -First 1

            if ($targetAsset) {
                Write-Verbose -Message ("Found matching asset: '{0}'" -f $targetAsset.name)

                $filePath = Join-Path $ToolDir $targetAsset.name
                Invoke-RestMethod -Uri $targetAsset.browser_download_url -OutFile $filePath

                $toolDir = Join-Path $ToolDir (Split-Path -LeafBase $targetAsset.name)

                if ($Extract.IsPresent) {
                    Write-Verbose -Message ("Extracting '{0}' to '{1}'" -f $filePath, $toolDir)
                    Expand-Archive -Path $filePath -DestinationPath $toolDir -Force
                }

                if (-not ([string]::IsNullOrEmpty($AddToPath))) {
                    $pathToadd = Join-Path $toolDir $AddToPath
                    if (-not (Test-Path -Path $pathToadd)) {
                        Write-Error "The specified path '$pathToadd' does not exist."
                        return
                    }
                    
                    $env:Path += [System.IO.Path]::PathSeparator + $pathToadd
                    Write-Verbose -Message ("Added '{0}' to PATH" -f $toolDir)
                }
            }
        }
    }
}

function Get-GitRepositoryInfo() {
    $gitFile = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

    if (-not (Test-Path -Path $gitFile)) {
        Write-Error -Message ("This script must be run inside a Git repository. Current directory '{0}' searched." -f $gitFile)
        return
    }

    $repoInfo = [PSCustomObject]@{
        RemoteUrl           = (git config --get remote.origin.url)
        CurrentBranch       = (git rev-parse --abbrev-ref HEAD)
        LastCommitHash      = (git rev-parse HEAD)
        LastCommitShortHash = (git rev-parse --short HEAD)
        LastCommitDate      = (git log -1 --format=%cd)
        LastCommitMessage   = (git log -1 --pretty=%B)
        RepositoryRoot      = (git rev-parse --show-toplevel)
        Owner               = $null
        RepositoryName      = $null
    }
    
    if ($repoInfo.RemoteUrl) {
        if ($repoInfo.RemoteUrl -match "github\.com[:/](?<owner>[^/]+)/(?<repo>[^/\.]+)(\.git)?") {
            $repoInfo.Owner = $matches.owner
            $repoInfo.RepositoryName = $matches.repo -replace '\.git$', ''
        }
    }
    
    return $repoInfo
}

function Install-RequiredPsModule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter()]
        [string]$Repository = 'PSGallery',

        [Parameter(Mandatory = $true)]
        [string]$Version,


        [Parameter()]
        [switch]$TrustRepository
    )

    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Verbose "Installing module '$ModuleName' from repository '$Repository'"
        
        $installParams = @{
            Name            = $ModuleName
            Repository      = $Repository
            TrustRepository = $TrustRepository
            Scope           = 'CurrentUser'
            Version         = $Version
        }
        
        Install-PSResource @installParams
    }
}

function Install-UvPackageManager() {
    if (-not (Get-Command uv.exe -Type Application -ErrorAction Ignore)) {
        Write-Verbose -Message "Installing uv package manager"
        Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
    }

    $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
}

function Build-PythonProject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        
        [Parameter()]
        [string]$OutputName = 'win32service',
        
        [Parameter()]
        [string]$MainScript = 'main.py',
        
        [Parameter()]
        [string]$Icon = 'NONE'
    )

    begin {
        Write-Verbose -Message ("Starting function: {0}" -f $MyInvocation.MyCommand.Name)
        $outputDir = Join-Path $ProjectPath 'output'
        $sourceDir = Join-Path $ProjectPath 'src'

    }

    process {
        Push-Location -Path $sourceDir -ErrorAction Stop

        try {
            # Create virtual environment
            & uv venv

            # Activate it
            & .\.venv\Scripts\activate.ps1

            # Sync all the dependencies
            & uv sync

            $poFiles = Get-ChildItem -Path $ProjectPath -Filter '*.po' -Recurse
            foreach ($poFile in $poFiles) {
                $moFile = [System.IO.Path]::ChangeExtension($poFile.FullName, '.mo')
                & msgfmt.exe -o $moFile $poFile.FullName --verbose
            }

            # Add locales directory to the path
            $localesPath = Join-Path $ProjectPath 'locales'
            $localesSpec = $localesPath + [System.IO.Path]::PathSeparator + "locales"

            Write-Verbose -Message "Using locales spec: $localesSpec"

            # Build the project
            $pyInstallerArgs = @(
                $MainScript,
                '-F',
                '--clean',
                '--distpath', $outputDir,
                '--name', $OutputName,
                '--icon', $Icon,
                '--upx-dir', (Join-Path $PSScriptRoot 'tools' 'upx'),
                '--add-data', $localesSpec
            )
            & pyinstaller.exe @pyInstallerArgs

        }
        finally {
            deactivate
            Pop-Location -ErrorAction Ignore
        }
    }
    end {
        Write-Verbose -Message ("Finished function: {0}" -f $MyInvocation.MyCommand.Name)
    }
}