# UniversalDsc.Resource.Windows.User

A Universal DSC Resource for managing Windows local user accounts. This resource provides management of Windows local users through Microsoft Desired State Configuration (DSC) v3 or running the executable standalone.

## Features

- Create, update, and delete local Windows user accounts
- Manage user properties: full name, description, password
- Configure account settings: enabled/disabled state, password expiration, password change requirements
- Full integration with DSC v3 framework
- Support for Get, Set, and Test operations

## Available package

| **Package**                                                                                             | **Platforms** | **Description**                                          |
| :------------------------------------------------------------------------------------------------------ | :------------ | :------------------------------------------------------- |
| [UniversalDsc.Resource.Windows.User](https://www.nuget.org/packages/UniversalDsc.Resource.Windows.User) | Windows       | DSC v3 resource for managing Windows local user accounts |

## Usage

### Installation

```powershell
dotnet tool install UniversalDsc.Resource.Windows.User --global

dotnet tool install UniversalDsc.Resource.Windows.User --tool-path mytools
```

## Microsoft DSC v3 integration

The `windows-user.exe` can be executed through Microsoft DSC v3. Using `dotnet.exe tool install` doesn't automatically copy the `windows-user.dsc.resource.json` to the root directory. If you manually copy the file in the root, the DSC engine can pick it up.

The following code snippet can be run after the tool is installed:

```powershell
$rootPath = Join-Path $env:USERPROFILE -ChildPath '.dotnet' -AdditionalChildPath 'tools'
$storePath = Join-Path $rootPath -ChildPath '.store' -AdditionalChildPath 'universaldsc.resource.windows.user'

$manifestFile = Get-ChildItem -Path $storePath -Recurse -Filter *.dsc.resource.json | Select-Object -First 1
Copy-Item -Path $manifestFile -Destination $rootPath
```

### Configuration document example

The following example shows you how you can run a configuration document through `dsc.exe`:

```yaml
# user.dsc.config.yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
resources:
  - name: TestUser
    type: UniversalDsc.Windows/user
    properties:
      username: testuser
      fullName: Test User
      description: Test user account
      disabled: false
      passwordNeverExpires: false
      passwordChangeRequired: true
```

Run the following command to execute `dsc.exe` if you have it installed:

```bash
dsc config get --file user.dsc.config.yaml
```

### Properties

- **userName** (required): The username for the local user account
- **fullName** (optional): The full display name for the user
- **description** (optional): Description for the user account
- **password** (optional): Password for the user account
- **disabled** (optional): Whether the account is disabled (true/false)
- **passwordNeverExpires** (optional): Whether the password never expires (true/false)
- **passwordChangeRequired** (optional): Whether password change is required at next logon (true/false)
- **passwordChangeNotAllowed** (optional): Whether the user can change their password (true/false)
- **exist** (optional): Whether the user should exist (true/false, defaults to true)

## Additional Information

- [Install Microsoft DSC v3](https://learn.microsoft.com/en-us/powershell/dsc/overview?view=dsc-3.0#install-dsc-on-windows-with-winget)