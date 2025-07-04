using System.Text.Json.Serialization;

namespace DSCUniversalResources.Windows.User;

public sealed class userSchema
{
    [JsonRequired]
    public string userName { get; set; } = string.Empty;

    public string? fullName { get; set; }

    public string? description { get; set; }

    public string? password { get; set; }

    public bool? disabled { get; set; }

    public bool? passwordNeverExpires { get; set; }

    public bool? passwordChangeRequired { get; set; }

    public bool? passwordChangeNotAllowed { get; set; }

    [JsonPropertyName("_exist")]
    public bool? exist { get; set; }
}
