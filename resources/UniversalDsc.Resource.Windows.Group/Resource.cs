using System.Text.Json;
using System.ComponentModel;
using OpenDsc.Resource;

namespace UniversalDsc.Resource.Windows.Group;

[DscResource("UniversalDsc.Windows/Group", Description = "Manage groups.", Tags = ["windows", "group"])]
[ExitCode(0, Description = "Success")]
[ExitCode(1, Description = "Invalid parameter")]
[ExitCode(2, Exception = typeof(Exception), Description = "Generic error")]
[ExitCode(3, Exception = typeof(JsonException), Description = "Invalid JSON")]
[ExitCode(4, Exception = typeof(InvalidOperationException), Description = "Group operation failed")]
[ExitCode(5, Exception = typeof(UnauthorizedAccessException), Description = "Access denied")]
public sealed class Resource : DscResource<Schema>, IGettable<Schema>, ISettable<Schema>, ITestable<Schema>, IDeletable<Schema>, IExportable<Schema>
{
    public Schema Get(Schema instance)
    {
        return Utils.GetGroup(instance.GroupName);
    }

    public SetResult<Schema> Set(Schema instance)
    {
        bool groupExists = Utils.GroupExists(instance.GroupName);

        if (!groupExists)
        {
            Utils.CreateGroup(instance);
        }
        
        Utils.UpdateGroup(instance);

        var currentGroup = Utils.GetGroup(instance.GroupName);
        return new SetResult<Schema>(currentGroup);
    }

    public void Delete(Schema instance)
    {
        if (Utils.GroupExists(instance.GroupName))
        {
            Utils.DeleteGroup(instance.GroupName);
        }
    }

    public TestResult<Schema> Test(Schema instance)
    {
        bool inDesiredState = Utils.TestGroup(instance);
        var currentState = Utils.GetGroup(instance.GroupName);
        currentState.InDesiredState = inDesiredState;
        return new TestResult<Schema>(currentState);
    }

    public IEnumerable<Schema> Export()
    {
        return Utils.GetAllGroups();
    }
}
