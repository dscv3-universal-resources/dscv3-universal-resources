@{
    # This is a PowerShell data file that contains test data for the UniversalDsc.Resource.Windows.Group utility
    testCases = @(
        @{
            operation = 'get'
            testData = @(
                @{
                    groupName = 'Administrators'    
                }
            )
            requiresElevation = $false
        },
        @{
            operation = 'set'
            testData = @(
                @{
                    groupName = 'TestGroup'
                    description = 'Test Group for demonstration'
                    members = @('Administrator')
                },
                @{
                    groupName = 'TestGroupInclude'
                    description = 'Test Group with members to include'
                    membersToInclude = @('Administrator', 'Guest')
                },
                @{
                    groupName = 'TestGroupExclude'
                    description = 'Test Group with members to exclude'
                    membersToInclude = @('Administrator', 'Guest')
                    membersToExclude = @('Guest')
                }
            )
            requiresElevation = $true
        },
        @{
            operation = 'delete'
            testData = @(
                @{
                    groupName = 'TestGroup'
                },
                @{
                    groupName = 'TestGroupInclude'
                },
                @{
                    groupName = 'TestGroupExclude'
                }
            )
            requiresElevation = $true
        },
        @{
            operation = 'export'
            testData = @{
                groupName = "does not have to exist"
            }
            requiresElevation = $false
        }
    )  
}
