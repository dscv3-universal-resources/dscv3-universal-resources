[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ProjectName,

    [ValidateSet("Release", "Debug")]
    [string]
    $Configuration = "Debug",

    [switch]
    $Clean,

    [switch]
    $Publish,

    [switch]
    $Test,

    [switch]
    $Pack,

    [switch]
    $Release
)

$errorActionPreference = 'Stop'
$outputDirectory = Join-Path $PSScriptRoot 'output'

# dot-source the common build helpers
. (Join-Path $PSScriptRoot 'sharedScripts' 'buildHelpers' 'common.ps1')

function getNetPath
{
    $dotnetPaths = @()
    
    # Check x64 path
    $dotnetPathX64 = Get-ChildItem -Path (Join-Path $env:ProgramFiles 'dotnet' 'sdk' '9.0.*') -ErrorAction Ignore | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($dotnetPathX64)
    {
        $dotnetX64 = Join-Path $env:ProgramFiles 'dotnet' 'dotnet.exe'
        if (Test-Path $dotnetX64)
        {
            $dotnetPaths += $dotnetX64
        }
    }

    # Check x86 path
    $dotnetPathX86 = Get-ChildItem -Path (Join-Path ${env:ProgramFiles(x86)} 'dotnet' 'sdk' '9.0.*') -ErrorAction Ignore | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($dotnetPathX86)
    {
        $dotnetX86 = Join-Path ${env:ProgramFiles(x86)} 'dotnet' 'dotnet.exe'
        if (Test-Path $dotnetX86)
        {
            $dotnetPaths += $dotnetX86
        }
    }

    if ($dotnetPaths.Count -ne 2) {
        return $false
    }

    return $dotnetPaths[0]
}

function getProjectPath ($ProjectName)
{
    $projectPath = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "$ProjectName.csproj" -File -ErrorAction Ignore | Select-Object -First 1
    if ($null -eq $projectPath)
    {
        Write-Error "Project file '$ProjectName.csproj' not found in the script directory or its subdirectories."
        return
    }

    return $projectPath.FullName
}

function saveChangeLogModule
{
    if (-not (Get-Module -Name 'ChangeLogManagement' -ListAvailable -ErrorAction Ignore))
    {
        $params = @{
            Name            = 'ChangeLogManagement'
            Repository      = 'PSGallery'
            Version         = '3.1.0'
            TrustRepository = $true
            ErrorAction     = 'Stop'
            Path            = $outputDirectory
        }
        Save-PSResource @params

        $env:PSModulePath += ([System.IO.Path]::PathSeparator + $outputDirectory)
    }
}

$dotnet = getNetPath
if (-not $dotnet)
{
    Write-Error "Dotnet SDK not found. Please install .NET SDK 9.0 or later for both 'x64' and 'x86'."
    return 
}

$projectFile = getProjectPath -ProjectName $ProjectName

if ($Clean.IsPresent)
{
    Write-Verbose "Cleaning output directory '$outputDirectory'" -Verbose
    if (Test-Path -Path $outputDirectory)
    {
        Remove-Item -Path $outputDirectory -Recurse -Force -ErrorAction Stop
    }

    & $dotnet clean $projectFile -c $Configuration -nologo
}

$build = @(
    'build',
    $projectFile,
    '--nologo',
    '--configuration', $Configuration
)

& $dotnet @build

# Set the output directories for packing and publishing
$outputDirectories = @()
$outputDirectories += Join-Path $outputDirectory 'nupkgs'
$outputDirectories += Join-Path $outputDirectory 'GitHub' 'win-x64'
$outputDirectories += Join-Path $outputDirectory 'GitHub' 'win-x86'

if ($Publish.IsPresent)
{
    # TODO: Should add more parameters if needed
    foreach ($outputDir in $outputDirectories)
    {
        $publishParams = @(
            'publish',
            $projectFile,
            '--configuration', $Configuration
        )

        if ($Configuration -eq 'Release')
        {
            $publishParams += '/p:DebugType=None'
            $publishParams += '/p:DebugSymbols=False'
        }

        if ($outputDir -like '*nupkgs')
        {
            Write-Verbose -Message "Publishing project '$ProjectName' to NuGet package in '$outputDir'" -Verbose
            $publishParams += "/p:NuspecFile=$($projectFile -replace '\.csproj$', '.nuspec')"
        }
        else
        {
            $runtime = Split-Path -Path $outputDir -Leaf
            Write-Verbose -Message "Publishing project '$ProjectName' to executable in '$outputDir'" -Verbose
            $publishParams += "/p:SelfContained=false"
            $publishParams += "/p:PublishSingleFile=true"
            $publishParams += '--runtime', $runtime
        }

        $publishParams += '--output', $outputDir
        Write-Verbose ($publishParams | ConvertTo-Json | Out-String) -Verbose
        & $dotnet @publishParams

        if ($LASTEXITCODE -ne 0)
        {
            Write-Error "Failed to publish project '$ProjectName'. Exit code: $LASTEXITCODE"
            return
        }
    }
}

if ($Test.IsPresent)
{
    # TODO: We should check if publish is done before running tests
    if (-not (Get-Module -Name 'Pester' -ListAvailable -ErrorAction Ignore))
    {
        $params = @{
            Name            = 'Pester'
            Scope           = 'CurrentUser'
            Repository      = 'PSGallery'
            Version         = '5.7.1'
            TrustRepository = $true
            ErrorAction     = 'Stop'
        }
        Install-PSResource @params
    }

    $testContainerData = @{
        ProjectName = $ProjectName
    }

    Invoke-Pester -Configuration @{
        Run    = @{
            Container = New-PesterContainer -Path (Join-Path $PSScriptRoot 'tests' 'integration') -Data $testContainerData
        }
        Output = @{
            Verbosity = 'Detailed'
        }
    } -ErrorAction Stop
}

if ($Pack.IsPresent)
{
    if ($Configuration -ne 'Release')
    {
        Write-Error "Packing is only supported for the 'Release' configuration. Please set the configuration to 'Release' and try again."
        return
    }

    $changeLogPath = Join-Path -Path (Split-Path $projectFile -Parent) -ChildPath 'CHANGELOG.md'
    if (-not (Test-Path -Path $changeLogPath))
    {
        Write-Error "CHANGELOG.md file not found at '$changeLogPath'. Please create a changelog before packing."
        return
    }

    $script:changeLog = Get-ChangelogData -Path $changeLogPath

    if ($null -eq $changeLog.LastVersion)
    {
        Write-Error "No version found in CHANGELOG.md. Please ensure the file contains a valid version entry."
        return
    }

    Write-Verbose "Packing project '$ProjectName' with version '$($changeLog.LastVersion)'" -Verbose
    $nugetPkgsPath = Join-Path $outputDirectory 'nupkgs'

    $nuSpecFile = Join-Path (Split-Path $projectFile -Parent) "$($ProjectName).nuspec"
    Write-Verbose "Using NuSpec file at '$nuSpecFile'" -Verbose

    # Read the nuspec file
    [xml]$nuspecContent = Get-Content -Path $nuSpecFile -Raw
    
    # Store the original version
    $originalVersion = $nuspecContent.package.metadata.version
    
    try
    {
        # Update the version in the nuspec
        $nuspecContent.package.metadata.version = $changeLog.LastVersion.ToString()
        
        # Save back to the original file
        $nuspecContent.Save($nuSpecFile)
        
        Write-Verbose "Updated version in nuspec to '$($changeLog.LastVersion)'" -Verbose
    }
    catch
    {
        throw "Failed to update nuspec file: $_"
    }

    $packParams = @(
        'pack',
        $projectFile,
        '--configuration', $Configuration,
        '--output', $nugetPkgsPath,
        '--no-build',
        "/p:NuspecFile=$nuSpecFile"
    )

    Write-Verbose "Packing project '$ProjectName' to '$nugetPkgsPath'" -Verbose
    & $dotnet @packParams

    if ($LASTEXITCODE -ne 0)
    {
        Write-Error "Failed to pack project '$ProjectName'. Exit code: $LASTEXITCODE"
        return
    }

    Write-Verbose "Packing completed successfully. NuGet packages are available in '$nugetPkgsPath'" -Verbose
    # Restore the original version in the nuspec file
    try
    {
        $nuspecContent.package.metadata.version = $originalVersion
        $nuspecContent.Save($nuSpecFile)
        Write-Verbose "Restored original version '$originalVersion' in nuspec file." -Verbose
    }
    catch
    {
        Write-Warning "Failed to restore original version in nuspec file: $_"
    }

    $gitHubPath = Join-Path $outputDirectory 'GitHub'
    $exe = Get-ChildItem -Path $gitHubPath -Filter *.exe -Recurse

    $zips = @()
    foreach ($arch in $exe) {
        $filesToZip = @(
            $arch.FullName,
            (Join-Path ($arch.DirectoryName) "$($arch.BaseName).dsc.resource.json")
        )

        $compressParams = @{
            Path            = $filesToZip
            DestinationPath = (Join-Path $gitHubPath "$($arch.BaseName)-$($changeLog.LastVersion)-$($arch.Directory.Name.TrimStart('win-')).zip")
            Force           = $true
            PassThru        = $true
        }

        # create the zip file
        Write-Verbose "Creating zip file for '$($arch.Name)' at '$($compressParams.DestinationPath)'" -Verbose
        $zips += Compress-Archive @compressParams
    }
}

if ($Release.IsPresent)
{
    $repo = Get-GitRepositoryInfo
    $tagName = [System.IO.Path]::Combine('resources', $ProjectName, $changeLog.LastVersion)
    $releaseParams = @{
        Owner      = $repo.Owner 
        Repository = $repo.RepositoryName
        Tag        = $tagName.Replace('\', '/')
    }

    Write-Verbose -Message ($releaseParams | ConvertTo-Json | Out-String) -Verbose
    $currentRelease = Get-GitHubRelease @releaseParams -ErrorAction Ignore
    if (-not $currentRelease)
    {
        Write-Verbose -Message "No existing release found for tag '$($releaseParams.Tag)'. Creating a new release." -Verbose
        $releaseParams.Add('Notes', $changeLog.ReleaseNotes)
        $releaseParams.Add('Latest', $false)
        $currentRelease = New-GitHubRelease @releaseParams -ErrorAction Stop
        Write-Verbose -Message "Release created successfully with tag '$($releaseParams.Tag)'" -Verbose

        # Adding asset
        foreach ($zip in $zips) {
            Write-Verbose -Message "Adding asset '$($zip.Name)' to release '$($currentRelease.Tag)'" -Verbose
            if (-not (Test-Path -Path $zip.FullName))
            {
                Write-Error "Zip file '$($zip.FullName)' does not exist. Cannot add to release."
                continue
            } else 
            {
                $currentRelease | Add-GitHubReleaseAsset -Path $zip.FullName `
                -Name $zip.Name `
                -ContentType 'application/zip' `
                -ErrorAction Stop
            }
        }
    }
    else
    {
        Write-Verbose -Message "Release already exists for tag '$($releaseParams.Tag)'. Updating release notes." -Verbose
        $currentRelease | Update-GitHubRelease -Notes $changeLog.ReleaseNotes -ErrorAction Stop
    }   
}