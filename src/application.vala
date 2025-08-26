/*
 * Key Maker - Main Application Class
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {
    public class Application : Adw.Application {
        
        private KeyMaker.Window? window = null;
        private Settings settings;

        public Application () {
            Object (
                application_id: Config.APP_ID,
                flags: ApplicationFlags.HANDLES_COMMAND_LINE
            );
        }

        construct {
            // Set application metadata
            Environment.set_application_name (Config.APP_NAME);
            Environment.set_prgname (Config.APP_ID);
            
            // Add command line options
            add_command_line_options ();
            
            // Connect signals
            command_line.connect (on_command_line);
            activate.connect (on_activate);
            startup.connect (on_startup);
            shutdown.connect (on_shutdown);
        }

        private void on_startup () {
            // Initialize Adwaita
            Adw.init ();
            
            
            // Setup GSettings and apply theme
            setup_settings ();
            
            // Create application actions
            create_actions ();
        }
        
        private void setup_settings () {
            // Get GSettings
            settings = new Settings (Config.APP_ID);
            
            // Apply initial theme
            var theme = settings.get_string ("theme");
            apply_theme (theme);
            
            // Listen for theme changes
            settings.changed["theme"].connect ((key) => {
                var new_theme = settings.get_string (key);
                apply_theme (new_theme);
            });
        }
        
        private void apply_theme (string theme) {
            var style_manager = Adw.StyleManager.get_default ();
            
            switch (theme) {
                case "light":
                    style_manager.color_scheme = Adw.ColorScheme.FORCE_LIGHT;
                    break;
                case "dark":
                    style_manager.color_scheme = Adw.ColorScheme.FORCE_DARK;
                    break;
                default: // "auto"
                    style_manager.color_scheme = Adw.ColorScheme.DEFAULT;
                    break;
            }
        }
        
        private bool should_show_release_notes () {
            var last_version = settings.get_string ("last-version-shown");
            var current_version = Config.VERSION;

            // Show if this is the first run (empty last version) or version has changed
            if (last_version == "" || last_version != current_version) {
                settings.set_string ("last-version-shown", current_version);
                return true;
            }
            return false;
        }

        private void on_activate () {
            // Create or present main window
            if (window == null) {
                window = new KeyMaker.Window (this);
            }
            window.present ();
            
            // Check if this is a new version and show release notes automatically
            if (should_show_release_notes ()) {
                // Small delay to ensure main window is fully presented
                Timeout.add (500, () => {
                    // Launch about dialog with automatic navigation to release notes
                    KeyMaker.AboutDialog.show_with_release_notes (window);
                    return false;
                });
            }
        }

        private int on_command_line (ApplicationCommandLine command_line) {
            var options = command_line.get_options_dict ();
            
            // Handle version option
            if (options.contains ("version")) {
                print ("%s %s\n", Config.APP_NAME, Config.VERSION);
                return 0;
            }
            
            // Handle verbose option
            if (options.contains ("verbose")) {
                // Enable verbose logging if needed
                Environment.set_variable ("G_MESSAGES_DEBUG", Config.APP_ID, true);
            }
            
            // Activate the application
            activate ();
            return 0;
        }

        private void on_shutdown () {
            // Cleanup resources
            if (window != null) {
                window.destroy ();
                window = null;
            }
        }

        private void create_actions () {
            // Quit action
            var quit_action = new SimpleAction ("quit", null);
            quit_action.activate.connect (() => quit ());
            add_action (quit_action);
            set_accels_for_action ("app.quit", {"<Control>q"});

            // About action
            var about_action = new SimpleAction ("about", null);
            about_action.activate.connect (on_about_action);
            add_action (about_action);
            set_accels_for_action ("app.about", {"F1"});

            // Preferences action
            var preferences_action = new SimpleAction ("preferences", null);
            preferences_action.activate.connect (on_preferences_action);
            add_action (preferences_action);
            set_accels_for_action ("app.preferences", {"<Control>comma"});

            // Generate key action
            var generate_action = new SimpleAction ("generate-key", null);
            generate_action.activate.connect (on_generate_key_action);
            add_action (generate_action);
            set_accels_for_action ("app.generate-key", {"<Control>n"});

            // Refresh action
            var refresh_action = new SimpleAction ("refresh", null);
            refresh_action.activate.connect (on_refresh_action);
            add_action (refresh_action);
            set_accels_for_action ("app.refresh", {"<Control>r", "F5"});

            // Help action
            var help_action = new SimpleAction ("help", null);
            help_action.activate.connect (on_help_action);
            add_action (help_action);

            // Shortcuts action  
            var shortcuts_action = new SimpleAction ("shortcuts", null);
            shortcuts_action.activate.connect (on_shortcuts_action);
            add_action (shortcuts_action);
            set_accels_for_action ("app.shortcuts", {"<Control>question"});
        }

        private void on_about_action () {
            KeyMaker.AboutDialog.show (window);
        }

        private void on_preferences_action () {
            if (window != null) {
                var dialog = new KeyMaker.PreferencesDialog (window);
                dialog.present (window);
            }
        }

        private void on_generate_key_action () {
            if (window != null) {
                window.on_generate_key_action ();
            }
        }

        private void on_refresh_action () {
            if (window != null) {
                window.on_refresh_action ();
            }
        }

        private void on_help_action () {
            if (window != null) {
                window.on_help_action ();
            }
        }

        private void on_shortcuts_action () {
            KeyMaker.ShortcutsDialog.show (window);
        }
        
        private void add_command_line_options () {
            add_main_option ("version", 0, OptionFlags.NONE, OptionArg.NONE,
                           _("Show version information"), null);
            add_main_option ("verbose", 'v', OptionFlags.NONE, OptionArg.NONE,
                           _("Enable verbose logging"), null);
        }
    }
}