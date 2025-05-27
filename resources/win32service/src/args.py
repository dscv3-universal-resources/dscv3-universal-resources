import argparse

from localization import _


def create_parser():
    """
    Create a parser for managing Windows services.

    Returns:
        argparse.ArgumentParser: The argument parser for the script.
    """
    parser = argparse.ArgumentParser(description=_("about"))
    subparsers = parser.add_subparsers(dest="config", required=True)

    # Create config subparser
    config_parser = subparsers.add_parser("config", help=_("configAbout"))
    config_subparsers = config_parser.add_subparsers(dest="action", required=True)

    # Define common arguments
    def add_common_args(parser, include_what_if=False):
        parser.add_argument("--input", "-i", type=str, required=True, help=_("input"))
        if include_what_if:
            parser.add_argument("--what-if", "-w", action="store_true", help=_("whatIf"))

    # Define all config actions with their required arguments
    config_actions = {
        "get": {"help": _("configAboutGet"), "what_if": False},
        "set": {"help": _("configAboutSet"), "what_if": True},
        "delete": {"help": _("configAboutDelete"), "what_if": True},
        "export": {"help": _("configAboutExport"), "what_if": False, "no_input": True},
    }

    # Create parsers for each config action
    for action, options in config_actions.items():
        action_parser = config_subparsers.add_parser(action, help=options["help"])
        if not options.get("no_input", False):
            add_common_args(action_parser, options["what_if"])

    # Add schema command
    subparsers.add_parser("schema", help=_("schemaAbout"))

    return parser