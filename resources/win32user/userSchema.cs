using System.Text.Json.Serialization;

namespace DSCUniversalResources.Windows.User;

public sealed class userSchema
{
    [JsonRequired]
    public string UserName { get; set; } = string.Empty;

    public string? FullName { get; set; }

    public string? Description { get; set; }

    public string? Password { get; set; }

    public bool? Disabled { get; set; }

    public bool? PasswordNeverExpires { get; set; }

    public bool? PasswordChangeRequired { get; set; }

    public bool? PasswordChangeNotAllowed { get; set; }

    [JsonPropertyName("_exist")]
    public bool? Exist { get; set; }
}
