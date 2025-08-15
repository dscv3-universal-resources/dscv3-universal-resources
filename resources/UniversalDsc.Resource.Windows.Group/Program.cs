using System.CommandLine;

using OpenDsc.Resource.CommandLine;

using UniversalDsc.Resource.Windows.Group;

var resource = new Resource();
var command = CommandBuilder<Resource, Schema>.Build(resource, resource.SerializerOptions);

if (args.Length == 0)
{
    command.Invoke(args);
    return 0;
}
return command.Invoke(args);
