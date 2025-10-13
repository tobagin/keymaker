/*
 * SSHer - Terminal Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/terminal_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/terminal_dialog.ui")]
#endif
public class KeyMaker.TerminalDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.WindowTitle window_title;
    
    [GtkChild]
    private unowned Gtk.Button copy_button;
    
    [GtkChild]
    private unowned Gtk.Box terminal_container;
    
    [GtkChild]
    private unowned Gtk.Label status_label;
    
    [GtkChild]
    private unowned Gtk.Label connection_status;
    
    private Vte.Terminal terminal;
    private Vte.Pty? pty = null;
    private string host_name;
    private string ssh_command;
    
    public signal void terminal_closed ();
    
    public TerminalDialog (Gtk.Window parent, string host_name, string ssh_command) {
        print ("🏗️ TerminalDialog constructor called for host: %s\n", host_name ?? "null");
        Object ();

        this.host_name = host_name ?? "unknown";
        this.ssh_command = ssh_command ?? "ssh";

        print ("📝 TerminalDialog properties set: host_name=%s, ssh_command=%s\n", this.host_name, this.ssh_command);

        // Schedule the connection start and UI setup for after construction completes
        Idle.add (() => {
            print ("⏰ Idle callback executing post_construction_setup\n");
            post_construction_setup ();
            return false;
        });
        print ("✅ TerminalDialog constructor completed\n");
    }

    construct {
        print ("🔧 TerminalDialog construct block started\n");
        setup_terminal ();
        setup_actions ();
        setup_signals ();
        print ("✅ TerminalDialog construct block completed\n");
    }
    
    private void setup_terminal () {
        print ("🖥️  setup_terminal() started\n");
        // Create VTE terminal
        terminal = new Vte.Terminal ();
        print ("✅ VTE Terminal created\n");
        
        // Configure terminal appearance
        terminal.set_size_request (800, 600);
        terminal.set_hexpand (true);
        terminal.set_vexpand (true);
        terminal.set_scrollback_lines (10000);
        
        // Set terminal colors to follow system theme
        setup_terminal_colors ();
        
        // Set font
        var font_desc = Pango.FontDescription.from_string ("Monospace 11");
        terminal.set_font (font_desc);
        
        // Enable mouse autohide and other features
        terminal.set_mouse_autohide (true);
        terminal.set_audible_bell (false);
        terminal.set_allow_hyperlink (true);
        
        // Add terminal to container
        print ("📦 Adding terminal to container\n");
        terminal_container.append (terminal);
        print ("✅ Terminal added to container\n");

        // Watch for theme changes
        var style_manager = Adw.StyleManager.get_default ();
        style_manager.notify["dark"].connect (() => {
            setup_terminal_colors ();
        });
        
        // Update window title and start connection will be done after construct completes
    }
    
    private void setup_actions () {
        var action_group = new SimpleActionGroup ();
        
        // Copy action
        var copy_action = new SimpleAction ("copy", null);
        copy_action.activate.connect (on_copy_activated);
        action_group.add_action (copy_action);
        
        // Paste action
        var paste_action = new SimpleAction ("paste", null);
        paste_action.activate.connect (on_paste_activated);
        action_group.add_action (paste_action);
        
        // Select all action
        var select_all_action = new SimpleAction ("select-all", null);
        select_all_action.activate.connect (on_select_all_activated);
        action_group.add_action (select_all_action);
        
        // Clear action
        var clear_action = new SimpleAction ("clear", null);
        clear_action.activate.connect (on_clear_activated);
        action_group.add_action (clear_action);
        
        // Reset action
        var reset_action = new SimpleAction ("reset", null);
        reset_action.activate.connect (on_reset_activated);
        action_group.add_action (reset_action);
        
        // Add action group
        this.insert_action_group ("terminal", action_group);
    }
    
    private void setup_signals () {
        // Terminal selection changed
        terminal.selection_changed.connect (() => {
            copy_button.sensitive = terminal.get_has_selection ();
        });
        
        // Terminal child exited
        terminal.child_exited.connect ((status) => {
            connection_status.label = "Disconnected";
            connection_status.remove_css_class ("success");
            connection_status.add_css_class ("error");
            status_label.label = "Connection closed (exit code: " + status.to_string () + ")";
            terminal_closed ();
            
            // Auto-close the dialog immediately when connection ends
            this.close ();
        });
        
        // Terminal window title changed (deprecated in VTE 0.78+)
        // Using property notification to handle null values safely
        terminal.notify["window-title"].connect (() => {
            var title = terminal.window_title;
            if (title != null && title.length > 0) {
                window_title.subtitle = title;
            } else {
                window_title.subtitle = "";
            }
        });
        
        // Handle close attempts
        close_attempt.connect (() => {
            // Always show confirmation for terminal connections
            show_close_confirmation ();
        });
        
        // Copy button clicked
        copy_button.clicked.connect (on_copy_activated);
    }
    
    private void post_construction_setup () {
        print ("🎯 post_construction_setup() started\n");

        // Update window title now that we have the hostname
        var safe_host = host_name ?? "Unknown Host";
        if (window_title != null) {
            print ("📝 Setting window title to: SSH Terminal - %s\n", safe_host);
            window_title.title = "SSH Terminal - " + safe_host;
        } else {
            print ("⚠️  window_title is null!\n");
        }

        // Start SSH connection now that everything is properly initialized
        print ("🚀 Calling start_ssh_connection()\n");
        start_ssh_connection ();
        print ("✅ post_construction_setup() completed\n");
    }

    private void start_ssh_connection () {
        print ("🔌 start_ssh_connection() started for host: %s\n", host_name);
        try {
            status_label.label = "Connecting...";
            connection_status.label = "Connecting";
            connection_status.remove_css_class ("success");
            connection_status.remove_css_class ("error");
            connection_status.add_css_class ("warning");

            // Ensure host_name is not null or empty
            if (host_name == null || host_name.strip () == "") {
                print ("❌ Invalid hostname: '%s'\n", host_name ?? "(null)");
                show_connection_error ("Invalid hostname provided: '" + (host_name ?? "(null)") + "'");
                return;
            }

            var argv = new string[] { "ssh", host_name };
            var env = Environ.get ();

            var spawn_flags = GLib.SpawnFlags.SEARCH_PATH;

            print ("📡 Spawning SSH process: ssh %s\n", host_name);
            // Try synchronous spawn for better error handling
            try {
                terminal.spawn_sync (
                    Vte.PtyFlags.DEFAULT,
                    null, // working directory
                    argv,
                    env,
                    spawn_flags,
                    null, // child setup
                    null  // cancellable
                );

                print ("✅ SSH spawn succeeded!\n");
                // If we get here, spawn was successful
                status_label.label = "SSH terminal started for " + (host_name ?? "unknown host");
                connection_status.label = "Connected";
                connection_status.remove_css_class ("warning");
                connection_status.add_css_class ("success");

            } catch (Error spawn_error) {
                print ("❌ SSH spawn failed: %s\n", spawn_error.message);
                var error_msg = spawn_error.message ?? "Failed to start SSH process";
                status_label.label = "Failed to connect: " + error_msg;
                connection_status.label = "Failed";
                connection_status.remove_css_class ("warning");
                connection_status.add_css_class ("error");
                show_connection_error (error_msg);
                return;
            }

        } catch (Error e) {
            print ("❌ Outer exception in start_ssh_connection: %s\n", e.message);
            var error_msg = e.message ?? "Unknown error";
            status_label.label = "Failed to start terminal: " + error_msg;
            connection_status.label = "Error";
            connection_status.add_css_class ("error");
            show_connection_error (error_msg);
        }
    }
    
    private void show_connection_error (string message) {
        var safe_host = host_name ?? "unknown host";
        var safe_message = message ?? "Unknown error";
        var dialog = new Adw.AlertDialog (
            "Connection Failed",
            "Failed to establish SSH connection to " + safe_host + ":\n\n" + safe_message
        );
        dialog.add_response ("ok", "OK");
        dialog.set_default_response ("ok");
        dialog.present (this);
    }
    
    private void show_close_confirmation () {
        var safe_host = host_name ?? "the server";
        var dialog = new Adw.AlertDialog (
            "Close Terminal?",
            "The SSH connection to " + safe_host + " may still be active. Are you sure you want to close the terminal?"
        );
        dialog.add_response ("cancel", "Cancel");
        dialog.add_response ("close", "Close Terminal");
        dialog.set_response_appearance ("close", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response ("cancel");
        dialog.set_close_response ("cancel");
        
        dialog.response.connect ((response) => {
            if (response == "close") {
                force_close_terminal ();
            }
        });
        
        dialog.present (this);
    }
    
    private void force_close_terminal () {
        this.force_close ();
    }
    
    // Action callbacks
    private void on_copy_activated () {
        if (terminal.get_has_selection ()) {
            terminal.copy_clipboard_format (Vte.Format.TEXT);
        }
    }
    
    private void on_paste_activated () {
        terminal.paste_clipboard ();
    }
    
    private void on_select_all_activated () {
        terminal.select_all ();
    }
    
    private void on_clear_activated () {
        // Try multiple approaches to clear the terminal
        // Method 1: Send clear command directly
        terminal.feed_child ("clear\n".data);
        
        // Method 2: Also send ANSI escape sequences as backup
        terminal.feed_child ("\x1b[2J\x1b[H".data);
    }
    
    private void on_reset_activated () {
        terminal.reset (true, true);
    }
    
    private void setup_terminal_colors () {
        var style_manager = Adw.StyleManager.get_default ();
        bool is_dark = style_manager.dark;
        
        var fg_color = Gdk.RGBA ();
        var bg_color = Gdk.RGBA ();
        
        if (is_dark) {
            // Dark mode colors
            fg_color.parse ("#FFFFFF");
            bg_color.parse ("#1E1E1E");
        } else {
            // Light mode colors  
            fg_color.parse ("#2E3436");
            bg_color.parse ("#FFFFFF");
        }
        
        terminal.set_colors (fg_color, bg_color, null);
    }
}