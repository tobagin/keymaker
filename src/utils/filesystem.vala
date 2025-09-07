/*
 * Key Maker - Filesystem Utilities
 *
 * Central helpers for SSH directory paths and secure permissions.
 */

namespace KeyMaker {
    public class Filesystem {
        public const uint PERM_DIR_PRIVATE = 0x1C0;  // 0700
        public const uint PERM_FILE_PRIVATE = 0x180; // 0600
        public const uint PERM_FILE_PUBLIC = 0x1A4;  // 0644

        public static File ssh_dir () {
            return File.new_for_path (Path.build_filename (Environment.get_home_dir (), ".ssh"));
        }

        public static void ensure_ssh_dir () throws Error {
            var dir = ssh_dir ();
            ensure_directory_with_perms (dir);
        }
        
        public static void ensure_directory_with_perms (File dir) throws Error {
            if (!dir.query_exists ()) {
                dir.make_directory_with_parents ();
            }
            // Always enforce permission
            Posix.chmod (dir.get_path (), PERM_DIR_PRIVATE);
        }

        public static void chmod_private (File file) {
            Posix.chmod (file.get_path (), PERM_FILE_PRIVATE);
        }

        public static void chmod_public (File file) {
            Posix.chmod (file.get_path (), PERM_FILE_PUBLIC);
        }

        // Sanitize an arbitrary display name into a safe base filename
        public static string safe_base_filename (string? proposed, string fallback = "restored_key", int max_len = 100) {
            var input = (proposed ?? "").strip ();
            if (input == "" || input == "." || input == "..") {
                input = fallback;
            }

            var sb = new StringBuilder ();
            for (int i = 0; i < input.length; i++) {
                unichar ch = input.get_char (i);
                if (ch.isalnum () || ch == '.' || ch == '-' || ch == '_') {
                    sb.append_unichar (ch);
                } else {
                    sb.append ("_");
                }
            }

            var result = sb.str;
            // Avoid leading '.' or '-'
            while (result.length > 0 && (result.has_prefix (".") || result.has_prefix ("-"))) {
                result = result.substring (1);
            }
            if (result == "") {
                result = fallback;
            }
            if (result.length > max_len) {
                result = result.substring (0, max_len);
            }
            return result;
        }
    }
}

