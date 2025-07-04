using System.Text.Json.Serialization;

using OpenDsc.Resource;

namespace DSCUniversalResources.Windows.User;

public sealed class userResource : AotDscResource<userSchema>, IGettable<userSchema>, ISettable<userSchema>, IDeletable<userSchema>, IExportable<userSchema>
{
    public userResource(JsonSerializerContext context) : base("DSCUniversalResources.Windows/User", context)
    {
        Description = "Manage users in computer management.";
        Tags = ["Windows"];
        ExitCodes.Add(4, new() { Exception = typeof(FileNotFoundException), Description = "Failed to get user information" });
        ExitCodes.Add(5, new() { Exception = typeof(InvalidOperationException), Description = "Failed to create or update user" });
        ExitCodes.Add(6, new() { Exception = typeof(InvalidOperationException), Description = "Failed to delete user" });
        ExitCodes.Add(7, new() { Exception = typeof(InvalidOperationException), Description = "Failed to export users" });
    }

    public userSchema Get(userSchema instance)
    {
        return userUtils.GetUser(instance.userName);
    }

    public SetResult<userSchema> Set(userSchema instance)
    {
        try
        {
            bool userExists = userUtils.UserExists(instance.userName);

            if (!userExists)
            {
                Logger.WriteTrace($"Creating user '{instance.userName}'");
                userUtils.CreateUser(instance);
            }
            else
            {
                Logger.WriteTrace($"Updating user '{instance.userName}'");
                userUtils.UpdateUser(instance);
            }

            return new SetResult<userSchema>(instance);
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Failed to set user '{instance.userName}': {ex.Message}", ex);
        }
    }

    public void Delete(userSchema instance)
    {
        try
        {
            if (userUtils.UserExists(instance.userName))
            {
                Logger.WriteTrace($"Deleting user '{instance.userName}'");
                userUtils.DeleteUser(instance.userName);
            }
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Failed to delete user '{instance.userName}': {ex.Message}", ex);
        }
    }

    public IEnumerable<userSchema> Export()
    {
        return userUtils.GetAllUsers();
    }
}
