using System.CommandLine;
using OpenDsc.Resource.CommandLine;
using DSCUniversalResources.Windows.User;

var resource = new userResource(SourceGenerationContext.Default);
var command = CommandBuilder<userResource, userSchema>.Build(resource, SourceGenerationContext.Default);
return command.Invoke(args);
