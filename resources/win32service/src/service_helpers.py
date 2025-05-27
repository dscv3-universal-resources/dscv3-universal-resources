import json
import win32service
import datetime 
import inspect
import sys
from sys import exit
from localization import _

def validate_json_input(inputs, *required_properties):
    """
    Validates that the input string is valid JSON and optionally checks for required properties.
    """
    try:
        input_data = json.loads(inputs)
        log_message("DEBUG", _("jsonParseSuccess", input_data), "input validation")
    except json.JSONDecodeError:
        log_message("ERROR", _("jsonParseError"), "input validation")
        exit(4)

    if not isinstance(input_data, dict):
        log_message("ERROR", _("jsonNotObject"), "input validation")
        exit(4)

    flat_required = []
    for prop in required_properties:
        if isinstance(prop, (list, tuple)):
            flat_required.extend([p for p in prop if isinstance(p, str)])
        elif isinstance(prop, str):
            flat_required.append(prop)
    
    log_message(
        "DEBUG", _("jsonCheckProperties", flat_required), "input validation"
    )
    
    missing_properties = [prop for prop in flat_required if prop not in input_data]
    if missing_properties:
        log_message(
            "ERROR", 
            _("jsonMissingProps", ", ".join(missing_properties)), 
            "input validation"
        )
        exit(1)

    return input_data

def get_start_type_description(start_type):
    """
    Converts between start type code and description. If an integer is provided, returns the name.
    If a name is provided, returns the integer. Handles Unknown or None values.

    Args:
        start_type (int, str, or None): The start type code or name.

    Returns:
        str or int: The description of the start type or the integer value.
    """
    start_type_mapping = {
        2: "Automatic",
        3: "Manual",
        4: "Disabled",
    }

    # Handle None or Unknown values
    if start_type is None or start_type == "Unknown":
        return (
            win32service.SERVICE_NO_CHANGE
            if isinstance(start_type, str)
            else "Disabled"
        )

    if isinstance(start_type, int):
        return start_type_mapping.get(start_type, "Disabled")
    elif isinstance(start_type, str):
        reverse_mapping = {v: k for k, v in start_type_mapping.items()}
        return reverse_mapping.get(start_type, win32service.SERVICE_NO_CHANGE)
    else:
        return "Invalid input"

def get_service_status(scm, service_name):
    service = win32service.OpenService(
        scm, service_name, win32service.SERVICE_QUERY_STATUS
    )
    try:
        service_status = get_service_state_description(
            win32service.QueryServiceStatus(service)[1]
        )
        win32service.CloseServiceHandle(service)
        return service_status
    except Exception as e:
        return json.dumps({"error": str(e)}, indent=4)
    
def get_service_state_description(state_code):
    state_mapping = {
        1: "stopped",
        2: "start_pending",
        3: "stop_pending",
        4: "running",
        5: "continue_pending",
        6: "pause_pending",
        7: "paused",
    }
    return state_mapping.get(state_code, "unknown")

def validate_credentials(username, password):
    if (username and not password) or (password and not username):
        exit(2)
    return username or None, password or None

def log_message(level, message, target):
    """
    Logs a message in JSON format.

    Args:
        level (str): The log level (e.g., "DEBUG", "INFO", "ERROR").
        message (str): The log message.
        target (str): The target or context of the log.

    Returns:
        str: JSON string representing the log message.
    """
    # Validate log level
    valid_levels = ["INFO", "DEBUG", "WARN", "ERROR", "TRACE"]
    if level not in valid_levels:
        level = "INFO"  # Default to INFO if invalid level provided
        
    timestamp = datetime.datetime.now().isoformat() + "Z"
    caller_frame = inspect.currentframe().f_back
    line_number = caller_frame.f_lineno if caller_frame else "Unknown"
    log_entry = {
        "timestamp": timestamp,
        "level": level,
        "fields": {"message": message},
        "target": target,
        "line_number": line_number,
    }
    print(json.dumps(log_entry, separators=(",", ":")), file=sys.stderr)

def get_service_schema():
    """
    Returns the JSON schema for the properties that can be set in the set_service function.

    Returns:
        str: JSON schema as a string.
    """
    schema = {
        "$schema": "http://json-schema.org/draft-07/schema#",
        "title": "win32service",
        "type": "object",
        "required": ["name"],
        "properties": {
            "_exist": {
                "description": "Indicates whether the service already exists.",
                "type": ["boolean", "null"],
            },
            "name": {
                "description": "The name of the Windows service.",
                "type": "string",
            },
            "path": {
                "description": "The executable path of the Windows service.",
                "type": "string",
            },
            "startupType": {
                "description": "The startup type of the Windows service.",
                "type": "string",
                "enum": ["Automatic", "Manual", "Disabled"],
            },
            "displayName": {
                "description": "The display name of the Windows service.",
                "type": ["string", "null"],
            },
            "description": {
                "description": "The description of the Windows service.",
                "type": ["string", "null"],
            },
            "dependencies": {
                "description": "The dependencies of the Windows service.",
                "type": ["array", "null"],
            },
            "username": {
                "description": "The username for the Windows service logon.",
                "type": ["string", "null"],
            },
            "password": {
                "description": "The password for the Windows service logon.",
                "type": ["string", "null"],
            },
        },
        "additionalProperties": False,
    }
    return json.dumps(schema, separators=(",", ":"))

def record_changes(current_service_info, desired_values, properties_to_check):
    """
    Compares current service properties with desired values and records differences.

    Args:
        current_service_info (dict): Current properties of the service.
        desired_values (dict): Desired properties of the service.
        properties_to_check (list): List of properties to compare.

    Returns:
        dict: A dictionary of changes with keys as property names and values as dictionaries
              containing 'current' and 'desired' values.
    """
    changes = {}

    for key in properties_to_check:
        # Special handling for username/logon mapping
        if key == "logon" and "username" in desired_values and desired_values.get("username") is not None:
            current_value = current_service_info.get(key)
            desired_value = desired_values.get("username")
            if current_value != desired_value:
                changes[key] = {"current": current_value, "desired": desired_value}
            continue

        if key in desired_values and desired_values.get(key) is not None:
            current_value = current_service_info.get(key)
            desired_value = desired_values.get(key)
            if current_value != desired_value:
                changes[key] = {"current": current_value, "desired": desired_value}

    return changes