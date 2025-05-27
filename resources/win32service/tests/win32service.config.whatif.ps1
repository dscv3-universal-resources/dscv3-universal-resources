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

    function Test-Administrator {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole($adminRole)
    }
}

BeforeDiscovery {
    function Test-Administrator {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole($adminRole)
    }

    $result = Test-Administrator
}

Describe "Win32Service config whatIf tests" {
    It 'WhatIf can create a new service with default properties' -Skip:(!$result) {
        $config = @{
            '$schema' = 'https://aka.ms/dsc/schemas/v3/bundled/config/document.json'
            resources = @(
                @{
                    name = 'service'
                    type = 'DSCResources.Windows/Win32Service'
                    properties = @{
                        name = 'NewService'
                        path       = (Get-Process -Id $PID).Path
                        _exist = $true
                    }
                }
            )
        }

        $out = dsc config set --input ($config | ConvertTo-Json -Depth 10) -w | ConvertFrom-Json
        $out.results.result.afterState.name | Should -Be 'NewService'
    }

    It 'Returns the property that gets modified in whatIf result' -Skip:(!$result) {
        $config = @{
            '$schema' = 'https://aka.ms/dsc/schemas/v3/bundled/config/document.json'
            resources = @(
                @{
                    name = 'service'
                    type = 'DSCResources.Windows/Win32Service'
                    properties = @{
                        name = 'NewService'
                        path       = (Get-Process -Id $PID).Path
                        _exist = $true
                    }
                }
            )
        }

        dsc config set --input ($config | ConvertTo-Json -Depth 10) | Out-Null

        $config.resources[0].properties.Add('description', 'This is a new service')
        $out = dsc config set --input ($config | ConvertTo-Json -Depth 10) -w | ConvertFrom-Json
        $out.results.result.changedProperties | Should -Contain 'description'
    }

    It 'Throws an error in whatIf mode that is unelevated' -Skip:($result) {
        $config = @{
            '$schema' = 'https://aka.ms/dsc/schemas/v3/bundled/config/document.json'
            resources = @(
                @{
                    name = 'service'
                    type = 'DSCResources.Windows/Win32Service'
                    properties = @{
                        name = 'NewService'
                        path       = (Get-Process -Id $PID).Path
                        _exist = $true
                    }
                }
            )
        }

        $out = dsc config set --input ($config | ConvertTo-Json -Depth 10) -w 2>&1
        $out[0] | Should -BeLike '*ERROR*'
        $out[0] | Should -BeLike '*Access is denied*'
    }
}

AfterAll {
    if (!$script:dscExist) {
        # Clean up service
        dsc config delete --resource 'DSCResources.Windows/Win32Service' --name (@{name = 'NewService'}) | Out-Null

        Remove-Item -Path (Join-Path $script:dscPath 'win32service.exe') -Force -ErrorAction Ignore
        Remove-Item -Path (Join-Path $script:dscPath 'win32service.dsc.resource.json') -Force -ErrorAction Ignore
    }
}

