using System.Text.Json.Serialization;
using OpenDsc.Resource;
using OpenDsc.Resource.CommandLine;

namespace DSCUniversalResources.Windows.User;

[JsonSourceGenerationOptions(WriteIndented = false,
                             PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
                             UseStringEnumConverter = true,
                             DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
                             Converters = [typeof(ResourceConverter<userSchema>)])]
[JsonSerializable(typeof(IDscResource<userSchema>))]
[JsonSerializable(typeof(userSchema))]
[JsonSerializable(typeof(HashSet<string>))]
internal partial class SourceGenerationContext : JsonSerializerContext
{

}
