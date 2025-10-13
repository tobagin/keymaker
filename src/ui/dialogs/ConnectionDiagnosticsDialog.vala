/*
 * SSHer - Connection Diagnostics Main Dialog
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
    private unowned Adw.ViewStack main_stack;
    
    [GtkChild]
    private unowned Adw.ViewSwitcher view_switcher;
    
    [GtkChild]
    private unowned Gtk.Button launch_diagnostics_button;
    
    // History tab elements
    [GtkChild]
    private unowned Gtk.ListBox history_list;
    
    [GtkChild]
    private unowned Gtk.Button refresh_history_button;
    
    [GtkChild]
    private unowned Gtk.Button clear_history_button;
    
    [GtkChild]
    private unowned Adw.ActionRow history_placeholder;
    
    private DiagnosticHistory diagnostic_history;

    public ConnectionDiagnosticsDialog (Gtk.Window parent) {
        Object ();
    }
    
    construct {
        debug ("ConnectionDiagnosticsDialog: Constructor called");
        diagnostic_history = new DiagnosticHistory ();
        
        // Initially disable clear button until we know if there's history
        if (clear_history_button != null) {
            clear_history_button.sensitive = false;
        }
        
        setup_signals ();
        // Load history asynchronously to avoid blocking UI
        load_history_list.begin ();
        debug ("ConnectionDiagnosticsDialog: Constructor completed");
    }
    
    private void setup_signals () {
        // Connect to history changed signal
        diagnostic_history.history_changed.connect (refresh_history_list);
        
        // Button signals
        if (launch_diagnostics_button != null) {
            launch_diagnostics_button.clicked.connect (on_launch_diagnostics);
        }
        
        if (refresh_history_button != null) {
            refresh_history_button.clicked.connect (on_refresh_history);
        }
        
        if (clear_history_button != null) {
            clear_history_button.clicked.connect (on_clear_history);
        }
        
        if (history_list != null) {
            history_list.row_activated.connect (on_history_row_activated);
        }
    }
    
    private void on_launch_diagnostics () {
        var runner_dialog = new ConnectionDiagnosticsRunnerDialog (this.get_root () as Gtk.Window, diagnostic_history, true);
        
        // Connect to completion signal to refresh history
        runner_dialog.diagnostic_completed.connect ((target, options, results) => {
            // History is automatically updated through the diagnostic_history object
            // The signal connection will refresh our display
        });
        
        runner_dialog.present (this);
    }
    
    private void on_refresh_history () {
        // NO MOCK DATA - Just refresh the actual history
        load_history_list.begin ();
    }
    
    private void on_clear_history () {
        var dialog = new Adw.AlertDialog (
            _("Clear History"),
            _("Are you sure you want to clear all diagnostic history? This action cannot be undone.")
        );
        dialog.add_response ("cancel", _("Cancel"));
        dialog.add_response ("clear", _("Clear History"));
        dialog.set_response_appearance ("clear", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response ("cancel");
        
        dialog.response.connect ((response) => {
            if (response == "clear") {
                clear_history_backend ();
            }
        });
        
        dialog.present (this);
    }
    
    private void on_history_row_activated (Gtk.ListBoxRow row) {
        // Load configuration and launch diagnostics
        if (row != history_placeholder) {
            var index_ptr = row.get_data<void*> ("history-index");
            if (index_ptr != null) {
                uint index = (uint) index_ptr;
                var entry = diagnostic_history.get_entry (index);
                if (entry != null) {
                    var runner_dialog = new ConnectionDiagnosticsRunnerDialog (this.get_root () as Gtk.Window, diagnostic_history, false);
                    runner_dialog.load_configuration (entry);
                    runner_dialog.present (this);
                }
            }
        }
    }
    
    private void clear_history_backend () {
        // Clear the history backend - separate method to avoid recursion
        diagnostic_history.clear_history ();
        // Button will be disabled automatically when refresh_history_list is called via signal
    }
    
    private async void load_history_list () {
        if (diagnostic_history == null || history_list == null) {
            return;
        }
        
        // Load initial history
        refresh_history_list ();
    }
    
    private void refresh_history_list () {
        // Clear existing entries (except placeholder) - UI only, no backend
        var child = history_list.get_first_child ();
        while (child != null) {
            var next_child = child.get_next_sibling ();
            if (child != history_placeholder) {
                history_list.remove (child);
            }
            child = next_child;
        }
        
        var entries = diagnostic_history.get_entries ();
        
        if (entries.length == 0) {
            history_placeholder.visible = true;
            // Disable clear button when no history
            if (clear_history_button != null) {
                clear_history_button.sensitive = false;
            }
            return;
        }
        
        history_placeholder.visible = false;
        // Enable clear button when history exists
        if (clear_history_button != null) {
            clear_history_button.sensitive = true;
        }
        
        // Add history entries
        for (uint i = 0; i < entries.length; i++) {
            var entry = entries[i];
            var row = create_history_row (entry, i);
            history_list.insert (row, (int)i);
        }
    }
    
    private Adw.ActionRow create_history_row (DiagnosticHistoryEntry entry, uint index) {
        var row = new Adw.ActionRow ();
        
        // Format title: hostname@username:port
        var title = @"$(entry.username)@$(entry.hostname)";
        if (entry.port != 22) {
            title += @":$(entry.port)";
        }
        row.title = title;
        
        // Format subtitle with status and time
        var time_str = entry.timestamp.format ("%Y-%m-%d %H:%M");
        var tests_str = @"$(entry.passed_tests)/$(entry.total_tests) tests passed";
        row.subtitle = @"$(time_str) • $(tests_str)";
        
        // Add network status icon based on test results
        var status_icon = new Gtk.Image ();
        if (entry.passed_tests == entry.total_tests && entry.total_tests > 0) {
            // All tests passed
            status_icon.icon_name = "network-transmit-receive-symbolic";
            status_icon.add_css_class ("success");
        } else {
            // Some or all tests failed
            status_icon.icon_name = "network-offline-symbolic";
            status_icon.add_css_class ("error");
        }
        row.add_prefix (status_icon);
        
        // Create action buttons container
        var actions_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        
        // View Results button
        var view_button = new Gtk.Button () {
            icon_name = "view-reveal-symbolic",
            tooltip_text = _("View Results"),
            valign = Gtk.Align.CENTER
        };
        view_button.add_css_class ("flat");
        view_button.clicked.connect (() => on_view_results (entry, index));
        actions_box.append (view_button);
        
        // Download Results button
        var download_button = new Gtk.Button () {
            icon_name = "io.github.tobagin.keysmith-download-symbolic",
            tooltip_text = _("Download Results"),
            valign = Gtk.Align.CENTER
        };
        download_button.add_css_class ("flat");
        download_button.clicked.connect (() => on_download_results (entry, index));
        actions_box.append (download_button);
        
        // Remove Test button
        var remove_button = new Gtk.Button () {
            icon_name = "io.github.tobagin.keysmith-remove-symbolic",
            tooltip_text = _("Remove Test"),
            valign = Gtk.Align.CENTER
        };
        remove_button.add_css_class ("flat");
        remove_button.add_css_class ("destructive-action");
        remove_button.clicked.connect (() => on_remove_test (entry, index));
        actions_box.append (remove_button);
        
        row.add_suffix (actions_box);
        
        // Store the history index for later reference
        row.set_data ("history-index", index.to_pointer ());
        
        return row;
    }
    
    private void on_view_results (DiagnosticHistoryEntry entry, uint index) {
        debug ("View results for entry %u: %s@%s", index, entry.username, entry.hostname);
        
        var results_dialog = new DiagnosticResultsViewDialog (this.get_root () as Gtk.Window, entry);
        results_dialog.present (this);
    }
    
    private void on_download_results (DiagnosticHistoryEntry entry, uint index) {
        debug ("Download results for entry %u: %s@%s", index, entry.username, entry.hostname);
        
        var file_dialog = new Gtk.FileDialog () {
            title = _("Save Diagnostic Report"),
            initial_name = generate_report_filename (entry)
        };
        
        file_dialog.save.begin (this.get_root () as Gtk.Window, null, (obj, res) => {
            try {
                var file = file_dialog.save.end (res);
                generate_report_for_entry.begin (file, entry);
            } catch (Error e) {
                if (e.code != Gtk.DialogError.DISMISSED) {
                    show_error (_("Save Error"), e.message);
                }
            }
        });
    }
    
    private void on_remove_test (DiagnosticHistoryEntry entry, uint index) {
        var dialog = new Adw.AlertDialog (
            _("Remove Test"),
            @"Are you sure you want to remove the diagnostic test for $(entry.username)@$(entry.hostname)? This action cannot be undone."
        );
        dialog.add_response ("cancel", _("Cancel"));
        dialog.add_response ("remove", _("Remove"));
        dialog.set_response_appearance ("remove", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response ("cancel");
        
        dialog.response.connect ((response) => {
            if (response == "remove") {
                diagnostic_history.remove_entry (index);
            }
        });
        
        dialog.present (this);
    }
    
    private string generate_report_filename (DiagnosticHistoryEntry entry) {
        var timestamp_str = entry.timestamp != null ? entry.timestamp.format ("%Y%m%d_%H%M%S") : "unknown";
        var hostname = entry.hostname ?? "unknown";
        return @"ssh_diagnostic_$(hostname)_$(timestamp_str).txt";
    }
    
    private async void generate_report_for_entry (File file, DiagnosticHistoryEntry entry) {
        try {
            var report = generate_report_content_for_entry (entry);
            yield file.replace_contents_async (report.data, null, false, FileCreateFlags.REPLACE_DESTINATION, null, null);
        } catch (Error e) {
            show_error (_("Save Error"), @"Failed to save report: $(e.message)");
        }
    }
    
    private string generate_report_content_for_entry (DiagnosticHistoryEntry entry) {
        var builder = new StringBuilder ();
        var timestamp_str = entry.timestamp != null ? entry.timestamp.format ("%Y-%m-%d %H:%M:%S") : "Unknown";
        
        builder.append ("SSH Connection Diagnostic Report\n");
        builder.append ("====================================\n\n");
        builder.append (@"Generated: $(timestamp_str)\n");
        builder.append (@"Target: $(entry.username ?? "unknown")@$(entry.hostname ?? "unknown"):$(entry.port)\n");
        builder.append (@"Authentication: $(entry.auth_method ?? "Unknown")\n");
        if (entry.key_file != null) {
            builder.append (@"Key File: $(entry.key_file)\n");
        }
        builder.append (@"\nTest Results:\n");
        builder.append (@"-------------\n");
        
        // Use actual saved test results if available
        DiagnosticHistory history = new DiagnosticHistory();
        var saved_results = history.deserialize_test_results(entry.test_results_json);
        
        if (saved_results != null && saved_results.length > 0) {
            // Use real test results - NO MOCK DATA
            for (uint i = 0; i < saved_results.length; i++) {
                var result = saved_results[i];
                builder.append (@"$(result.test_name): $(result.status) ($(result.execution_time_ms)ms)\n");
                if (result.details != null && result.details.length > 0) {
                    builder.append (@"  Details: $(result.details)\n");
                }
                builder.append ("\n");
            }
        } else {
            // NO MOCK DATA - Just indicate that detailed results are not available
            builder.append ("Detailed test results are not available for this entry.\n");
            builder.append (@"Summary: $(entry.passed_tests) of $(entry.total_tests) tests passed\n");
        }
        
        return builder.str;
    }
    
    private int estimate_test_time (string test_name) {
        // Provide realistic execution time estimates based on test type
        if ("Basic Connection Test" in test_name) return Random.int_range (100, 300);
        if ("DNS Resolution Test" in test_name) return Random.int_range (5, 50);
        if ("Protocol Detection Test" in test_name) return Random.int_range (10, 100);
        if ("Performance Test" in test_name) return Random.int_range (500, 2000);
        if ("Tunnel Capabilities Test" in test_name) return Random.int_range (50, 200);
        if ("Permission Verification Test" in test_name) return Random.int_range (20, 150);
        
        return Random.int_range (10, 200); // Default range
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
}