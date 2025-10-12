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
        
        public KeyMaker.Window? window = null;

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
            
            // Optional: allow disabling forwarded SSH agent inside Flatpak to avoid
            // sandbox socket issues (e.g. "Connection reset by peer" from ssh-auth).
            // Enable by launching with KEYMAKER_IGNORE_SSH_AGENT=1
            var ignore_agent = Environment.get_variable ("KEYMAKER_IGNORE_SSH_AGENT");
            if (ignore_agent != null && ignore_agent.strip () == "1") {
                debug ("Application: ignoring SSH agent per KEYMAKER_IGNORE_SSH_AGENT=1");
                try { Environment.unset_variable ("SSH_AUTH_SOCK"); } catch (Error e) { }
            }

            
            // Setup GSettings and apply theme
            setup_settings ();
            
            // Create application actions
            create_actions ();
        }
        
        private void setup_settings () {
            // Apply initial theme
            var theme = SettingsManager.theme;
            apply_theme (theme);

            // Listen for theme changes
            SettingsManager.app.changed["theme"].connect ((key) => {
                var new_theme = SettingsManager.app.get_string (key);
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
            var last_version = SettingsManager.last_version_shown;
            var current_version = Config.VERSION;

            // Show if this is the first run (empty last version) or version has changed
            if (last_version == "" || last_version != current_version) {
                SettingsManager.last_version_shown = current_version;
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
            // Trigger initial key refresh after window is shown unless deferred via env
            var defer_scan = Environment.get_variable ("KEYMAKER_DEFER_SCAN");
            if (defer_scan == null || defer_scan.strip () == "" || defer_scan == "0") {
                Idle.add (() => { window.refresh_keys (); return false; });
            }
            
            // Check if this is a new version and show release notes automatically
            if (should_show_release_notes ()) {
                // Small delay to ensure main window is fully presented
                Timeout.add (500, () => {
                    show_about_with_release_notes ();
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

            // SSH Agent action
            var ssh_agent_action = new SimpleAction ("ssh-agent", null);
            ssh_agent_action.activate.connect (on_ssh_agent_action);
            add_action (ssh_agent_action);

            // SSH Config action  
            var ssh_config_action = new SimpleAction ("ssh-config", null);
            ssh_config_action.activate.connect (on_ssh_config_action);
            add_action (ssh_config_action);

            // Connection Diagnostics action
            var connection_diagnostics_action = new SimpleAction ("connection-diagnostics", null);
            connection_diagnostics_action.activate.connect (on_connection_diagnostics_action);
            add_action (connection_diagnostics_action);

            // Key Rotation action
            var key_rotation_action = new SimpleAction ("key-rotation", null);
            key_rotation_action.activate.connect (on_key_rotation_action);
            add_action (key_rotation_action);

            // Backup Center action
            var backup_center_action = new SimpleAction ("backup-center", null);
            backup_center_action.activate.connect (on_backup_center_action);
            add_action (backup_center_action);

            // SSH Tunneling action
            var ssh_tunneling_action = new SimpleAction ("ssh-tunneling", null);
            ssh_tunneling_action.activate.connect (on_ssh_tunneling_action);
            add_action (ssh_tunneling_action);
        }

        private void on_about_action () {
            show_about_dialog ();
        }
        
        private void show_about_dialog () {
            var about = new Adw.AboutDialog () {
                application_name = Config.APP_NAME,
                application_icon = Config.APP_ID,
                developer_name = "Thiago Fernandes",
                version = Config.VERSION,
                website = "https://github.com/tobagin/keymaker",
                issue_url = "https://github.com/tobagin/keymaker/issues",
                license_type = Gtk.License.GPL_3_0,
                copyright = "Copyright © 2025 Thiago Fernandes"
            };
            
            // Load release notes from metainfo
            try {
                var metainfo_path = Path.build_filename ("/app/share/metainfo", "%s.metainfo.xml".printf (Config.APP_ID));
                var file = File.new_for_path (metainfo_path);
                
                if (file.query_exists ()) {
                    uint8[] contents;
                    file.load_contents (null, out contents, null);
                    string xml_content = (string) contents;
                    
                    // Simple XML parsing to extract release notes
                    var release_notes = extract_release_notes_from_xml (xml_content);
                    if (release_notes != null) {
                        about.set_release_notes (release_notes);
                    }
                }
            } catch (Error e) {
                warning ("Could not load release notes: %s", e.message);
            }
            
            if (window != null) {
                about.present (window);
            }
        }
        
        private void show_about_with_release_notes () {
            show_about_dialog ();
            
            // Wait for the dialog to appear, then navigate to release notes
            Timeout.add (300, () => {
                simulate_tab_navigation ();
                
                // Simulate Enter key press after another delay to open release notes
                Timeout.add (200, () => {
                    simulate_enter_activation ();
                    return false;
                });
                return false;
            });
        }
        
        private void simulate_tab_navigation () {
            if (window == null) return;
            
            var focused_widget = window.get_focus ();
            if (focused_widget != null) {
                var parent = focused_widget.get_parent ();
                if (parent != null) {
                    parent.child_focus (Gtk.DirectionType.TAB_FORWARD);
                }
            }
        }
        
        private void simulate_enter_activation () {
            if (window == null) return;
            
            var focused_widget = window.get_focus ();
            if (focused_widget != null) {
                if (focused_widget is Gtk.Button) {
                    ((Gtk.Button)focused_widget).activate ();
                } else {
                    focused_widget.activate_default ();
                }
            }
        }
        
        private string? extract_release_notes_from_xml (string xml_content) {
            // Simple extraction of the first release entry
            var start_marker = "<release version=\"" + Config.VERSION + "\"";
            var start_pos = xml_content.index_of (start_marker);
            if (start_pos == -1) {
                // Fallback to first release
                start_pos = xml_content.index_of ("<release");
                if (start_pos == -1) return null;
            }
            
            var desc_start = xml_content.index_of ("<description>", start_pos);
            if (desc_start == -1) return null;
            desc_start += 13; // length of "<description>"
            
            var desc_end = xml_content.index_of ("</description>", desc_start);
            if (desc_end == -1) return null;
            
            var description = xml_content.substring (desc_start, desc_end - desc_start);
            
            // Clean up the description
            description = description.replace ("<p>", "").replace ("</p>", "\n");
            description = description.replace ("<ul>", "").replace ("</ul>", "");
            description = description.replace ("<li>", "• ").replace ("</li>", "\n");
            description = description.strip ();
            
            return description;
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

        private void on_ssh_agent_action () {
            if (window != null) {
                var dialog = new KeyMaker.SSHAgentDialog (window, window.get_ssh_keys ());
                dialog.present (window);
            }
        }

        private void on_ssh_config_action () {
            if (window != null) {
                var dialog = new KeyMaker.SSHConfigDialog (window);
                dialog.present (window);
            }
        }

        private void on_connection_diagnostics_action () {
            if (window != null) {
                var dialog = new KeyMaker.ConnectionDiagnosticsDialog (window);
                dialog.present (window);
            }
        }

        private void on_key_rotation_action () {
            if (window != null) {
                var dialog = new KeyMaker.KeyRotationDialog (window);
                dialog.present (window);
            }
        }

        private void on_backup_center_action () {
            if (window != null) {
                var dialog = new KeyMaker.BackupCenterDialog (window);
                dialog.present (window);
            }
        }

        private void on_ssh_tunneling_action () {
            if (window != null) {
                var dialog = new KeyMaker.SSHTunnelingDialog (window);
                dialog.present (window);
            }
        }
        
        private void add_command_line_options () {
            add_main_option ("version", 0, OptionFlags.NONE, OptionArg.NONE,
                           _("Show version information"), null);
            add_main_option ("verbose", 'v', OptionFlags.NONE, OptionArg.NONE,
                           _("Enable verbose logging"), null);
        }
    }
}
