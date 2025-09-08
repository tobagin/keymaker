/*
 * Key Maker - Diagnostics Page
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/diagnostics_page.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/diagnostics_page.ui")]
#endif
public class KeyMaker.DiagnosticsPage : Adw.Bin {
    [GtkChild]
    private unowned Gtk.Button run_diagnostics_button;
    [GtkChild]
    private unowned Adw.PreferencesGroup quick_tests_group;
    [GtkChild]
    private unowned Adw.PreferencesGroup detailed_diagnostics_group;
    [GtkChild]
    private unowned Adw.PreferencesGroup test_history_group;
    
    private GenericArray<DiagnosticTest> quick_tests;
    private GenericArray<DiagnosticTest> detailed_tests;
    private GenericArray<DiagnosticResult> test_history;
    
    // Signals for window integration
    public signal void show_toast_requested (string message);
    
    construct {
        quick_tests = new GenericArray<DiagnosticTest> ();
        detailed_tests = new GenericArray<DiagnosticTest> ();
        test_history = new GenericArray<DiagnosticResult> ();
        
        // Setup button signals
        run_diagnostics_button.clicked.connect (on_run_diagnostics_clicked);
        
        // Initialize test data
        initialize_tests ();
        refresh_diagnostics_data ();
    }
    
    private void initialize_tests () {
        // Quick tests
        var ssh_agent_test = new DiagnosticTest ();
        ssh_agent_test.name = _("SSH Agent Status");
        ssh_agent_test.description = _("Check if SSH agent is running and accessible");
        ssh_agent_test.test_type = QUICK;
        quick_tests.add (ssh_agent_test);
        
        var key_permissions_test = new DiagnosticTest ();
        key_permissions_test.name = _("Key File Permissions");
        key_permissions_test.description = _("Verify SSH key file permissions are secure");
        key_permissions_test.test_type = QUICK;
        quick_tests.add (key_permissions_test);
        
        var ssh_config_test = new DiagnosticTest ();
        ssh_config_test.name = _("SSH Configuration");
        ssh_config_test.description = _("Validate SSH configuration syntax and settings");
        ssh_config_test.test_type = QUICK;
        quick_tests.add (ssh_config_test);
        
        // Detailed tests
        var connectivity_test = new DiagnosticTest ();
        connectivity_test.name = _("Host Connectivity");
        connectivity_test.description = _("Test connections to configured SSH hosts");
        connectivity_test.test_type = DETAILED;
        detailed_tests.add (connectivity_test);
        
        var auth_test = new DiagnosticTest ();
        auth_test.name = _("Authentication Methods");
        auth_test.description = _("Test various authentication methods for each host");
        auth_test.test_type = DETAILED;
        detailed_tests.add (auth_test);
        
        var performance_test = new DiagnosticTest ();
        performance_test.name = _("Connection Performance");
        performance_test.description = _("Measure connection latency and throughput");
        performance_test.test_type = DETAILED;
        detailed_tests.add (performance_test);
    }
    
    private void on_run_diagnostics_clicked () {
        var dialog = new KeyMaker.ConnectionDiagnosticsDialog (get_root () as Gtk.Window);
        dialog.present (get_root () as Gtk.Window);
    }
    
    public void refresh_diagnostics_data () {
        refresh_quick_tests_display ();
        refresh_detailed_tests_display ();
        refresh_test_history_display ();
    }
    
    private void refresh_quick_tests_display () {
        // Clear current display
        var child = quick_tests_group.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            if (child is Adw.ActionRow) {
                quick_tests_group.remove (child);
            }
            child = next;
        }
        
        // Add quick tests to display
        for (int i = 0; i < quick_tests.length; i++) {
            var test = quick_tests[i];
            var row = create_quick_test_row (test);
            quick_tests_group.add (row);
        }
    }
    
    private void refresh_detailed_tests_display () {
        // Clear current display
        var child = detailed_diagnostics_group.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            if (child is Adw.ActionRow) {
                detailed_diagnostics_group.remove (child);
            }
            child = next;
        }
        
        // Add detailed tests to display
        for (int i = 0; i < detailed_tests.length; i++) {
            var test = detailed_tests[i];
            var row = create_detailed_test_row (test);
            detailed_diagnostics_group.add (row);
        }
    }
    
    private void refresh_test_history_display () {
        // Clear current display
        var child = test_history_group.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            if (child is Adw.ActionRow) {
                test_history_group.remove (child);
            }
            child = next;
        }
        
        if (test_history.length == 0) {
            var placeholder_row = new Adw.ActionRow ();
            placeholder_row.title = _("No test history available");
            placeholder_row.subtitle = _("Run diagnostics to see previous test results");
            placeholder_row.sensitive = false;
            
            var prefix_icon = new Gtk.Image ();
            prefix_icon.icon_name = "folder-documents-symbolic";
            prefix_icon.icon_size = Gtk.IconSize.LARGE;
            placeholder_row.add_prefix (prefix_icon);
            
            test_history_group.add (placeholder_row);
        } else {
            for (int i = 0; i < test_history.length; i++) {
                var result = test_history[i];
                var row = create_history_row (result);
                test_history_group.add (row);
            }
        }
    }
    
    private Adw.ActionRow create_quick_test_row (DiagnosticTest test) {
        var row = new Adw.ActionRow ();
        row.title = test.name;
        row.subtitle = test.description;
        
        // Add prefix icon
        var prefix_icon = new Gtk.Image ();
        prefix_icon.icon_name = "applications-system-symbolic";
        prefix_icon.icon_size = Gtk.IconSize.LARGE;
        row.add_prefix (prefix_icon);
        
        // Add run button
        var run_button = new Gtk.Button.from_icon_name ("media-playback-start-symbolic");
        run_button.tooltip_text = _("Run Test");
        run_button.add_css_class ("flat");
        run_button.add_css_class ("suggested-action");
        run_button.clicked.connect (() => on_run_quick_test_clicked (test));
        row.add_suffix (run_button);
        
        return row;
    }
    
    private Adw.ActionRow create_detailed_test_row (DiagnosticTest test) {
        var row = new Adw.ActionRow ();
        row.title = test.name;
        row.subtitle = test.description;
        
        // Add prefix icon
        var prefix_icon = new Gtk.Image ();
        prefix_icon.icon_name = "preferences-system-symbolic";
        prefix_icon.icon_size = Gtk.IconSize.LARGE;
        row.add_prefix (prefix_icon);
        
        // Add action buttons
        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        button_box.add_css_class ("linked");
        
        var run_button = new Gtk.Button.from_icon_name ("media-playback-start-symbolic");
        run_button.tooltip_text = _("Run Detailed Test");
        run_button.add_css_class ("flat");
        run_button.add_css_class ("suggested-action");
        run_button.clicked.connect (() => on_run_detailed_test_clicked (test));
        
        var configure_button = new Gtk.Button.from_icon_name ("preferences-other-symbolic");
        configure_button.tooltip_text = _("Configure Test");
        configure_button.add_css_class ("flat");
        configure_button.clicked.connect (() => on_configure_test_clicked (test));
        
        button_box.append (run_button);
        button_box.append (configure_button);
        row.add_suffix (button_box);
        
        return row;
    }
    
    private Adw.ActionRow create_history_row (DiagnosticResult result) {
        var row = new Adw.ActionRow ();
        row.title = result.test_name;
        row.subtitle = @"Execution time: $(result.execution_time_ms)ms";
        
        // Add prefix icon based on result
        var prefix_icon = new Gtk.Image ();
        switch (result.status) {
            case TestStatus.PASSED:
                prefix_icon.icon_name = "emblem-ok-symbolic";
                prefix_icon.add_css_class ("success");
                break;
            case TestStatus.WARNING:
                prefix_icon.icon_name = "dialog-warning-symbolic";
                prefix_icon.add_css_class ("warning");
                break;
            case TestStatus.FAILED:
                prefix_icon.icon_name = "dialog-error-symbolic";
                prefix_icon.add_css_class ("error");
                break;
            case TestStatus.SKIPPED:
                prefix_icon.icon_name = "media-skip-forward-symbolic";
                break;
        }
        prefix_icon.icon_size = Gtk.IconSize.LARGE;
        row.add_prefix (prefix_icon);
        
        // Add result status
        var status_label = new Gtk.Label ("");
        switch (result.status) {
            case TestStatus.PASSED:
                status_label.label = _("Passed");
                status_label.add_css_class ("success");
                break;
            case TestStatus.WARNING:
                status_label.label = _("Warning");
                status_label.add_css_class ("warning");
                break;
            case TestStatus.FAILED:
                status_label.label = _("Failed");
                status_label.add_css_class ("error");
                break;
            case TestStatus.SKIPPED:
                status_label.label = _("Skipped");
                status_label.add_css_class ("dim-label");
                break;
        }
        status_label.add_css_class ("caption");
        
        // Add view details button
        var details_button = new Gtk.Button.from_icon_name ("dialog-information-symbolic");
        details_button.tooltip_text = _("View Details");
        details_button.add_css_class ("flat");
        details_button.clicked.connect (() => on_view_result_details_clicked (result));
        
        var suffix_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        suffix_box.append (status_label);
        suffix_box.append (details_button);
        row.add_suffix (suffix_box);
        
        return row;
    }
    
    private void on_run_quick_test_clicked (DiagnosticTest test) {
        show_toast_requested (_("Running quick test: %s").printf (test.name));
        // This would run the actual test
    }
    
    private void on_run_detailed_test_clicked (DiagnosticTest test) {
        show_toast_requested (_("Running detailed test: %s").printf (test.name));
        // This would run the actual test
    }
    
    private void on_configure_test_clicked (DiagnosticTest test) {
        show_toast_requested (_("Test configuration not yet implemented"));
        // This would show test configuration options
    }
    
    private void on_view_result_details_clicked (DiagnosticResult result) {
        // Create a dummy history entry for now
        var dummy_entry = DiagnosticHistoryEntry ();
        var dialog = new KeyMaker.DiagnosticResultsViewDialog (get_root () as Gtk.Window, dummy_entry);
        dialog.present (get_root () as Gtk.Window);
    }
    
    public void add_test_result (DiagnosticResult result) {
        test_history.add (result);
        refresh_test_history_display ();
    }
}