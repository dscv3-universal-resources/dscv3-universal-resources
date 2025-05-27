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

Describe 'Win32Service config set tests' {
    It 'Can create a new service with default properties' {
        $jsonBody = @{
            name = 'TestService'
            path        = (Get-Process -Id $PID).Path
        } | ConvertTo-Json

        $out = win32service config set --input $jsonBody
        $LASTEXITCODE | Should -Be 0

        $out = win32service config get --input $jsonBody
        $json = $out | ConvertFrom-Json
        $json.name | Should -Be 'TestService'
        $json.displayName | Should -Be 'TestService'
        $json.path | Should -BeLike "*$($jsonBody.path)*"
        $json.startupType | Should -Be 'Disabled' # Default startup type

    }

    It 'Can delete a service' {
        $jsonBody = @{
            name = 'TestService'
        } | ConvertTo-Json

        $out = win32service config delete --input $jsonBody
        $LASTEXITCODE | Should -Be 0
        
        $out = win32service config get --input $jsonBody
        $LASTEXITCODE | Should -Be 0
        $json = $out | ConvertFrom-Json -ErrorAction Stop
        $json._exist | Should -Be $false
    }

    It 'Can delete a service using dsc.exe' -Skip:$dscExist {
        $config = @{
            '$schema' = 'https://aka.ms/dsc/schemas/v3/bundled/config/document.json'
            resources = @(
                @{
                    name = 'service'
                    type = 'DSCResources.Windows/Win32Service'
                    properties = @{
                        name = 'DSCService'
                        path       = (Get-Process -Id $PID).Path
                        _exist = $true
                    }
                }
            )
        }

        $out = dsc config set --input ($config | ConvertTo-Json -Depth 10)
        $LASTEXITCODE | Should -Be 0

        $config.resources[0].properties._exist = $false
        $out = dsc config set -i ($config | ConvertTo-Json -Depth 10) | ConvertFrom-Json
        $LASTEXITCODE | Should -Be 0
        $out.results[0].result.afterState._exist | Should -Be $false
    }
}
AfterAll {
    if (!$script:dscExist) {
        Remove-Item -Path (Join-Path $script:dscPath 'win32service.exe') -Force -ErrorAction Ignore
        Remove-Item -Path (Join-Path $script:dscPath 'win32service.dsc.resource.json') -Force -ErrorAction Ignore
    }
}