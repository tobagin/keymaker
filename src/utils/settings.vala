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
            public const string SAVED_TUNNELS = "saved-tunnels";
            public const string AUTO_START_TUNNELS = "auto-start-tunnels";
            public const string TUNNEL_TIMEOUT = "tunnel-timeout";
            public const string DEFAULT_SSH_PORT = "default-ssh-port";
        }
        
        // Convenience methods for common operations
        public static void save_window_state(int width, int height, bool maximized) {
            app.set_int(Keys.WINDOW_WIDTH, width);
            app.set_int(Keys.WINDOW_HEIGHT, height);
            app.set_boolean(Keys.WINDOW_MAXIMIZED, maximized);
        }
        
        public static void get_window_state(out int width, out int height, out bool maximized) {
            width = app.get_int(Keys.WINDOW_WIDTH);
            height = app.get_int(Keys.WINDOW_HEIGHT);
            maximized = app.get_boolean(Keys.WINDOW_MAXIMIZED);
        }
        
        public static string get_theme_preference() {
            return app.get_string(Keys.THEME_PREFERENCE);
        }
        
        public static void set_theme_preference(string theme) {
            app.set_string(Keys.THEME_PREFERENCE, theme);
        }
        
        public static bool get_auto_add_keys_to_agent() {
            return app.get_boolean(Keys.AUTO_ADD_KEYS_TO_AGENT);
        }
        
        public static void set_auto_add_keys_to_agent(bool enabled) {
            app.set_boolean(Keys.AUTO_ADD_KEYS_TO_AGENT, enabled);
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
        
        // Rotation plans storage
        public static Variant get_rotation_plans() {
            return app.get_value("rotation-plans");
        }
        
        public static void set_rotation_plans(Variant plans) {
            app.set_value("rotation-plans", plans);
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