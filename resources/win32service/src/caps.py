import json
import win32service
from sys import exit

from service_helpers import (
    validate_json_input,
    get_start_type_description,
    get_service_status,
    validate_credentials,
    log_message,
    record_changes,
)

from localization import _


def get_service(inputs):
    """
    Retrieves information about a Windows service and returns it as JSON.

    Args:
        inputs (str): JSON string containing the input data. Must include a property 'name'.

    Returns:
        str: JSON string containing service information.
    """
    # Parse and validate the input JSON
    json_str = validate_json_input(inputs, str, "name")
    service_name = json_str["name"]

    try:
        log_message("DEBUG", _("serviceGetRetrieving", service_name), "service")
        scm = win32service.OpenSCManager(None, None, win32service.SC_MANAGER_ALL_ACCESS)

        try:
            service = win32service.OpenService(
                scm, service_name, win32service.SERVICE_QUERY_CONFIG
            )
            config = win32service.QueryServiceConfig(service)
            description = win32service.QueryServiceConfig2(
                service, win32service.SERVICE_CONFIG_DESCRIPTION
            )
            win32service.CloseServiceHandle(service)

            json_string = {
                "name": service_name,
                "path": config[3],
                "startupType": get_start_type_description(config[1]),
                "logon": config[7],
                "state": get_service_status(scm, service_name),
                "displayName": config[8],
                "description": description,
                "dependencies": config[6],
            }
        except win32service.error:
            # Service not found
            json_string = {"name": service_name, "_exist": False}

        return json.dumps(json_string)
    except Exception as e:
        log_message("ERROR", _("serviceGetStatusError", service_name, str(e)), "service")
        exit(3)


def set_service(inputs, what_if=False):
    """
    Sets the configuration for a Windows service. If the service already exists, updates its properties.

    Args:
        inputs (str): JSON string containing the input data. Must include properties like 'name', 'path', 'startupType', etc.
        what_if (bool): If True, performs a dry run without making changes.

    Returns:
        str: JSON string indicating success or failure.
    """

    json_str = validate_json_input(inputs, "name", "path")
    service_name = json_str["name"]

    if what_if:
        # Perform a dry run analysis
        return what_if_service(inputs, service_name)

    try:
        scm = win32service.OpenSCManager(None, None, win32service.SC_MANAGER_ALL_ACCESS)
        # Validate username and password
        username, password = validate_credentials(
            json_str.get("username"), json_str.get("password")
        )

        log_message(
            "DEBUG",
            _("serviceSetCreatingWithParams", json.dumps(json_str, indent=2)),
            "service",
        )

        service = win32service.CreateService(
            scm,
            json_str["name"],
            json_str.get("displayName", json_str["name"]),
            win32service.SERVICE_ALL_ACCESS,
            win32service.SERVICE_WIN32_OWN_PROCESS,
            get_start_type_description(json_str.get("startupType", "Disabled")),
            win32service.SERVICE_ERROR_NORMAL,
            json_str["path"],
            None,
            False,
            json_str.get("dependencies", []),
            username,
            password,
        )
        win32service.CloseServiceHandle(service)
        log_message("INFO", _("serviceSetCreatedSuccess", json_str["name"]), "service")
        exit(0)
    except win32service.error as e:
        if e.winerror == 1073:  # 1073 is ERROR_SERVICE_EXIST
            log_message(
                "INFO", _("serviceSetExistsUpdating", json_str["name"]), "service"
            )
            service = win32service.OpenService(
                scm, json_str["name"], win32service.SERVICE_CHANGE_CONFIG
            )
            win32service.ChangeServiceConfig(
                service,
                win32service.SERVICE_NO_CHANGE,
                get_start_type_description(json_str.get("startupType", "Disabled")),
                win32service.SERVICE_NO_CHANGE,
                json_str["path"],
                None,
                0,
                json_str.get("dependencies", []),
                None,
                None,
                json_str.get("displayName", json_str["name"]),
            )
            win32service.CloseServiceHandle(service)
            log_message(
                "DEBUG",
                _("serviceSetUpdatedSuccess", json_str["name"]),
                "service",
            )
            exit(0)
        else:
            log_message("ERROR", _("serviceSetUpdateError", str(e.args)), "service")
            exit(3)


def delete_service(inputs, what_if=False):
    """
    Deletes a Windows service.

    Args:
        inputs (str): JSON string containing the input data. Must include a property 'name'.
        what_if (bool): If True, performs a dry run without making changes.

    Returns:
        str: JSON string indicating success or failure.
    """
    json_str = validate_json_input(inputs, "name")
    service_name = json_str["name"]

    try:
        scm = win32service.OpenSCManager(None, None, win32service.SC_MANAGER_ALL_ACCESS)
        service = win32service.OpenService(
            scm, service_name, win32service.SERVICE_ALL_ACCESS
        )

        if what_if:
            print(
                json.dumps(
                    {
                        "name": service_name,
                        "_metadata": {
                            "whatIf": [
                                f"Service '{service_name}' exists and will be deleted."
                            ]
                        },
                    }
                )
            )
            win32service.CloseServiceHandle(service)
            return

        # Stop the service if it is running
        try:
            log_message(
                "DEBUG",
                _("serviceDeleteStopping", service_name),
                "service",
            )
            stateCode = win32service.SERVICE_CONTROL_STOP
            win32service.ControlService(service, stateCode)
        except win32service.error as e:
            if e.winerror == 1062:
                log_message(
                    "DEBUG",
                    _("serviceDeleteAlreadyStopped", service_name),
                    "service",
                )
            else:
                log_message(
                    "ERROR",
                    _("serviceDeleteStopError", service_name, str(e.args)),
                    "service",
                )
                exit(3)

        log_message(
            "DEBUG",
            _("serviceDeleteDeleting", service_name),
            "service",
        )
        win32service.DeleteService(service)
        win32service.CloseServiceHandle(service)

        log_message("INFO", _("serviceDeleteDeletedSuccess", service_name), "service")
        exit(0)
    except win32service.error as e:
        if what_if:
            print(
                json.dumps(
                    {
                        "name": service_name,
                        "_metadata": {
                            "whatIf": [
                                f"Service '{service_name}' does not exist or cannot be accessed."
                            ]
                        },
                    }
                )
            )
            return
        log_message(
            "ERROR", _("serviceDeleteError", service_name, str(e.args)), "service"
        )
        exit(3)


def export_services():
    """
    Retrieves a list of all services on the system and returns them as JSON.

    Returns:
        str: JSON string containing information about all services.
    """
    try:
        log_message("DEBUG", _("serviceExportRetrieving"), "service")
        services = {"services": []}

        # Open Service Control Manager
        scm = win32service.OpenSCManager(None, None, win32service.SC_MANAGER_ALL_ACCESS)

        # Enumerate Service Control Manager DB
        statuses = win32service.EnumServicesStatus(
            scm, win32service.SERVICE_WIN32, win32service.SERVICE_STATE_ALL
        )

        for service_name, display_name, service_info in statuses:
            try:
                service = win32service.OpenService(
                    scm, service_name, win32service.SERVICE_QUERY_CONFIG
                )
                config = win32service.QueryServiceConfig(service)
                description = win32service.QueryServiceConfig2(
                    service, win32service.SERVICE_CONFIG_DESCRIPTION
                )
                win32service.CloseServiceHandle(service)

                service_info = {
                    "name": service_name,
                    "path": config[3],
                    "startupType": get_start_type_description(config[1]),
                    "logon": config[7],
                    "state": get_service_status(scm, service_name),
                    "displayName": display_name,
                    "description": description,
                    "dependencies": config[6],
                }
                services["services"].append(service_info)
            except win32service.error as e:
                log_message(
                    "WARNING",
                    _("serviceExportDetailError", service_name, str(e)),
                    "service",
                )
        return json.dumps(services)
    except Exception as e:
        log_message("ERROR", _("serviceExportError", str(e)), "service")
        exit(3)


def what_if_service(inputs, service_name):
    """
    Performs a what-if analysis on a service operation without making changes.

    Args:
    inputs (str): JSON string containing the input data.
    service_name (str): Name of the service to analyze.

    Returns:
    None: Prints JSON result and returns.
    """
    try:
        current_service_info = json.loads(get_service(inputs))
    except SystemExit as e:
        if e.code == 3:
            print(
                json.dumps(
                    {
                        "name": service_name,
                        "_metadata": {
                            "whatIf": [
                                f"Access denied while querying service '{service_name}'"
                            ]
                        },
                    }
                )
            )
            return
    except Exception as e:
        print(
            json.dumps(
                {
                    "name": service_name,
                    "_metadata": {
                        "whatIf": [f"Error getting current service info: {str(e)}"]
                    },
                }
            )
        )
        return
    if (
        not current_service_info.get("name")
        or current_service_info.get("_exist") is False
    ):
        # Service does not exist
        print(
            json.dumps(
                {
                    "name": service_name,
                    "_metadata": {
                        "whatIf": [
                            f"Service '{service_name}' does not exist, will be created"
                        ]
                    },
                }
            )
        )
        return

    # Service exists, compare properties
    properties_to_check = [
        "path",
        "startupType",
        "displayName",
        "description",
        "dependencies",
        "logon",
    ]

    loadedJson = json.loads(inputs)

    # Use the helper function to record changes
    changes = record_changes(current_service_info, loadedJson, properties_to_check)

    # Prepare the result dictionary with all required properties
    result = {"name": service_name, "path": current_service_info.get("path")}

    # Add the desired values for all changing properties
    if changes:
        for prop, change_info in changes.items():
            result[prop] = change_info["desired"]

        # Return the result as plain JSON
        print(json.dumps(result))
        return

    else:
        # No changes needed, return the current service info
        if "_exist" in current_service_info:
            del current_service_info["_exist"]
        print(json.dumps(current_service_info))
        return
