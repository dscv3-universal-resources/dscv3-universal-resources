import gettext
import os
import locale
import sys

def setup_localization():
    """
    Sets up localization for the application.
    Returns the translation function '_'.
    """
    # Handle different runtime environments
    if getattr(sys, 'frozen', False) and hasattr(sys, '_MEIPASS'):
        # Running from PyInstaller bundle
        base_path = sys._MEIPASS
        locale_dir = os.path.join(base_path, 'locales')
    else:
        # Running in development mode
        src_dir = os.path.dirname(__file__)
        project_root = os.path.dirname(src_dir)  # Go up one level from src
        locale_dir = os.path.join(project_root, 'locales')
    
    
    current_lang_code = None

    try:
        env_lang = os.environ.get('LANG')
        if env_lang:
            # Strip off any encoding part (e.g., .utf-8, .iso8859-1)
            env_lang = env_lang.split('.')[0]
            # Normalize: lowercase, replace underscore with hyphen
            normalized_lang = env_lang.lower().replace('_', '-')
            current_lang_code = normalized_lang
        else:
            loc = locale.getdefaultlocale()
            if loc and loc[0]:
                normalized_loc = loc[0].lower().replace('_', '-')
                current_lang_code = normalized_loc.split('.')[0]
    except Exception:
        pass

    if not current_lang_code:
        current_lang_code = 'en-us'  # Default to English (US)
    
    mo_filename = f"{current_lang_code}.mo"
    mo_file_path = os.path.join(locale_dir, mo_filename)

    if os.path.exists(mo_file_path):
        try:
            with open(mo_file_path, 'rb') as fp:
                lang_translation = gettext.GNUTranslations(fp)
            
            # Create the translation lookup function
            def translate(message_id, *args):
                """
                Get a message by its ID and format it with the given arguments.
                
                Args:
                    message_id: The camelCase ID of the message
                    *args: Format arguments for the message
                
                Returns:
                    str: The translated and formatted message
                """
                # Get the translated text
                text = lang_translation.gettext(message_id)
                
                # Format if arguments are provided
                if args:
                    try:
                        text = text.format(*args)
                    except IndexError:
                        pass
                
                return text
            
            return translate
            
        except Exception:
            pass
    
    # Fallback: return a function that just returns the message ID as-is
    def identity_translate(message_id, *args):
        return message_id if not args else message_id.format(*args)
    
    return identity_translate

_ = setup_localization()
