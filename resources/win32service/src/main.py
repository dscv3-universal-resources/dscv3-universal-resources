from caps import get_service, set_service, delete_service, export_services
from args import create_parser
from service_helpers import log_message, get_service_schema
from localization import _

if __name__ == "__main__":
    parser = create_parser()

    args = parser.parse_args()

    if args.config == "config":
        if args.action == "get":
            log_message(
                "INFO", _("logGetService", args.input), "service"
            )
            print(get_service(args.input))
        elif args.action == "set":
            log_message(
                "INFO", _("logSetService", args.input), "service"
            )
            set_service(args.input, what_if=args.what_if)
        elif args.action == "delete":
            log_message(
                "INFO", _("logDeleteService", args.input), "service"
            )
            delete_service(args.input, what_if=args.what_if)
        elif args.action == "export":
            log_message(
                "INFO", _("logExportServices"), "service"
            )
            print(export_services())
    elif args.config == "schema":
        schema = get_service_schema()
        print(str(schema))