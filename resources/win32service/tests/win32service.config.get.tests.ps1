Describe 'Win32Service config get tests' {
    It 'Can get a service' -Skip:(!$IsWindows) {
        $jsonBody = @{name = 'W32Time'} | ConvertTo-Json -Depth 5
        $out = win32service config get --input $jsonBody

        $LASTEXITCODE | Should -Be 0
        $json = $out | ConvertFrom-Json -ErrorAction Stop
        $json.name | Should -Be 'W32Time'
        $json.displayName | Should -Be 'Windows Time'
        ($json.psobject.properties | Measure-Object).Count | Should -Be 8
    }

    It 'Cannot get a service' -Skip:(!$IsWindows) {
        $jsonBody = @{name = 'W32Time123'} | ConvertTo-Json -Depth 5
        $out = win32service config get --input $jsonBody

        $LASTEXITCODE | Should -Be 0
        $json = $out | ConvertFrom-Json -ErrorAction Stop
        $json._exist | Should -Be $false
        $json.name | Should -Be 'W32Time123'
    }
}