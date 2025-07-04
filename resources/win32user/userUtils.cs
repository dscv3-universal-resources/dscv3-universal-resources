using System.DirectoryServices.AccountManagement;
using OpenDsc.Resource;

namespace DSCUniversalResources.Windows.User;

internal static class userUtils
{
    public static userSchema GetUser(string userName)
    {
        try
        {
            using var context = new PrincipalContext(ContextType.Machine);
            using var user = UserPrincipal.FindByIdentity(context, userName);

            return user == null
                ? new userSchema { userName = userName, exist = false }
                : new userSchema
                {
                    userName = userName,
                    exist = true,
                    fullName = user.DisplayName,
                    description = user.Description,
                    disabled = !user.Enabled,
                    passwordNeverExpires = user.PasswordNeverExpires,
                    passwordChangeNotAllowed = user.UserCannotChangePassword,
                    passwordChangeRequired = IsPasswordChangeRequired(user)
                };
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Failed to retrieve user '{userName}': {ex.Message}", ex);
        }
    }

    public static bool UserExists(string userName)
    {
        try
        {
            using var context = new PrincipalContext(ContextType.Machine);
            using var user = UserPrincipal.FindByIdentity(context, userName);
            return user != null;
        }
        catch
        {
            return false;
        }
    }

    public static void CreateUser(userSchema userSchema)
    {
        try
        {
            using var context = new PrincipalContext(ContextType.Machine);
            using var user = new UserPrincipal(context);

            user.SamAccountName = userSchema.userName;
            user.Name = userSchema.userName;

            if (!string.IsNullOrEmpty(userSchema.fullName))
                user.DisplayName = userSchema.fullName;

            if (!string.IsNullOrEmpty(userSchema.description))
                user.Description = userSchema.description;

            if (!string.IsNullOrEmpty(userSchema.password))
                user.SetPassword(userSchema.password);

            if (userSchema.disabled.HasValue)
                user.Enabled = !userSchema.disabled.Value;

            if (userSchema.passwordNeverExpires.HasValue)
                user.PasswordNeverExpires = userSchema.passwordNeverExpires.Value;

            if (userSchema.passwordChangeNotAllowed.HasValue)
                user.UserCannotChangePassword = userSchema.passwordChangeNotAllowed.Value;

            user.Save();

            // Handle password change required after creation
            if (userSchema.passwordChangeRequired == true)
            {
                user.ExpirePasswordNow();
            }
        }
        catch (Exception ex)
        {
            Logger.WriteError($"Failed to create user '{userSchema.userName}': {ex.Message}");
            Environment.Exit(4);
        }
    }

    public static void UpdateUser(userSchema userSchema)
    {
        try
        {
            using var context = new PrincipalContext(ContextType.Machine);
            using var user = UserPrincipal.FindByIdentity(context, userSchema.userName);

            if (user == null)
                throw new InvalidOperationException($"User '{userSchema.userName}' not found");

            // Update properties only if they're specified
            if (!string.IsNullOrEmpty(userSchema.fullName))
                user.DisplayName = userSchema.fullName;

            if (!string.IsNullOrEmpty(userSchema.description))
                user.Description = userSchema.description;

            if (!string.IsNullOrEmpty(userSchema.password))
                user.SetPassword(userSchema.password);

            if (userSchema.disabled.HasValue)
                user.Enabled = !userSchema.disabled.Value;

            if (userSchema.passwordNeverExpires.HasValue)
                user.PasswordNeverExpires = userSchema.passwordNeverExpires.Value;

            if (userSchema.passwordChangeNotAllowed.HasValue)
                user.UserCannotChangePassword = userSchema.passwordChangeNotAllowed.Value;

            user.Save();

            // Handle password change required
            if (userSchema.passwordChangeRequired == true)
            {
                user.ExpirePasswordNow();
            }
        }
        catch (Exception ex)
        {
            Logger.WriteError($"Failed to update user '{userSchema.userName}': {ex.Message}");
            Environment.Exit(4);
        }
    }

    public static void DeleteUser(string userName)
    {
        try
        {
            using var context = new PrincipalContext(ContextType.Machine);
            using var user = UserPrincipal.FindByIdentity(context, userName);

            if (user == null)
                throw new InvalidOperationException($"User '{userName}' not found");

            user.Delete();
        }
        catch (Exception ex)
        {
            Logger.WriteError($"Failed to delete user '{userName}': {ex.Message}");
            Environment.Exit(4);
        }
    }

    private static bool IsPasswordChangeRequired(UserPrincipal user)
    {
        try
        {
            // Check if password has expired or must be changed at next logon
            return user.LastPasswordSet == null || user.LastPasswordSet == DateTime.MinValue;
        }
        catch
        {
            return false;
        }
    }
}