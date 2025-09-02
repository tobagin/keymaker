/*
 * Key Maker - Connection Diagnostics Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/connection_diagnostics_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/connection_diagnostics_dialog.ui")]
#endif
public class KeyMaker.ConnectionDiagnosticsDialog : Adw.Dialog {
    [GtkChild]
    private unowned Gtk.Stack main_stack;
    
    [GtkChild]
    private unowned Adw.EntryRow hostname_entry;
    
    [GtkChild]
    private unowned Adw.EntryRow username_entry;
    
    [GtkChild]
    private unowned Adw.SpinRow port_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow test_basic_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow test_performance_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow test_tunnels_row;
    
    [GtkChild]
    private unowned Gtk.Button run_diagnostics_button;
    
    [GtkChild]
    private unowned Gtk.ListBox results_list;
    
    [GtkChild]
    private unowned Gtk.Label progress_label;
    
    [GtkChild]
    private unowned Gtk.ProgressBar progress_bar;
    
    private ConnectionDiagnostics diagnostics;
    
    public ConnectionDiagnosticsDialog (Gtk.Window parent) {
        Object ();
    }
    
    construct {
        diagnostics = new ConnectionDiagnostics ();
        setup_signals ();
        setup_defaults ();
    }
    
    private void setup_signals () {
        if (run_diagnostics_button != null) {
            run_diagnostics_button.clicked.connect (on_run_diagnostics);
        }
        
        if (diagnostics != null) {
            diagnostics.diagnostic_test_started.connect (on_test_started);
            diagnostics.diagnostic_test_completed.connect (on_test_completed);
            diagnostics.progress_updated.connect (on_progress_updated);
        }
    }
    
    private void setup_defaults () {
        username_entry.text = Environment.get_user_name () ?? "user";
        port_row.value = 22;
        test_basic_row.active = true;
    }
    
    private void on_run_diagnostics () {
        if (!validate_input ()) {
            show_error ("Invalid Input", "Please check hostname and username fields.");
            return;
        }
        
        main_stack.visible_child_name = "progress_page";
        progress_bar.fraction = 0.0;
        
        run_diagnostics_async.begin ((obj, res) => {
            try {
                run_diagnostics_async.end (res);
            } catch (Error e) {
                warning ("Failed to complete diagnostics: %s", e.message);
                show_error ("Diagnostics Failed", e.message);
                main_stack.visible_child_name = "setup_page";
            }
        });
    }
    
    private bool validate_input () {
        return hostname_entry.text.strip ().length > 0 && 
               username_entry.text.strip ().length > 0;
    }
    
    private async void run_diagnostics_async () {
        var target = new DiagnosticTarget ();
        target.hostname = hostname_entry.text.strip ();
        target.username = username_entry.text.strip ();
        target.port = (int) port_row.value;
        
        var options = new DiagnosticOptions ();
        options.test_basic_connection = test_basic_row.active;
        options.test_performance = test_performance_row.active;
        options.test_tunnel_capabilities = test_tunnels_row.active;
        
        try {
            yield diagnostics.run_diagnostics (target, options);
            show_results ();
        } catch (KeyMakerError e) {
            show_error ("Diagnostics Failed", e.message);
            main_stack.visible_child_name = "setup_page";
        }
    }
    
    private void on_test_started (string test_name) {
        progress_label.label = @"Running: $test_name";
    }
    
    private void on_test_completed (DiagnosticResult result) {
        add_result_row (result);
    }
    
    private void on_progress_updated (double progress) {
        progress_bar.fraction = progress;
    }
    
    private void show_results () {
        main_stack.visible_child_name = "results_page";
    }
    
    private void add_result_row (DiagnosticResult result) {
        var row = new Adw.ActionRow ();
        row.title = result.test_name;
        row.subtitle = result.details;
        
        var status_icon = new Gtk.Image ();
        switch (result.status) {
            case TestStatus.PASSED:
                status_icon.icon_name = "emblem-ok-symbolic";
                status_icon.add_css_class ("success");
                break;
            case TestStatus.FAILED:
                status_icon.icon_name = "dialog-error-symbolic";
                status_icon.add_css_class ("error");
                break;
            case TestStatus.WARNING:
                status_icon.icon_name = "dialog-warning-symbolic";
                status_icon.add_css_class ("warning");
                break;
            case TestStatus.SKIPPED:
                status_icon.icon_name = "media-skip-forward-symbolic";
                status_icon.add_css_class ("dim-label");
                break;
        }
        
        row.add_prefix (status_icon);
        
        if (result.execution_time_ms > 0) {
            var time_label = new Gtk.Label (@"$(result.execution_time_ms)ms");
            time_label.add_css_class ("dim-label");
            time_label.add_css_class ("numeric");
            row.add_suffix (time_label);
        }
        
        results_list.append (row);
    }
    
    private void show_error (string title, string message) {
        var error_dialog = new Adw.AlertDialog (title, message);
        error_dialog.add_response ("ok", "OK");
        error_dialog.set_default_response ("ok");
        error_dialog.present (this);
    }
}