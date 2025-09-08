/*
 * Key Maker - Connection Diagnostics Runner Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/connection_diagnostics_runner_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/connection_diagnostics_runner_dialog.ui")]
#endif
public class ConnectionDiagnosticsRunnerDialog : Adw.Dialog {
    
    // Navigation
    [GtkChild]
    private unowned Adw.NavigationView navigation_view;
    
    [GtkChild]
    private unowned Adw.NavigationPage setup_page;
    
    [GtkChild]
    private unowned Adw.NavigationPage results_page;
    
    [GtkChild]
    private unowned Adw.NavigationPage progress_page;
    
    // Form elements
    [GtkChild]
    private unowned Adw.EntryRow hostname_entry;
    
    [GtkChild]
    private unowned Adw.EntryRow username_entry;
    
    [GtkChild]
    private unowned Adw.SpinRow port_row;
    
    [GtkChild]
    private unowned Adw.ComboRow auth_method_row;
    
    [GtkChild]
    private unowned Adw.ComboRow ssh_key_row;
    
    [GtkChild]
    private unowned Adw.PasswordEntryRow password_entry;
    
    // Test options
    [GtkChild]
    private unowned Adw.SwitchRow test_basic_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow test_dns_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow test_protocol_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow test_performance_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow test_tunnels_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow test_permissions_row;
    
    // Buttons
    [GtkChild]
    private unowned Gtk.Button run_diagnostics_button;
    
    [GtkChild]
    private unowned Gtk.Button run_again_button_header;
    
    [GtkChild]
    private unowned Gtk.Button cancel_progress_button;
    
    // Progress elements
    [GtkChild]
    private unowned Gtk.Label progress_label;
    
    [GtkChild]
    private unowned Gtk.ProgressBar progress_bar;
    
    // Results elements
    [GtkChild]
    private unowned Gtk.ListBox results_list;
    
    [GtkChild]
    private unowned Adw.WindowTitle results_window_title;
    
    private Adw.ActionRow results_subtitle_row;
    private Gtk.Button download_report_button;
    
    private ConnectionDiagnostics diagnostics;
    private DiagnosticHistory diagnostic_history;
    private GenericArray<SSHKey> available_keys;
    private GenericArray<DiagnosticResult>? current_results;
    private bool is_fresh_test;
    private DateTime? test_start_time;
    
    public signal void diagnostic_completed (DiagnosticTarget target, DiagnosticOptions options, GenericArray<DiagnosticResult> results);
    
    public ConnectionDiagnosticsRunnerDialog (Gtk.Window parent, DiagnosticHistory history, bool fresh_test = false) {
        Object ();
        diagnostic_history = history;
        is_fresh_test = fresh_test;
    }
    
    construct {
        debug ("ConnectionDiagnosticsRunnerDialog: Constructor called (fresh_test=%s)", is_fresh_test.to_string ());
        diagnostics = new ConnectionDiagnostics ();
        available_keys = new GenericArray<SSHKey> ();
        current_results = new GenericArray<DiagnosticResult> ();
        
        setup_results_subtitle_row ();
        setup_signals ();
        setup_defaults ();
        setup_auth_methods ();
        load_ssh_keys_sync ();
        
        // If this is a fresh test, ensure form is completely reset
        if (is_fresh_test) {
            reset_form_and_results ();
        }
        
        debug ("ConnectionDiagnosticsRunnerDialog: Constructor completed");
    }
    
    private void setup_results_subtitle_row () {
        // Create the download report button
        download_report_button = new Gtk.Button () {
            label = _("Download Report"),
            valign = Gtk.Align.CENTER
        };
        download_report_button.add_css_class ("flat");
        
        // Create the results subtitle row with embedded button
        results_subtitle_row = new Adw.ActionRow () {
            title = _("Diagnostic Results"),
            subtitle = _("Connection test completed")
        };
        results_subtitle_row.add_suffix (download_report_button);
        results_list.prepend (results_subtitle_row);
        
        // Add spacing after subtitle row
        results_subtitle_row.margin_bottom = 12;
    }
    
    private void setup_signals () {
        // Diagnostics engine signals
        diagnostics.diagnostic_test_started.connect (on_test_started);
        diagnostics.diagnostic_test_completed.connect (on_test_completed);
        diagnostics.progress_updated.connect (on_progress_updated);
        
        // Form validation signals
        hostname_entry.notify["text"].connect (validate_form);
        username_entry.notify["text"].connect (validate_form);
        auth_method_row.notify["selected"].connect (on_auth_method_changed);
        
        // Button signals
        if (run_diagnostics_button != null) {
            run_diagnostics_button.clicked.connect (on_run_diagnostics);
        }
        
        if (run_again_button_header != null) {
            run_again_button_header.clicked.connect (on_run_again);
        }
        
        if (cancel_progress_button != null) {
            cancel_progress_button.clicked.connect (on_cancel_progress);
        }
        
        if (download_report_button != null) {
            download_report_button.clicked.connect (on_download_report);
        }
    }
    
    private void setup_defaults () {
        hostname_entry.text = "";
        username_entry.text = Environment.get_user_name () ?? "";
        port_row.value = 22;
        
        // Set default test options
        test_basic_row.active = true;
        test_dns_row.active = true;
        test_protocol_row.active = true;
        test_performance_row.active = false;
        test_tunnels_row.active = false;
        test_permissions_row.active = false;
        
        validate_form ();
    }
    
    private void setup_auth_methods () {
        var auth_model = new Gtk.StringList (null);
        auth_model.append (_("SSH Key"));
        auth_model.append (_("Password"));
        auth_method_row.model = auth_model;
        auth_method_row.selected = 0; // Default to SSH Key
    }
    
    private void load_ssh_keys_sync () {
        available_keys.remove_range (0, available_keys.length);
        
        var ssh_key_model = new Gtk.StringList (null);
        ssh_key_model.append (_("Auto-detect"));
        
        try {
            var keys = KeyScanner.scan_ssh_directory_sync ();
            
            for (uint i = 0; i < keys.length; i++) {
                var key = keys[i];
                available_keys.add (key);
                
                var display_name = @"$(key.get_display_name()) ($(key.get_type_description()))";
                ssh_key_model.append (display_name);
            }
        } catch (Error e) {
            warning ("Failed to load SSH keys: %s", e.message);
        }
        
        ssh_key_row.model = ssh_key_model;
        ssh_key_row.selected = 0; // Default to auto-detect
    }
    
    private void validate_form () {
        var hostname = hostname_entry.text.strip ();
        var username = username_entry.text.strip ();
        
        bool is_valid = hostname.length > 0 && username.length > 0;
        run_diagnostics_button.sensitive = is_valid;
    }
    
    private void on_auth_method_changed () {
        var is_password = auth_method_row.selected == 1;
        password_entry.visible = is_password;
        ssh_key_row.visible = !is_password;
    }
    
    private void on_run_diagnostics () {
        debug ("Running diagnostics...");
        navigation_view.push (progress_page);
        run_diagnostics_async.begin ();
    }
    
    private void on_run_again () {
        reset_form_and_results ();
        navigation_view.pop_to_tag ("setup");
    }
    
    private void on_cancel_progress () {
        diagnostics.cancel_diagnostics ();
        navigation_view.pop_to_tag ("setup");
    }
    
    public void reset_form_and_results () {
        debug ("Resetting form and results for fresh diagnostic test");
        
        // Clear form fields
        hostname_entry.text = "";
        username_entry.text = Environment.get_user_name () ?? "";
        port_row.value = 22;
        password_entry.text = "";
        
        // Reset auth method and key selection
        auth_method_row.selected = 0; // Default to SSH Key
        ssh_key_row.selected = 0; // Default to auto-detect
        on_auth_method_changed (); // Update visibility
        
        // Reset test options to defaults
        test_basic_row.active = true;
        test_dns_row.active = true;
        test_protocol_row.active = true;
        test_performance_row.active = false;
        test_tunnels_row.active = false;
        test_permissions_row.active = false;
        
        // Clear current results
        if (current_results != null) {
            current_results.remove_range (0, current_results.length);
        }
        
        // Reset test start time
        test_start_time = null;
        
        // Clear results list (except subtitle row)
        clear_results_list ();
        
        // Reset progress elements
        progress_label.label = "";
        progress_bar.fraction = 0.0;
        
        // Validate form
        validate_form ();
        
        debug ("Form and results reset completed");
    }
    
    private void clear_results_list () {
        // Clear existing result entries except the subtitle row
        var child = results_list.get_first_child ();
        while (child != null) {
            var next_child = child.get_next_sibling ();
            if (child != results_subtitle_row) {
                results_list.remove (child);
            }
            child = next_child;
        }
        
        // Reset results window title
        if (results_window_title != null) {
            results_window_title.title = _("Diagnostic Results");
            results_window_title.subtitle = _("Ready for new connection test");
        }
        
        // Reset subtitle row
        if (results_subtitle_row != null) {
            results_subtitle_row.title = _("Diagnostic Results");
            results_subtitle_row.subtitle = _("Run a new diagnostic to see results here");
        }
    }
    
    private async void run_diagnostics_async () {
        current_results.remove_range (0, current_results.length);
        test_start_time = new DateTime.now_local ();
        
        var target = new DiagnosticTarget ();
        target.hostname = hostname_entry.text.strip ();
        target.username = username_entry.text.strip ();
        target.port = (int) port_row.value;
        target.key_file = get_selected_key_file ();
        
        var options = new DiagnosticOptions ();
        options.test_basic_connection = test_basic_row.active;
        options.test_dns_resolution = test_dns_row.active;
        options.test_protocol_detection = test_protocol_row.active;
        options.test_performance = test_performance_row.active;
        options.test_tunnel_capabilities = test_tunnels_row.active;
        options.test_permissions = test_permissions_row.active;
        
        try {
            yield diagnostics.run_diagnostics (target, options);
            save_to_history (target, options);
            show_results ();
        } catch (KeyMakerError e) {
            show_error ("Diagnostics Failed", e.message);
            navigation_view.pop_to_tag ("setup");
        }
    }
    
    private void save_to_history (DiagnosticTarget target, DiagnosticOptions options) {
        if (diagnostic_history != null && current_results != null) {
            // Override target auth method to match what's displayed in live report
            var auth_method = auth_method_row.selected == 0 ? "SSH Key" : "Password";
            diagnostic_history.add_entry_with_auth_method (target, options, current_results, test_start_time, auth_method);
            diagnostic_completed (target, options, current_results);
        }
    }
    
    private string? get_selected_key_file () {
        if (auth_method_row.selected == 1) {
            // Password authentication
            return null;
        }
        
        var selected_key_index = ssh_key_row.selected;
        if (selected_key_index == 0 || selected_key_index > available_keys.length) {
            // Auto-detect or invalid selection
            return null;
        }
        
        var key = available_keys[selected_key_index - 1]; // -1 because of "Auto-detect" option
        return key.private_path.get_path ();
    }
    
    // Removed on_diagnostic_started - not needed with current ConnectionDiagnostics API
    
    private void on_test_started (string test_name) {
        progress_label.label = @"Running: $test_name";
    }
    
    private void on_test_completed (DiagnosticResult result) {
        current_results.add (result);
        add_result_row (result);
    }
    
    private void on_progress_updated (double progress) {
        progress_bar.fraction = progress;
    }
    
    private void show_results () {
        update_results_title ();
        navigation_view.push (results_page);
    }
    
    private void update_results_title () {
        if (results_window_title != null && hostname_entry != null && username_entry != null) {
            var hostname = hostname_entry.text.strip ();
            var username = username_entry.text.strip ();
            var port = (int) port_row.value;
            
            var subtitle = @"Connection test results for $username@$hostname:$port";
            results_window_title.subtitle = subtitle;
            
            // Also update the subtitle row
            if (results_subtitle_row != null) {
                results_subtitle_row.title = subtitle;
            }
        }
    }
    
    private void add_result_row (DiagnosticResult result) {
        if (results_list == null) {
            warning ("results_list is null, cannot add result row for: %s", result.test_name);
            return;
        }
        
        var row = new Adw.ActionRow ();
        row.title = result.test_name;
        row.subtitle = result.details;
        
        var status_icon = new Gtk.Image ();
        status_icon.icon_size = Gtk.IconSize.NORMAL;
        switch (result.status) {
            case TestStatus.PASSED:
                status_icon.icon_name = "checkmark-symbolic";
            status_icon.icon_size = LARGE;
                status_icon.add_css_class ("success");
                break;
            case TestStatus.FAILED:
                status_icon.icon_name = "cross-symbolic";
            status_icon.icon_size = LARGE;
                status_icon.add_css_class ("error");
                break;
            case TestStatus.WARNING:
                status_icon.icon_name = "warning-symbolic";
            status_icon.icon_size = LARGE;
                status_icon.add_css_class ("warning");
                break;
            case TestStatus.SKIPPED:
                status_icon.icon_name = "minus-symbolic";
            status_icon.icon_size = LARGE;
                break;
        }
        row.add_prefix (status_icon);
        
        var execution_time_label = new Gtk.Label (@"$(result.execution_time_ms)ms") {
            margin_start = 8
        };
        execution_time_label.add_css_class ("dim-label");
        row.add_suffix (execution_time_label);
        
        results_list.append (row);
    }
    
    private void on_download_report () {
        debug ("Downloading diagnostic report...");
        
        var file_dialog = new Gtk.FileDialog () {
            title = _("Save Diagnostic Report"),
            initial_name = generate_report_filename ()
        };
        
        file_dialog.save.begin (this.get_root () as Gtk.Window, null, (obj, res) => {
            try {
                var file = file_dialog.save.end (res);
                generate_report_async.begin (file);
            } catch (Error e) {
                if (e.code != Gtk.DialogError.DISMISSED) {
                    show_error (_("Save Error"), e.message);
                }
            }
        });
    }
    
    private string generate_report_filename () {
        var hostname = hostname_entry.text.strip ();
        // Use the stored test start time for consistent filenames
        var test_time = test_start_time != null ? test_start_time : new DateTime.now_local();
        var timestamp = test_time.format ("%Y%m%d_%H%M%S");
        return @"ssh_diagnostic_$(hostname)_$(timestamp).txt";
    }
    
    private async void generate_report_async (File file) {
        try {
            var report = generate_report_content ();
            yield file.replace_contents_async (report.data, null, false, FileCreateFlags.REPLACE_DESTINATION, null, null);
        } catch (Error e) {
            show_error (_("Save Error"), @"Failed to save report: $(e.message)");
        }
    }
    
    private string generate_report_content () {
        var builder = new StringBuilder ();
        var timestamp = test_start_time != null ? test_start_time : new DateTime.now_local ();
        
        builder.append ("SSH Connection Diagnostic Report\n");
        builder.append ("====================================\n\n");
        builder.append (@"Generated: $(timestamp.format ("%Y-%m-%d %H:%M:%S"))\n");
        builder.append (@"Target: $(username_entry.text)@$(hostname_entry.text):$(port_row.value)\n");
        builder.append (@"Authentication: $(auth_method_row.selected == 0 ? "SSH Key" : "Password")\n");
        builder.append ("\nTest Results:\n");
        builder.append ("-------------\n");
        
        if (current_results != null) {
            for (uint i = 0; i < current_results.length; i++) {
                var result = current_results[i];
                builder.append (@"$(result.test_name): $(result.status) ($(result.execution_time_ms)ms)\n");
                if (result.details.length > 0) {
                    builder.append (@"  Details: $(result.details)\n");
                }
                // Note: DiagnosticResult uses 'details' field for both success and error info
                builder.append ("\n");
            }
        }
        
        return builder.str;
    }
    
    private void show_info (string title, string message) {
        var info_dialog = new Adw.AlertDialog (title, message);
        info_dialog.add_response ("ok", "OK");
        info_dialog.set_default_response ("ok");
        info_dialog.present (this);
    }
    
    private void show_error (string title, string message) {
        var error_dialog = new Adw.AlertDialog (title, message);
        error_dialog.add_response ("ok", "OK");
        error_dialog.set_default_response ("ok");
        error_dialog.present (this);
    }
    
    public void load_configuration (DiagnosticHistoryEntry entry) {
        // Load configuration from history entry
        hostname_entry.text = entry.hostname;
        username_entry.text = entry.username;
        port_row.value = entry.port;
        
        // Set test options
        test_basic_row.active = entry.test_basic;
        test_dns_row.active = entry.test_dns;
        test_protocol_row.active = entry.test_protocol;
        test_performance_row.active = entry.test_performance;
        test_tunnels_row.active = entry.test_tunnels;
        test_permissions_row.active = entry.test_permissions;
        
        // Handle authentication method and key selection
        if (entry.auth_method == "SSH Key" && entry.key_file != null) {
            // Try to find and select the SSH key
            for (uint i = 0; i < available_keys.length; i++) {
                var key = available_keys[i];
                if (key.private_path.get_path () == entry.key_file) {
                    ssh_key_row.selected = (uint)(i + 1); // +1 because of "Auto-detect" option
                    auth_method_row.selected = 0; // SSH Key
                    break;
                }
            }
            if (ssh_key_row.selected == 0) {
                // Key not found, set to auto-detect
                ssh_key_row.selected = 0;
                auth_method_row.selected = 0; // SSH Key
            }
        } else {
            // Password authentication
            auth_method_row.selected = 1; // Password
        }
        
        validate_form ();
    }
}

}