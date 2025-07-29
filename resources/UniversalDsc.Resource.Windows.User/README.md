# UniversalDsc.Resource.Windows.User

A Universal DSC Resource for managing Windows local user accounts. This resource provides management of Windows local users through Microsoft Desired State Configuration (DSC) v3.

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

### Configuration document example

```yaml
# Configuration document example
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
