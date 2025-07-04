using System.Text.Json.Serialization;
using OpenDsc.Resource;

namespace DSCUniversalResources.Windows.User;

public sealed class userResource : AotDscResource<userSchema>, IGettable<userSchema>
{
    public userResource(JsonSerializerContext context) : base("DSCResources.Windows/User", context)
    {
        Description = "Manage users in computer management.";
        Tags = ["Windows"];
        ExitCodes.Add(10, new() { Exception = typeof(FileNotFoundException), Description = "File not found" });
    }

    public userSchema Get(userSchema instance)
    {
        return userUtils.GetUser(instance.UserName);
    }
}
