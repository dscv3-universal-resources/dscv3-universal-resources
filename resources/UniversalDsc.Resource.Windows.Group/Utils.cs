using System.DirectoryServices.AccountManagement;
using OpenDsc.Resource;

namespace UniversalDsc.Resource.Windows.Group;

internal static class Utils
{
    public static Schema GetGroup(string groupName)
    {
        Logger.WriteTrace($"Getting group '{groupName}'");
        
        using var context = new PrincipalContext(ContextType.Machine);
        using var group = GroupPrincipal.FindByIdentity(context, groupName);
        
        if (group == null)
        {
            Logger.WriteTrace($"Group '{groupName}' not found");
            return new Schema()
            {
                GroupName = groupName,
                Exist = false
            };
        }

        var members = new List<string>();
        foreach (var member in group.Members)
        {
            members.Add(member.SamAccountName ?? member.Name);
        }

        Logger.WriteTrace($"Found group '{groupName}' with {members.Count} members");
        return new Schema()
        {
            GroupName = groupName,
            Exist = true,
            Description = group.Description,
            Members = members.ToArray()
        };
    }

    public static bool GroupExists(string groupName)
    {
        Logger.WriteTrace($"Checking if group '{groupName}' exists");
        
        using var context = new PrincipalContext(ContextType.Machine);
        using var group = GroupPrincipal.FindByIdentity(context, groupName);
        bool exists = group != null;
        
        Logger.WriteTrace($"Group '{groupName}' exists: {exists}");
        return exists;
    }

    public static IEnumerable<Schema> GetAllGroups()
    {
        Logger.WriteTrace("Enumerating all local groups");
        
        using var context = new PrincipalContext(ContextType.Machine);
        using var searcher = new PrincipalSearcher(new GroupPrincipal(context));
        
        int groupCount = 0;
        foreach (var result in searcher.FindAll())
        {
            if (result is GroupPrincipal group)
            {
                var members = new List<string>();
                foreach (var member in group.Members)
                {
                    members.Add(member.SamAccountName ?? member.Name);
                }

                groupCount++;
                yield return new Schema()
                {
                    GroupName = group.Name,
                    Exist = true,
                    Description = group.Description,
                    Members = members.ToArray()
                };
            }
        }
        
        Logger.WriteTrace($"Enumerated {groupCount} local groups");
    }

    public static void CreateGroup(Schema groupSchema)
    {
        Logger.WriteTrace($"Creating group '{groupSchema.GroupName}'");
        
        using var context = new PrincipalContext(ContextType.Machine);
        using var group = new GroupPrincipal(context);
        
        group.SamAccountName = groupSchema.GroupName;
        group.Name = groupSchema.GroupName;
        
        if (!string.IsNullOrEmpty(groupSchema.Description))
            group.Description = groupSchema.Description;
        
        group.Save();
        Logger.WriteTrace($"Group '{groupSchema.GroupName}' created successfully");
    }

    public static void UpdateGroup(Schema groupSchema)
    {
        Logger.WriteTrace($"Updating group '{groupSchema.GroupName}'");
        
        using var context = new PrincipalContext(ContextType.Machine);
        using var group = GroupPrincipal.FindByIdentity(context, groupSchema.GroupName);
        
        if (group == null)
            throw new InvalidOperationException($"Group '{groupSchema.GroupName}' not found");
        
        if (!string.IsNullOrEmpty(groupSchema.Description))
        {
            Logger.WriteTrace($"Updating description for group '{groupSchema.GroupName}'");
            group.Description = groupSchema.Description;
        }
        
        group.Save();
        
        if (groupSchema.Members != null)
        {
            Logger.WriteTrace($"Setting exact membership ({groupSchema.Members.Length} members) for group '{groupSchema.GroupName}'");
            SetGroupMembers(group, groupSchema.Members, context);
        }
        else
        {
            if (groupSchema.MembersToInclude != null && groupSchema.MembersToInclude.Length > 0)
            {
                Logger.WriteTrace($"Adding {groupSchema.MembersToInclude.Length} members to group '{groupSchema.GroupName}'");
                AddMembersToGroup(group, groupSchema.MembersToInclude, context);
            }
            
            if (groupSchema.MembersToExclude != null && groupSchema.MembersToExclude.Length > 0)
            {
                Logger.WriteTrace($"Removing {groupSchema.MembersToExclude.Length} members from group '{groupSchema.GroupName}'");
                RemoveMembersFromGroup(group, groupSchema.MembersToExclude, context);
            }
        }
        
        Logger.WriteTrace($"Group '{groupSchema.GroupName}' updated successfully");
    }

    public static void DeleteGroup(string groupName)
    {
        Logger.WriteTrace($"Deleting group '{groupName}'");
        
        using var context = new PrincipalContext(ContextType.Machine);
        using var group = GroupPrincipal.FindByIdentity(context, groupName);
        
        if (group == null)
            throw new InvalidOperationException($"Group '{groupName}' not found");
        
        group.Delete();
        Logger.WriteTrace($"Group '{groupName}' deleted successfully");
    }

    public static bool TestGroup(Schema groupSchema)
    {
        Logger.WriteTrace($"Testing group '{groupSchema.GroupName}' desired state");
        
        var currentGroup = GetGroup(groupSchema.GroupName);
        
        if (groupSchema.Exist == false)
        {
            bool shouldNotExist = !currentGroup.Exist.GetValueOrDefault(true);
            Logger.WriteTrace($"Group '{groupSchema.GroupName}' should not exist: {shouldNotExist}");
            return shouldNotExist;
        }
        
        if (!currentGroup.Exist.GetValueOrDefault(false))
        {
            Logger.WriteTrace($"Group '{groupSchema.GroupName}' does not exist but should");
            return false;
        }
        
        if (!string.IsNullOrEmpty(groupSchema.Description) && 
            groupSchema.Description != currentGroup.Description)
        {
            Logger.WriteTrace($"Group '{groupSchema.GroupName}' description mismatch. Expected: '{groupSchema.Description}', Actual: '{currentGroup.Description}'");
            return false;
        }
        
        if (groupSchema.Members != null)
        {
            var currentMembers = currentGroup.Members ?? Array.Empty<string>();
            var expectedMembers = groupSchema.Members;
            
            if (currentMembers.Length != expectedMembers.Length)
            {
                Logger.WriteTrace($"Group '{groupSchema.GroupName}' member count mismatch. Expected: {expectedMembers.Length}, Actual: {currentMembers.Length}");
                return false;
            }
            
            bool membersMatch = expectedMembers.All(member => currentMembers.Contains(member, StringComparer.OrdinalIgnoreCase));
            Logger.WriteTrace($"Group '{groupSchema.GroupName}' exact membership match: {membersMatch}");
            return membersMatch;
        }
        
        if (groupSchema.MembersToInclude != null)
        {
            var currentMembers = currentGroup.Members ?? Array.Empty<string>();
            bool allIncluded = groupSchema.MembersToInclude.All(member => 
                currentMembers.Contains(member, StringComparer.OrdinalIgnoreCase));
            
            if (!allIncluded)
            {
                Logger.WriteTrace($"Group '{groupSchema.GroupName}' missing required members");
                return false;
            }
        }
        
        if (groupSchema.MembersToExclude != null)
        {
            var currentMembers = currentGroup.Members ?? Array.Empty<string>();
            bool noneExcluded = groupSchema.MembersToExclude.Any(member => 
                currentMembers.Contains(member, StringComparer.OrdinalIgnoreCase));
            
            if (noneExcluded)
            {
                Logger.WriteTrace($"Group '{groupSchema.GroupName}' contains excluded members");
                return false;
            }
        }
        
        Logger.WriteTrace($"Group '{groupSchema.GroupName}' is in desired state");
        return true;
    }

    private static void SetGroupMembers(GroupPrincipal group, string[] members, PrincipalContext context)
    {
        Logger.WriteTrace($"Setting exact membership for group '{group.Name}' to {members.Length} members");
        group.Members.Clear();
        AddMembersToGroup(group, members, context);
    }

    private static void AddMembersToGroup(GroupPrincipal group, string[] members, PrincipalContext context)
    {
        Logger.WriteTrace($"Adding {members.Length} members to group '{group.Name}'");
        
        // Get current members for comparison
        var currentMembers = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var existingMember in group.Members)
        {
            var memberName = existingMember.SamAccountName ?? existingMember.Name;
            if (!string.IsNullOrEmpty(memberName))
                currentMembers.Add(memberName);
        }
        
        int successCount = 0;
        int skippedCount = 0;
        foreach (var memberName in members)
        {
            if (currentMembers.Contains(memberName))
            {
                Logger.WriteTrace($"Member '{memberName}' already exists in group '{group.Name}', skipping");
                skippedCount++;
                continue;
            }
            
            var member = ResolvePrincipal(memberName, context);
            if (member != null)
            {
                group.Members.Add(member);
                successCount++;
            }
            else
            {
                Logger.WriteTrace($"Failed to resolve member '{memberName}' for group '{group.Name}'");
            }
        }
        
        group.Save();
        Logger.WriteTrace($"Successfully added {successCount}/{members.Length} members to group '{group.Name}' (skipped {skippedCount} existing)");
    }

    private static void RemoveMembersFromGroup(GroupPrincipal group, string[] members, PrincipalContext context)
    {
        Logger.WriteTrace($"Removing {members.Length} members from group '{group.Name}'");
        
        // Get current members for comparison
        var currentMembers = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var existingMember in group.Members)
        {
            var memberName = existingMember.SamAccountName ?? existingMember.Name;
            if (!string.IsNullOrEmpty(memberName))
                currentMembers.Add(memberName);
        }
        
        int successCount = 0;
        int skippedCount = 0;
        foreach (var memberName in members)
        {
            if (!currentMembers.Contains(memberName))
            {
                Logger.WriteTrace($"Member '{memberName}' not found in group '{group.Name}', skipping");
                skippedCount++;
                continue;
            }
            
            var member = ResolvePrincipal(memberName, context);
            if (member != null)
            {
                group.Members.Remove(member);
                successCount++;
            }
            else
            {
                Logger.WriteTrace($"Failed to resolve member '{memberName}' for removal from group '{group.Name}'");
            }
        }
        
        group.Save();
        Logger.WriteTrace($"Successfully removed {successCount}/{members.Length} members from group '{group.Name}' (skipped {skippedCount} not found)");
    }

    private static Principal? ResolvePrincipal(string memberName, PrincipalContext context)
    {
        var user = UserPrincipal.FindByIdentity(context, memberName);
        if (user != null)
            return user;
        
        var group = GroupPrincipal.FindByIdentity(context, memberName);
        if (group != null)
            return group;
        
        return Principal.FindByIdentity(context, memberName);
    }

    private static void ValidateGroupName(string groupName)
    {
        if (string.IsNullOrWhiteSpace(groupName))
            throw new ArgumentException("Group name cannot be null or empty", nameof(groupName));
        
        var invalidChars = new[] { '\\', '/', '"', '[', ']', ':', '|', '<', '>', '+', '=', ';', ',', '?', '*', '@' };
        
        if (groupName.IndexOfAny(invalidChars) != -1)
            throw new ArgumentException($"Group name '{groupName}' contains invalid characters", nameof(groupName));
        
        if (groupName.All(c => char.IsWhiteSpace(c) || c == '.'))
            throw new ArgumentException($"Group name '{groupName}' cannot consist only of whitespace or dots", nameof(groupName));
    }
}
