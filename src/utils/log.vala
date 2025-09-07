/*
 * Key Maker - Structured Logging Utilities
 * 
 * Centralized logging with consistent categorization and structured output.
 */

namespace KeyMaker {
    public class Log {
        public enum Level {
            DEBUG,
            INFO,
            WARNING,
            ERROR
        }

        private static string get_level_string(Level level) {
            switch (level) {
                case Level.DEBUG:
                    return "DEBUG";
                case Level.INFO:
                    return "INFO";
                case Level.WARNING:
                    return "WARNING";
                case Level.ERROR:
                    return "ERROR";
                default:
                    return "UNKNOWN";
            }
        }

        private static void log_message(Level level, string category, string format, va_list args) {
            var message = format.vprintf(args);
            var timestamp = new DateTime.now_local().format("%Y-%m-%d %H:%M:%S");
            var level_str = get_level_string(level);
            
            var full_message = "[%s] [%s] [%s] %s".printf(timestamp, level_str, category, message);
            
            // Use GLib structured logging if available, otherwise fallback to print
            switch (level) {
                case Level.DEBUG:
                    GLib.debug("%s", full_message);
                    break;
                case Level.INFO:
                    GLib.info("%s", full_message);
                    break;  
                case Level.WARNING:
                    GLib.warning("%s", full_message);
                    break;
                case Level.ERROR:
                    GLib.critical("%s", full_message);
                    break;
            }
        }

        // Debug logging
        public static void debug(string category, string format, ...) {
            var args = va_list();
            log_message(Level.DEBUG, category, format, args);
        }

        // Info logging  
        public static void info(string category, string format, ...) {
            var args = va_list();
            log_message(Level.INFO, category, format, args);
        }

        // Warning logging
        public static void warning(string category, string format, ...) {
            var args = va_list();
            log_message(Level.WARNING, category, format, args);
        }

        // Error logging
        public static void error(string category, string format, ...) {
            var args = va_list();
            log_message(Level.ERROR, category, format, args);
        }

        // Category constants for consistent usage
        public class Categories {
            public const string VAULT = "VAULT";
            public const string SSH_OPS = "SSH_OPS";
            public const string ROTATION = "ROTATION";
            public const string TUNNELING = "TUNNELING";
            public const string DIAGNOSTICS = "DIAGNOSTICS";
            public const string AGENT = "AGENT";
            public const string CONFIG = "CONFIG";
            public const string UI = "UI";
            public const string SCANNER = "SCANNER";
        }
    }
}