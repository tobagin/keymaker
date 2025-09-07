/*
 * Key Maker - Diagnostic Results View Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {

private struct TestInfo {
    public string name;
    public string description;
}

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/diagnostic_results_view_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/diagnostic_results_view_dialog.ui")]
#endif
public class DiagnosticResultsViewDialog : Adw.Dialog {
    
    [GtkChild]
    private unowned Adw.WindowTitle results_title;
    
    // Info group elements
    [GtkChild]
    private unowned Adw.ActionRow hostname_row;
    
    [GtkChild]
    private unowned Adw.ActionRow timestamp_row;
    
    [GtkChild]
    private unowned Adw.ActionRow auth_method_row;
    
    [GtkChild]
    private unowned Adw.ActionRow execution_time_row;
    
    // Results list
    [GtkChild]
    private unowned Gtk.ListBox results_list;
    
    [GtkChild]
    private unowned Adw.ActionRow results_placeholder;
    
    // Summary elements
    [GtkChild]
    private unowned Adw.ActionRow total_tests_row;
    
    [GtkChild]
    private unowned Adw.ActionRow passed_tests_row;
    
    [GtkChild]
    private unowned Adw.ActionRow failed_tests_row;
    
    [GtkChild]
    private unowned Adw.ActionRow overall_status_row;
    
    [GtkChild]
    private unowned Gtk.Image overall_status_icon;
    
    private DiagnosticHistoryEntry entry;
    
    public DiagnosticResultsViewDialog (Gtk.Window parent, DiagnosticHistoryEntry history_entry) {
        Object ();
        entry = history_entry;
        debug ("DiagnosticResultsViewDialog: Created with entry for %s@%s (tests: %d, passed: %d)", entry.username, entry.hostname, entry.total_tests, entry.passed_tests);
    }
    
    construct {
        debug ("DiagnosticResultsViewDialog: construct() called");
        try {
            // First test basic UI element access
            if (hostname_row == null) critical ("hostname_row is NULL");
            if (timestamp_row == null) critical ("timestamp_row is NULL");
            if (auth_method_row == null) critical ("auth_method_row is NULL");
            
            setup_content ();
            debug ("DiagnosticResultsViewDialog: setup_content completed");
            populate_test_results ();
            debug ("DiagnosticResultsViewDialog: populate_test_results completed");
            
        } catch (Error e) {
            critical ("Error in construct: %s", e.message);
        }
        debug ("DiagnosticResultsViewDialog: construct() completed");
    }
    
    private void setup_content () {
        debug ("DiagnosticResultsViewDialog: setup_content() called");
        debug ("Entry data - hostname: %s, username: %s, port: %d, total_tests: %d", 
              entry.hostname, entry.username, entry.port, entry.total_tests);
        
        // Update title
        var target_display = @"$(entry.username)@$(entry.hostname)";
        if (entry.port != 22) {
            target_display += @":$(entry.port)";
        }
        results_title.title = @"Results: $(target_display)";  
        debug ("Set title to: %s", results_title.title);
        
        // Debug: Check if UI elements are properly connected
        debug ("UI elements check:");
        debug ("  results_title: %s", results_title != null ? "connected" : "NULL");
        debug ("  hostname_row: %s", hostname_row != null ? "connected" : "NULL");
        debug ("  timestamp_row: %s", timestamp_row != null ? "connected" : "NULL");
        debug ("  auth_method_row: %s", auth_method_row != null ? "connected" : "NULL");
        debug ("  total_tests_row: %s", total_tests_row != null ? "connected" : "NULL");
        debug ("  results_list: %s", results_list != null ? "connected" : "NULL");
        
        // Populate info group
        debug ("Setting hostname_row subtitle to: %s", target_display);
        if (hostname_row != null) {
            hostname_row.subtitle = target_display;
            debug ("hostname_row subtitle set successfully");
        } else {
            critical ("hostname_row is null!");
        }
        
        var timestamp_str = entry.timestamp != null ? entry.timestamp.format ("%Y-%m-%d %H:%M:%S") : "Unknown";
        debug ("Setting timestamp_row subtitle to: %s", timestamp_str);
        if (timestamp_row != null) {
            timestamp_row.subtitle = timestamp_str;
            debug ("timestamp_row subtitle set successfully");
        } else {
            critical ("timestamp_row is null!");
        }
        
        // Show authentication method with key info
        var auth_display = entry.auth_method ?? "Unknown";
        if (entry.key_file != null) {
            var key_name = Path.get_basename (entry.key_file);
            // Remove common extensions for cleaner display
            if (key_name.has_suffix (".pub")) {
                key_name = key_name[0:-4];
            } else if (key_name.has_suffix ("_rsa") || key_name.has_suffix ("_ed25519") || key_name.has_suffix ("_ecdsa")) {
                // Keep as is for key type identification
            }
            auth_display += @" ($(key_name))";
        }
        debug ("Setting auth_method_row subtitle to: %s", auth_display);
        if (auth_method_row != null) {
            auth_method_row.subtitle = auth_display;
            debug ("auth_method_row subtitle set successfully");
        } else {
            critical ("auth_method_row is null!");
        }
        
        // Show execution time
        var time_display = @"$(entry.execution_time_ms)ms";
        if (entry.execution_time_ms > 1000) {
            var seconds = entry.execution_time_ms / 1000.0;
            time_display += @" (~$(@"%.1f".printf(seconds))s)";
        }
        if (execution_time_row != null) {
            execution_time_row.subtitle = time_display;
            debug ("execution_time_row subtitle set to: %s", time_display);
        } else {
            critical ("execution_time_row is null!");
        }
        
        // Populate summary
        var total_text = @"$(entry.total_tests) test$(entry.total_tests != 1 ? "s" : "")";
        var passed_text = @"$(entry.passed_tests) test$(entry.passed_tests != 1 ? "s" : "")";
        var failed_text = @"$(entry.failed_tests) test$(entry.failed_tests != 1 ? "s" : "")";
        var success_rate = entry.total_tests > 0 ? (entry.passed_tests * 100) / entry.total_tests : 0;
        var status_display = entry.overall_status ?? "Unknown";
        var status_text = @"$(status_display) ($(success_rate)% success rate)";
        
        if (total_tests_row != null) {
            total_tests_row.subtitle = total_text;
            debug ("total_tests_row subtitle set to: %s", total_text);
        }
        if (passed_tests_row != null) {
            passed_tests_row.subtitle = passed_text;
            debug ("passed_tests_row subtitle set to: %s", passed_text);
        }
        if (failed_tests_row != null) {
            failed_tests_row.subtitle = failed_text;
            debug ("failed_tests_row subtitle set to: %s", failed_text);
        }
        if (overall_status_row != null) {
            overall_status_row.subtitle = status_text;
            debug ("overall_status_row subtitle set to: %s", status_text);
        }
        
        // Set overall status icon
        if (entry.passed_tests == entry.total_tests && entry.total_tests > 0) {
            overall_status_icon.icon_name = "network-transmit-receive-symbolic";
            overall_status_icon.add_css_class ("success");
            overall_status_icon.remove_css_class ("error");
            overall_status_icon.remove_css_class ("warning");
        } else if (entry.passed_tests > 0) {
            overall_status_icon.icon_name = "network-transmit-symbolic";
            overall_status_icon.add_css_class ("warning");
            overall_status_icon.remove_css_class ("success");
            overall_status_icon.remove_css_class ("error");
        } else {
            overall_status_icon.icon_name = "network-offline-symbolic";
            overall_status_icon.add_css_class ("error");
            overall_status_icon.remove_css_class ("success");
            overall_status_icon.remove_css_class ("warning");
        }
    }
    
    private void populate_test_results () {
        debug ("DiagnosticResultsViewDialog: populate_test_results() called");
        
        // Clear existing results except placeholder
        var child = results_list.get_first_child ();
        while (child != null) {
            var next_child = child.get_next_sibling ();
            if (child != results_placeholder) {
                results_list.remove (child);
            }
            child = next_child;
        }
        
        // Try to get saved test results first
        DiagnosticHistory history = new DiagnosticHistory();
        var saved_results = history.deserialize_test_results(entry.test_results_json);
        
        if (saved_results != null && saved_results.length > 0) {
            // Use actual saved test results
            debug ("Using %d saved test results", (int)saved_results.length);
            for (uint i = 0; i < saved_results.length; i++) {
                var result = saved_results[i];
                var test_name = result.test_name ?? "Unknown Test";
                var test_desc = result.details ?? "No description available";
                var passed = result.status == TestStatus.PASSED;
                debug ("Adding saved test row: %s (passed: %s, time: %dms)", test_name, passed.to_string(), result.execution_time_ms);
                add_saved_test_result_row (result);
            }
            results_placeholder.visible = false;
        } else {
            // Fallback to old method for backward compatibility
            debug ("No saved results found, using fallback method");
            var test_count = entry.total_tests;
            
            // Simple fallback: just show that tests were run based on boolean flags
            if (entry.test_basic) {
                add_fallback_test_result_row (_("Basic Connection Test") ?? "Basic Connection Test", 
                                            _("Test SSH connection and authentication") ?? "Test SSH connection and authentication", 
                                            entry.passed_tests > 0);
            }
            if (entry.test_dns) {
                add_fallback_test_result_row (_("DNS Resolution Test") ?? "DNS Resolution Test", 
                                            _("Resolve hostname to IP address") ?? "Resolve hostname to IP address", 
                                            entry.passed_tests > 0);
            }
            if (entry.test_protocol) {
                add_fallback_test_result_row (_("Protocol Detection Test") ?? "Protocol Detection Test", 
                                            _("Detect SSH protocol version and capabilities") ?? "Detect SSH protocol version and capabilities", 
                                            entry.passed_tests > 0);
            }
            if (entry.test_performance) {
                add_fallback_test_result_row (_("Performance Test") ?? "Performance Test", 
                                            _("Measure connection latency and throughput") ?? "Measure connection latency and throughput", 
                                            entry.passed_tests > 0);
            }
            if (entry.test_tunnels) {
                add_fallback_test_result_row (_("Tunnel Capabilities Test") ?? "Tunnel Capabilities Test", 
                                            _("Test port forwarding capabilities") ?? "Test port forwarding capabilities", 
                                            entry.passed_tests > 0);
            }
            if (entry.test_permissions) {
                add_fallback_test_result_row (_("Permission Verification Test") ?? "Permission Verification Test", 
                                            _("Verify user permissions and access") ?? "Verify user permissions and access", 
                                            entry.passed_tests > 0);
            }
            
            results_placeholder.visible = (test_count == 0);
        }
        
        debug ("populate_test_results() completed");
    }
    
    private void add_test_result_row (string test_name, string description, bool passed) {
        var row = new Adw.ActionRow () {
            title = test_name,
            subtitle = description
        };
        
        var status_icon = new Gtk.Image () {
            icon_size = Gtk.IconSize.NORMAL
        };
        
        if (passed) {
            status_icon.icon_name = "checkmark-symbolic";
            status_icon.add_css_class ("success");
        } else {
            status_icon.icon_name = "cross-symbolic";
            status_icon.add_css_class ("error");
        }
        
        row.add_prefix (status_icon);
        
        // Add estimated execution time based on test type
        var estimated_time = estimate_test_execution_time (test_name);
        var time_label = new Gtk.Label (@"~$(estimated_time)ms") {
            margin_start = 8
        };
        time_label.add_css_class ("dim-label");
        row.add_suffix (time_label);
        
        results_list.append (row);
    }
    
    private void add_saved_test_result_row (DiagnosticResult result) {
        var row = new Adw.ActionRow () {
            title = result.test_name ?? "Unknown Test",
            subtitle = result.details ?? "No description available"
        };
        
        var status_icon = new Gtk.Image () {
            icon_size = Gtk.IconSize.NORMAL
        };
        
        switch (result.status) {
            case TestStatus.PASSED:
                status_icon.icon_name = "checkmark-symbolic";
                status_icon.add_css_class ("success");
                break;
            case TestStatus.FAILED:
                status_icon.icon_name = "cross-symbolic";
                status_icon.add_css_class ("error");
                break;
            case TestStatus.WARNING:
                status_icon.icon_name = "warning-symbolic";
                status_icon.add_css_class ("warning");
                break;
            case TestStatus.SKIPPED:
                status_icon.icon_name = "minus-symbolic";
                status_icon.add_css_class ("dim-label");
                break;
        }
        
        row.add_prefix (status_icon);
        
        // Show actual execution time from saved data
        var time_label = new Gtk.Label (@"$(result.execution_time_ms)ms") {
            margin_start = 8
        };
        time_label.add_css_class ("dim-label");
        row.add_suffix (time_label);
        
        results_list.append (row);
    }
    
    private void add_fallback_test_result_row (string test_name, string description, bool passed) {
        var row = new Adw.ActionRow () {
            title = test_name,
            subtitle = description
        };
        
        var status_icon = new Gtk.Image () {
            icon_size = Gtk.IconSize.NORMAL
        };
        
        if (passed) {
            status_icon.icon_name = "checkmark-symbolic";
            status_icon.add_css_class ("success");
        } else {
            status_icon.icon_name = "cross-symbolic";
            status_icon.add_css_class ("error");
        }
        
        row.add_prefix (status_icon);
        
        // Use average time for fallback (no random data)
        var avg_time = entry.total_tests > 0 ? entry.execution_time_ms / entry.total_tests : 0;
        var time_label = new Gtk.Label (@"~$(avg_time)ms") {
            margin_start = 8
        };
        time_label.add_css_class ("dim-label");
        row.add_suffix (time_label);
        
        results_list.append (row);
    }
    
    private bool determine_test_result (uint test_index, uint total_tests) {
        // Distribute pass/fail results realistically based on overall statistics
        if (entry.failed_tests == 0) {
            return true; // All tests passed
        }
        if (entry.passed_tests == 0) {
            return false; // All tests failed
        }
        
        // For mixed results, distribute failures across tests
        // Basic connection test is most likely to fail first
        var failure_distribution = new bool[total_tests];
        
        // Start with all passing
        for (int i = 0; i < total_tests; i++) {
            failure_distribution[i] = true;
        }
        
        // Mark some as failed based on failed_tests count
        var failures_to_assign = (int) entry.failed_tests;
        
        // Priority order for failures (basic connection most likely to fail)
        var failure_priority = new string[] {
            _("Basic Connection Test"),
            _("DNS Resolution Test"), 
            _("Performance Test"),
            _("Permission Verification Test"),
            _("Protocol Detection Test"),
            _("Tunnel Capabilities Test")
        };
        
        // Assign failures based on priority and test presence
        for (int i = 0; i < failures_to_assign && i < total_tests; i++) {
            failure_distribution[i] = false;
        }
        
        return failure_distribution[test_index];
    }
    
    private int estimate_test_execution_time (string? test_name) {
        if (test_name == null) return Random.int_range (50, 300);
        
        // Provide realistic execution time estimates based on test type
        var basic_test = _("Basic Connection Test") ?? "Basic Connection Test";
        var dns_test = _("DNS Resolution Test") ?? "DNS Resolution Test";
        var protocol_test = _("Protocol Detection Test") ?? "Protocol Detection Test";
        var performance_test = _("Performance Test") ?? "Performance Test";
        var tunnel_test = _("Tunnel Capabilities Test") ?? "Tunnel Capabilities Test";
        var permission_test = _("Permission Verification Test") ?? "Permission Verification Test";
        
        if (basic_test in test_name) return Random.int_range (100, 300);
        if (dns_test in test_name) return Random.int_range (50, 150);
        if (protocol_test in test_name) return Random.int_range (80, 200);
        if (performance_test in test_name) return Random.int_range (500, 2000);
        if (tunnel_test in test_name) return Random.int_range (200, 600);
        if (permission_test in test_name) return Random.int_range (100, 400);
        
        return Random.int_range (50, 300); // Default range
    }
}

}