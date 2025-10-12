/*
 * Key Maker - Settings Utilities
 *
 * Centralized settings access with consistent schema handling.
 */

namespace KeyMaker {
    public class SettingsManager {
        private static GLib.Settings? _app_settings;
        private static GLib.Settings? _tunneling_settings;
        
        // App settings instance (main schema)
        public static GLib.Settings app {
            get {
                if (_app_settings == null) {
                    _app_settings = new GLib.Settings(Config.APP_ID);
                }
                return _app_settings;
            }
        }
        
        // Tunneling settings instance (separate schema)
        public static GLib.Settings tunneling {
            get {
                if (_tunneling_settings == null) {
                    _tunneling_settings = new GLib.Settings(@"$(Config.APP_ID).tunneling");
                }
                return _tunneling_settings;
            }
        }
        
        // Common settings keys for the main schema
        public class Keys {
            // Window state
            public const string WINDOW_WIDTH = "window-width";
            public const string WINDOW_HEIGHT = "window-height";
            public const string WINDOW_MAXIMIZED = "window-maximized";
            
            // UI preferences
            public const string THEME_PREFERENCE = "theme-preference";
            public const string SHOW_WELCOME = "show-welcome";
            public const string CHECK_FOR_UPDATES = "check-for-updates";
            
            // Security settings
            public const string AUTO_LOCK_TIMEOUT = "auto-lock-timeout";
            public const string REQUIRE_PASSPHRASE_CONFIRMATION = "require-passphrase-confirmation";
            
            // SSH Agent settings
            public const string AUTO_ADD_KEYS_TO_AGENT = "auto-add-keys-to-agent";
            public const string AGENT_LIFETIME = "agent-lifetime";
            
            // Diagnostics settings
            public const string AUTO_RUN_DIAGNOSTICS = "auto-run-diagnostics";
            public const string DIAGNOSTICS_RETENTION_DAYS = "diagnostics-retention-days";
            
            // Key management
            public const string DEFAULT_KEY_TYPE = "default-key-type";
            public const string DEFAULT_KEY_SIZE = "default-key-size";
            public const string BACKUP_DIRECTORY = "backup-directory";
            
            // Emergency vault
            public const string VAULT_AUTO_BACKUP = "vault-auto-backup";
            public const string VAULT_BACKUP_INTERVAL = "vault-backup-interval";
        }
        
        // Tunneling settings keys
        public class TunnelingKeys {
            public const string SAVED_TUNNELS = "configurations";
            public const string AUTO_START_TUNNELS = "auto-start-tunnels";
            public const string TUNNEL_TIMEOUT = "tunnel-timeout";
            public const string DEFAULT_SSH_PORT = "default-ssh-port";
        }
        
        // Window state properties
        public static int window_width {
            get { return app.get_int("window-width"); }
            set { app.set_int("window-width", value); }
        }

        public static int window_height {
            get { return app.get_int("window-height"); }
            set { app.set_int("window-height", value); }
        }

        public static bool window_maximized {
            get { return app.get_boolean("window-maximized"); }
            set { app.set_boolean("window-maximized", value); }
        }

        // Key generation default properties
        public static owned string default_key_type {
            owned get { return app.get_string("default-key-type"); }
            set { app.set_string("default-key-type", value); }
        }

        public static int default_rsa_bits {
            get { return app.get_int("default-rsa-bits"); }
            set { app.set_int("default-rsa-bits", value); }
        }

        public static int default_ecdsa_curve {
            get { return app.get_int("default-ecdsa-curve"); }
            set { app.set_int("default-ecdsa-curve", value); }
        }

        public static owned string default_comment {
            owned get { return app.get_string("default-comment"); }
            set { app.set_string("default-comment", value); }
        }

        public static bool use_passphrase_by_default {
            get { return app.get_boolean("use-passphrase-by-default"); }
            set { app.set_boolean("use-passphrase-by-default", value); }
        }

        // UI preference properties
        public static int auto_refresh_interval {
            get { return app.get_int("auto-refresh-interval"); }
            set { app.set_int("auto-refresh-interval", value); }
        }

        public static bool show_fingerprints {
            get { return app.get_boolean("show-fingerprints"); }
            set { app.set_boolean("show-fingerprints", value); }
        }

        public static bool confirm_deletions {
            get { return app.get_boolean("confirm-deletions"); }
            set { app.set_boolean("confirm-deletions", value); }
        }

        public static owned string theme {
            owned get { return app.get_string("theme"); }
            set { app.set_string("theme", value); }
        }

        public static owned string preferred_terminal {
            owned get { return app.get_string("preferred-terminal"); }
            set { app.set_string("preferred-terminal", value); }
        }

        public static owned string last_version_shown {
            owned get { return app.get_string("last-version-shown"); }
            set { app.set_string("last-version-shown", value); }
        }

        // Diagnostics settings properties
        public static bool auto_run_diagnostics {
            get { return app.get_boolean("auto-run-diagnostics"); }
            set { app.set_boolean("auto-run-diagnostics", value); }
        }

        public static int diagnostics_retention_days {
            get { return app.get_int("diagnostics-retention-days"); }
            set { app.set_int("diagnostics-retention-days", value); }
        }

        // Convenience methods for common operations
        public static void save_window_state(int width, int height, bool maximized) {
            window_width = width;
            window_height = height;
            window_maximized = maximized;
        }

        public static void get_window_state(out int width, out int height, out bool maximized) {
            width = window_width;
            height = window_height;
            maximized = window_maximized;
        }
        
        // Complex variant type convenience methods
        public static Variant get_rotation_plans() {
            return app.get_value("rotation-plans");
        }

        public static void set_rotation_plans(Variant plans) {
            app.set_value("rotation-plans", plans);
        }

        public static Variant get_key_service_mappings() {
            return app.get_value("key-service-mappings");
        }

        public static void set_key_service_mappings(Variant mappings) {
            app.set_value("key-service-mappings", mappings);
        }

        public static Variant get_tunnel_configurations() {
            return app.get_value("tunnel-configurations");
        }

        public static void set_tunnel_configurations(Variant configs) {
            app.set_value("tunnel-configurations", configs);
        }
        
        // Tunneling convenience methods
        public static string[] get_saved_tunnels() {
            return tunneling.get_strv(TunnelingKeys.SAVED_TUNNELS);
        }
        
        public static void set_saved_tunnels(string[] tunnels) {
            tunneling.set_strv(TunnelingKeys.SAVED_TUNNELS, tunnels);
        }
        
        public static bool get_auto_start_tunnels() {
            return tunneling.get_boolean(TunnelingKeys.AUTO_START_TUNNELS);
        }
        
        public static void set_auto_start_tunnels(bool enabled) {
            tunneling.set_boolean(TunnelingKeys.AUTO_START_TUNNELS, enabled);
        }

        // Utility methods
        public static void reset_to_defaults() {
            KeyMaker.Log.info(KeyMaker.Log.Categories.CONFIG, "Resetting all settings to defaults");
            
            // Get all keys from main schema and reset them
            foreach (var key in app.settings_schema.list_keys()) {
                app.reset(key);
            }
            
            // Get all keys from tunneling schema and reset them  
            foreach (var key in tunneling.settings_schema.list_keys()) {
                tunneling.reset(key);
            }
        }
        
        public static void apply_settings() {
            // Force any pending settings to be written
            GLib.Settings.sync();
        }
    }
}