/*
 * Key Maker - Connection Test Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/connection_test_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/connection_test_dialog.ui")]
#endif
public class KeyMaker.ConnectionTestDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.EntryRow hostname_row;
    
    [GtkChild]
    private unowned Adw.EntryRow username_row;
    
    [GtkChild]
    private unowned Adw.SpinRow port_row;
    
    [GtkChild]
    private unowned Adw.ActionRow identity_file_row;
    
    [GtkChild]
    private unowned Gtk.Label identity_file_label;
    
    [GtkChild]
    private unowned Adw.EntryRow proxy_jump_row;
    
    [GtkChild]
    private unowned Adw.SpinRow timeout_row;
    
    [GtkChild]
    private unowned Gtk.Button test_button;
    
    [GtkChild]
    private unowned Gtk.Button close_button;
    
    [GtkChild]
    private unowned Gtk.Stack main_stack;
    
    [GtkChild]
    private unowned Adw.StatusPage initial_page;
    
    [GtkChild]
    private unowned Gtk.Box testing_page;
    
    [GtkChild]
    private unowned Gtk.Spinner testing_spinner;
    
    [GtkChild]
    private unowned Gtk.Label testing_status;
    
    [GtkChild]
    private unowned Gtk.Box results_page;
    
    [GtkChild]
    private unowned Adw.ActionRow result_row;
    
    [GtkChild]
    private unowned Gtk.Label result_title;
    
    [GtkChild]
    private unowned Gtk.Label result_subtitle;
    
    [GtkChild]
    private unowned Gtk.Image result_icon;
    
    [GtkChild]
    private unowned Adw.ExpanderRow details_row;
    
    [GtkChild]
    private unowned Gtk.ListBox details_list;
    
    private ConnectionDiagnostics diagnostics;
    private File? selected_identity_file = null;
    private ConnectionTest? current_test = null;
    
    public SSHKey? ssh_key { get; construct; }
    public SSHConfigHost? ssh_host { get; construct; }
    
    public ConnectionTestDialog (Gtk.Window parent, SSHKey? key = null, SSHConfigHost? host = null) {
        Object (
            ssh_key: key,
            ssh_host: host
        );
    }
    
    construct {
        diagnostics = new ConnectionDiagnostics ();
        
        setup_signals ();
        setup_defaults ();
        
        if (ssh_host != null) {
            populate_from_ssh_host ();
        } else if (ssh_key != null) {
            populate_from_ssh_key ();
        }
        
        update_ui_state ();
    }
    
    private void setup_signals () {
        test_button.clicked.connect (on_test_clicked);
        close_button.clicked.connect (on_close_clicked);
        
        // Update UI state when fields change
        hostname_row.notify["text"].connect (update_ui_state);
        username_row.notify["text"].connect (update_ui_state);
        
        // Identity file selection
        identity_file_row.activated.connect (on_select_identity_file);
        
        // Diagnostics signals
        diagnostics.test_started.connect (on_test_started);
        diagnostics.test_progress.connect (on_test_progress);
        diagnostics.test_completed.connect (on_test_completed);
        
        // Port and timeout ranges
        port_row.set_range (1, 65535);
        timeout_row.set_range (5, 120);
    }
    
    private void setup_defaults () {
        username_row.text = Environment.get_user_name ();
        port_row.value = 22;
        timeout_row.value = 10;
        
        main_stack.visible_child = initial_page;
    }
    
    private void populate_from_ssh_host () {
        hostname_row.text = ssh_host.hostname ?? ssh_host.name;
        username_row.text = ssh_host.user ?? Environment.get_user_name ();
        port_row.value = ssh_host.port ?? 22;
        proxy_jump_row.text = ssh_host.proxy_jump ?? "";
        
        if (ssh_host.identity_file != null) {
            var path = ssh_host.identity_file;
            if (path.has_prefix ("~/")) {
                path = Path.build_filename (Environment.get_home_dir (), path.substring (2));
            }
            selected_identity_file = File.new_for_path (path);
            identity_file_label.label = Path.get_basename (selected_identity_file.get_path ());
        }
    }
    
    private void populate_from_ssh_key () {
        if (ssh_key.identity_file != null) {
            selected_identity_file = ssh_key.private_path;
            identity_file_label.label = Path.get_basename (selected_identity_file.get_path ());
        }
        
        // Try to guess hostname from comment
        if (ssh_key.comment != null) {
            var comment = ssh_key.comment.down ();
            if ("github" in comment) {
                hostname_row.text = "github.com";
                username_row.text = "git";
            } else if ("gitlab" in comment) {
                hostname_row.text = "gitlab.com"; 
                username_row.text = "git";
            }
        }
    }
    
    private void on_select_identity_file () {
        var dialog = new Gtk.FileDialog ();
        dialog.title = "Select SSH Identity File";
        dialog.modal = true;
        
        // Set initial folder to ~/.ssh
        var ssh_dir = File.new_for_path (Path.build_filename (Environment.get_home_dir (), ".ssh"));
        dialog.set_initial_folder (ssh_dir);
        
        dialog.open.begin (this, null, (obj, res) => {
            try {
                var file = dialog.open.end (res);
                selected_identity_file = file;
                identity_file_label.label = Path.get_basename (selected_identity_file.get_path ());
            } catch (Error e) {
                // User cancelled
            }
        });
    }
    
    private void update_ui_state () {
        var hostname = hostname_row.text.strip ();
        var username = username_row.text.strip ();
        
        test_button.sensitive = (hostname.length > 0 && username.length > 0);
    }
    
    private async void on_test_clicked () {
        var hostname = hostname_row.text.strip ();
        var username = username_row.text.strip ();
        var port = (int) port_row.value;
        var timeout = (int) timeout_row.value;
        var proxy_jump = proxy_jump_row.text.strip ();
        
        if (hostname.length == 0 || username.length == 0) {
            return;
        }
        
        try {
            current_test = yield diagnostics.test_connection (
                hostname, username, port, selected_identity_file,
                proxy_jump.length > 0 ? proxy_jump : null, timeout
            );
        } catch (KeyMakerError e) {
            show_error ("Connection test failed", e.message);
        }
    }
    
    private void on_test_started (ConnectionTest test) {
        main_stack.visible_child = testing_page;
        testing_spinner.spinning = true;
        testing_status.label = "Initializing connection test...";
        
        test_button.sensitive = false;
    }
    
    private void on_test_progress (ConnectionTest test, string status) {
        testing_status.label = status;
    }
    
    private void on_test_completed (ConnectionTest test) {
        testing_spinner.spinning = false;
        test_button.sensitive = true;
        
        show_test_results (test);
    }
    
    private void show_test_results (ConnectionTest test) {
        main_stack.visible_child = results_page;
        
        // Update result summary
        result_title.label = test.result.to_string ();
        result_subtitle.label = test.get_display_name ();
        result_icon.icon_name = test.result.get_icon_name ();
        
        if (test.result.is_success ()) {
            result_title.add_css_class ("success");
            result_icon.add_css_class ("success");
        } else {
            result_title.add_css_class ("error");  
            result_icon.add_css_class ("error");
        }
        
        // Clear previous details
        clear_details_list ();
        
        // Add connection details
        add_detail_row ("Connection Time", @"$(test.connection_time:.2f) seconds");
        add_detail_row ("Test Time", test.test_time.format ("%Y-%m-%d %H:%M:%S"));
        
        if (test.error_message.length > 0) {
            add_detail_row ("Error Message", test.error_message);
        }
        
        if (test.server_version != null) {
            add_detail_row ("Server Version", test.server_version);
        }
        
        if (test.supported_ciphers.length > 0) {
            var ciphers = string.joinv (", ", test.supported_ciphers.data);
            add_detail_row ("Supported Ciphers", ciphers);
        }
        
        if (test.supported_kex.length > 0) {
            var kex = string.joinv (", ", test.supported_kex.data);
            add_detail_row ("Key Exchange Algorithms", kex);
        }
        
        if (test.supported_host_key_types.length > 0) {
            var host_keys = string.joinv (", ", test.supported_host_key_types.data);
            add_detail_row ("Host Key Types", host_keys);
        }
        
        // Add recommendations
        add_recommendations (test);
    }
    
    private void clear_details_list () {
        Gtk.Widget? child = details_list.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            details_list.remove (child);
            child = next;
        }
    }
    
    private void add_detail_row (string title, string subtitle) {
        var row = new Adw.ActionRow ();
        row.title = title;
        row.subtitle = subtitle;
        details_list.append (row);
    }
    
    private void add_recommendations (ConnectionTest test) {
        var recommendations = new GenericArray<string> ();
        
        switch (test.result) {
            case ConnectionResult.KEY_NOT_ACCEPTED:
                recommendations.add ("• Check if the public key is added to ~/.ssh/authorized_keys on the server");
                recommendations.add ("• Verify the key file has correct permissions (600 for private key)");
                recommendations.add ("• Try using ssh-copy-id to install the key");
                break;
                
            case ConnectionResult.HOST_KEY_VERIFICATION_FAILED:
                recommendations.add ("• The server's host key has changed or is unknown");
                recommendations.add ("• Check ~/.ssh/known_hosts and remove old entries if needed");
                recommendations.add ("• Verify you're connecting to the correct server");
                break;
                
            case ConnectionResult.HOST_UNREACHABLE:
                recommendations.add ("• Check network connectivity and DNS resolution");
                recommendations.add ("• Verify the hostname and port are correct");
                recommendations.add ("• Check if firewall is blocking the connection");
                break;
                
            case ConnectionResult.TIMEOUT:
                recommendations.add ("• Try increasing the connection timeout");
                recommendations.add ("• Check network stability and latency");
                recommendations.add ("• Verify the server is running and accessible");
                break;
                
            case ConnectionResult.AUTH_FAILED:
                recommendations.add ("• Check username and authentication method");
                recommendations.add ("• Verify SSH key is loaded in ssh-agent");
                recommendations.add ("• Try password authentication if available");
                break;
        }
        
        if (recommendations.length > 0) {
            var rec_text = string.joinv ("\n", recommendations.data);
            add_detail_row ("Recommendations", rec_text);
        }
    }
    
    private void show_error (string title, string message) {
        var error_dialog = new Adw.AlertDialog (title, message);
        error_dialog.add_response ("ok", "OK");
        error_dialog.set_default_response ("ok");
        error_dialog.present (this);
    }
    
    private void on_close_clicked () {
        close ();
    }
}