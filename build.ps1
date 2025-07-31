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
    $Pack
)

$outputDirectory = Join-Path $PSScriptRoot 'output'

function getNetPath
{
    $dotnet = (Get-Command dotnet -CommandType Application -ErrorAction Ignore | Select-Object -First 1).Source
    if ($null -eq $dotnet)
    {
        $dotnetPath = Get-ChildItem -Path (Join-Path $env:ProgramFiles 'dotnet' 'sdk' '9.0.*') | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (Test-Path -Path $dotnetPath)
        {
            $dotnet = Join-Path $env:ProgramFiles 'dotnet' 'dotnet.exe'
        }
        else
        {
            return $false
        } 
    }

    return $dotnet
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

function saveChangeLogModule {
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
    Write-Error "Dotnet SDK not found. Please install .NET SDK 9.0 or later."
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
$outputDirectories += Join-Path $outputDirectory 'GitHub'

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
            Write-Verbose -Message "Publishing project '$ProjectName' to executable in '$outputDir'" -Verbose
            $publishParams += "/p:SelfContained=false"
            $publishParams += "/p:PublishSingleFile=true"
            $publishParams += '--runtime', 'win-x64'
        }

        $publishParams += '--output', $outputDir
        Write-Verbose -Message "Publishing project '$ProjectName' to '$outputDir'" -Verbose
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

    $changeLog = Get-ChangelogData -Path $changeLogPath

    if ($changeLog.LastVersion -eq $null)
    {
        Write-Error "No version found in CHANGELOG.md. Please ensure the file contains a valid version entry."
        return
    }

    Write-Verbose "Packing project '$ProjectName' with version '$($changeLog.LastVersion)'" -Verbose
    $nugetPkgsPath = Join-Path $outputDirectory 'nupkgs'
    $packParams = @(
        'pack',
        $projectFile,
        '--configuration', $Configuration,
        '--output', $nugetPkgsPath,
        '--no-build',
        "/p:NuspecFile=$($projectFile -replace '\.csproj$', '.nuspec')",
        "--version-suffix", $changeLog.LastVersion
    )

    Write-Verbose "Packing project '$ProjectName' to '$nugetPkgsPath'" -Verbose
    & $dotnet @packParams

    if ($LASTEXITCODE -ne 0)
    {
        Write-Error "Failed to pack project '$ProjectName'. Exit code: $LASTEXITCODE"
        return
    }
}