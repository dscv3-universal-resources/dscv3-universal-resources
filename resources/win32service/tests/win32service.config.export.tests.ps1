BeforeAll {
    $script:dscExist = $false
    $script:dscPath = [System.IO.Path]::GetDirectoryName((Get-Command dsc.exe).Source)
    if ([string]::IsNullOrEmpty($dscPath)) {
        $dscExist = $true
    } else {
        $win32serviceExe = Join-Path (Split-Path $PSScriptRoot -Parent)  'output' 'win32service.exe'
        Write-Verbose -Message "Copying $win32serviceExe to $dscPath" -Verbose
        Copy-Item -Path $win32serviceExe -Destination $dscPath -Force -ErrorAction Stop

        # Copy manifest for discovery 
        $manifestPath = Join-Path (Split-Path $PSScriptRoot -Parent)  'win32service.dsc.resource.json'
        Copy-Item -Path $manifestPath -Destination $dscPath -Force -ErrorAction Stop
    }
}

Describe "Win32Service config export tests" {
    It 'Can export all services using dsc.exe' {
        $config = @{
            '$schema' = 'https://aka.ms/dsc/schemas/v3/bundled/config/document.json'
            resources = @(
                @{
                    name       = 'service'
                    type       = 'DSCResources.Windows/Win32Service'
                    properties = @{
                        name = 'wuauserv'
                    }
                }
            )
        }

        $out = dsc config export --input ($config | ConvertTo-Json -Depth 10)
        $LASTEXITCODE | Should -Be 0 
        $json = $out | ConvertFrom-Json
        $json.resources.properties.services | Should -Not -BeNullOrEmpty
        $json.resources.properties.services.Count| Should -BeGreaterThan 1
    }
}

AfterAll {
    if (!$script:dscExist) {
        Remove-Item -Path (Join-Path $script:dscPath 'win32service.exe') -Force -ErrorAction Ignore
        Remove-Item -Path (Join-Path $script:dscPath 'win32service.dsc.resource.json') -Force -ErrorAction Ignore
    }
}

