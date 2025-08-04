using System.Text.Json.Serialization;

namespace UniversalDsc.Resource.Windows.Group;

public sealed class Schema
{
    [JsonRequired]
    public string GroupName { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string[]? Members { get; set; }

    public string[]? MembersToInclude { get; set; }

    public string[]? MembersToExclude { get; set; }

    [JsonPropertyName("_exist")]
    public bool? Exist { get; set; }

    [JsonPropertyName("_inDesiredState")]
    public bool? InDesiredState { get; set; }
}
