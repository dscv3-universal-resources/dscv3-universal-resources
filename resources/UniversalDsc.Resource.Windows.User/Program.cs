// Copyright (c) Gijs Reijn - All Rights Reserved
// You may use, distribute and modify this code under the
// terms of the MIT license.

using System.CommandLine;
using OpenDsc.Resource.CommandLine;
using UniversalDsc.Resource.Windows.User;

var resource = new Resource();
var command = CommandBuilder<Resource, Schema>.Build(resource, resource.SerializerOptions);
return command.Invoke(args);

