using System.DirectoryServices.AccountManagement;

namespace DSCUniversalResources.Windows.User;

internal static class userUtils
{
    public static userSchema GetUser(string userName)
    {
        try
        {
            using var context = new PrincipalContext(ContextType.Machine);
            using var user = UserPrincipal.FindByIdentity(context, userName);

            if (user == null)
            {
                return new userSchema()
                {
                    UserName = userName,
                    Exist = false
                };
            }

            return new userSchema()
            {
                UserName = userName,
                Exist = true,
                FullName = user.DisplayName,
                Description = user.Description,
                Disabled = !user.Enabled,
                PasswordNeverExpires = user.PasswordNeverExpires,
                PasswordChangeNotAllowed = user.UserCannotChangePassword,
                PasswordChangeRequired = IsPasswordChangeRequired(user)
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

            user.SamAccountName = userSchema.UserName;
            user.Name = userSchema.UserName;

            if (!string.IsNullOrEmpty(userSchema.FullName))
                user.DisplayName = userSchema.FullName;

            if (!string.IsNullOrEmpty(userSchema.Description))
                user.Description = userSchema.Description;

            if (!string.IsNullOrEmpty(userSchema.Password))
                user.SetPassword(userSchema.Password);

            if (userSchema.Disabled.HasValue)
                user.Enabled = !userSchema.Disabled.Value;

            if (userSchema.PasswordNeverExpires.HasValue)
                user.PasswordNeverExpires = userSchema.PasswordNeverExpires.Value;

            if (userSchema.PasswordChangeNotAllowed.HasValue)
                user.UserCannotChangePassword = userSchema.PasswordChangeNotAllowed.Value;

            user.Save();

            // Handle password change required after creation
            if (userSchema.PasswordChangeRequired == true)
            {
                user.ExpirePasswordNow();
            }
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Failed to create user '{userSchema.UserName}': {ex.Message}", ex);
        }
    }

    public static void UpdateUser(userSchema userSchema)
    {
        try
        {
            using var context = new PrincipalContext(ContextType.Machine);
            using var user = UserPrincipal.FindByIdentity(context, userSchema.UserName);

            if (user == null)
                throw new InvalidOperationException($"User '{userSchema.UserName}' not found");

            // Update properties only if they're specified
            if (!string.IsNullOrEmpty(userSchema.FullName))
                user.DisplayName = userSchema.FullName;

            if (!string.IsNullOrEmpty(userSchema.Description))
                user.Description = userSchema.Description;

            if (!string.IsNullOrEmpty(userSchema.Password))
                user.SetPassword(userSchema.Password);

            if (userSchema.Disabled.HasValue)
                user.Enabled = !userSchema.Disabled.Value;

            if (userSchema.PasswordNeverExpires.HasValue)
                user.PasswordNeverExpires = userSchema.PasswordNeverExpires.Value;

            if (userSchema.PasswordChangeNotAllowed.HasValue)
                user.UserCannotChangePassword = userSchema.PasswordChangeNotAllowed.Value;

            user.Save();

            // Handle password change required
            if (userSchema.PasswordChangeRequired == true)
            {
                user.ExpirePasswordNow();
            }
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Failed to update user '{userSchema.UserName}': {ex.Message}", ex);
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
            throw new InvalidOperationException($"Failed to delete user '{userName}': {ex.Message}", ex);
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