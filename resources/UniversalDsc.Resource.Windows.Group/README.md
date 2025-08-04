# UniversalDsc.Resource.Windows.Group

A Universal DSC Resource for managing Windows local groups. This resource provides management of Windows local groups through Microsoft Desired State Configuration (DSC) v3 or running the executable standalone.

## Features

- Create, update, and delete local Windows groups
- Manage group properties: name, description, and membership
- Configure group membership: add specific members, include/exclude members
- Support for users and groups as members
- Full integration with DSC v3 framework
- Support for `get`, `set`, `test`, `delete`, and `export` operations

## Usage

### Installation

```powershell
dotnet tool install UniversalDsc.Resource.Windows.Group --global

dotnet tool install UniversalDsc.Resource.Windows.Group --tool-path mytools
```

## Microsoft DSC v3 integration

The `windows-group.exe` can be executed through Microsoft DSC v3. Using `dotnet.exe tool install` doesn't automatically copy the `windows-group.dsc.resource.json` to the root directory. If you manually copy the file in the root, the DSC engine can pick it up.

The following code snippet can be run after the tool is installed:

```powershell
$rootPath = Join-Path $env:USERPROFILE -ChildPath '.dotnet' -AdditionalChildPath 'tools'
$storePath = Join-Path $rootPath -ChildPath '.store' -AdditionalChildPath 'universaldsc.resource.windows.group'

$manifestFile = Get-ChildItem -Path $storePath -Recurse -Filter *.dsc.resource.json | Select-Object -First 1
Copy-Item -Path $manifestFile -Destination $rootPath
```

### Configuration document example

The following example shows you how you can run a configuration document through `dsc.exe`:

```yaml
# group.dsc.config.yaml
$schema: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
resources:
  - name: TestGroup
    type: UniversalDsc.Windows/Group
    properties:
      groupName: testgroup
      description: Test group for demonstration
      members: 
        - Administrator
        - testuser
  - name: PowerUsersGroup
    type: UniversalDsc.Windows/Group
    properties:
      groupName: PowerUsers
      description: Power Users with specific membership
      membersToInclude:
        - Administrator
      membersToExclude:
        - Guest
```

Run the following command to execute `dsc.exe` if you have it installed:

```bash
dsc config get --file group.dsc.config.yaml
```

### Properties

- **groupName** (required): The name for the local group
- **description** (optional): Description for the group
- **members** (optional): Array of specific members that should be in the group (exact membership)
- **membersToInclude** (optional): Array of members to ensure are included in the group
- **membersToExclude** (optional): Array of members to ensure are excluded from the group
- **exist** (optional): Whether the group should exist (true/false, defaults to true)

### Member management options

You can manage group membership in three ways:

1. **Exact membership** (`members`): Specifies the exact list of members. Any existing members not in this list will be removed.
2. **Additive membership** (`membersToInclude`): Ensures specified members are added to the group without affecting other existing members.
3. **Exclusive membership** (`membersToExclude`): Ensures specified members are removed from the group without affecting other members.

> [!NOTE]
> `members` cannot be used with `membersToInclude` or `membersToExclude`. However, `membersToInclude` and `membersToExclude` can be used together.

### Examples

#### Create a group with specific members

```bash
windows-group.exe config set --input '{"groupName":"TestGroup","description":"Test group","members":["Administrator","testuser"]}'
```

#### Add members to an existing group

```bash
windows-group.exe config set --input '{"groupName":"PowerUsers","membersToInclude":["newuser"]}'
```

#### Remove specific members from a group

```bash
windows-group.exe config set --input '{"groupName":"PowerUsers","membersToExclude":["Guest"]}'
```

#### Check if a group exists and get its current state

```bash
windows-group.exe config get --input '{"groupName":"TestGroup"}'
```

#### Test if a group is in desired state

```bash
windows-group.exe config test --input '{"groupName":"TestGroup","members":["Administrator"]}'
```

#### Export all local groups

```bash
windows-group.exe config export
```

## Additional information

- [Install Microsoft DSC v3](https://learn.microsoft.com/en-us/powershell/dsc/overview?view=dsc-3.0#install-dsc-on-windows-with-winget)
