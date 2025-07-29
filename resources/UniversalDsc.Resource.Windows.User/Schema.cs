// Copyright (c) Gijs Reijn - All Rights Reserved
// You may use, distribute and modify this code under the
// terms of the MIT license.

using System.Text.Json.Serialization;

namespace UniversalDsc.Resource.Windows.User;

public sealed class Schema
{
    [JsonRequired]
    public string Username { get; set; } = string.Empty;

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
