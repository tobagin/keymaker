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
    private unowned Gtk.Button add_diagnostic_button;
    [GtkChild]
    private unowned Gtk.Button run_all_diagnostics_button;
    [GtkChild]
    private unowned Gtk.Button refresh_diagnostics_button;
    [GtkChild]
    private unowned Gtk.Button clear_all_diagnostics_button;
    [GtkChild]
    private unowned Gtk.ListBox diagnostics_list;
    [GtkChild]
    private unowned Adw.ActionRow diagnostics_placeholder;
    [GtkChild]
    private unowned Gtk.Button refresh_history_button;
    [GtkChild]
    private unowned Gtk.Button clear_history_button;
    [GtkChild]
    private unowned Gtk.ListBox history_list;
    [GtkChild]
    private unowned Adw.ActionRow history_placeholder;
    
    private GenericArray<DiagnosticEntry> active_diagnostics;
    private GenericArray<DiagnosticEntry> history_entries;
    private DiagnosticHistory? history_manager;
    
    // Signals for window integration
    public signal void show_toast_requested (string message);
    
    construct {
        active_diagnostics = new GenericArray<DiagnosticEntry>();
        history_entries = new GenericArray<DiagnosticEntry>();
        
        // Initialize history manager
        history_manager = new DiagnosticHistory();
        history_manager.history_changed.connect(() => {
            // Reload history when it's available
            load_history_from_manager_silent();
        });
        
        // Setup button signals
        add_diagnostic_button.clicked.connect(on_add_diagnostic_clicked);
        run_all_diagnostics_button.clicked.connect(on_run_all_diagnostics_clicked);
        refresh_diagnostics_button.clicked.connect(on_refresh_diagnostics_clicked);
        clear_all_diagnostics_button.clicked.connect(on_clear_all_diagnostics_clicked);
        refresh_history_button.clicked.connect(on_refresh_history_clicked);
        clear_history_button.clicked.connect(on_clear_history_clicked);
        
        // Load saved data
        load_diagnostics_data();
        refresh_displays();
    }
    
    private void on_add_diagnostic_clicked() {
        var config_dialog = new KeyMaker.DiagnosticConfigurationDialog();
        config_dialog.configuration_created.connect((config, auto_run) => {
            var entry = new DiagnosticEntry(config);
            active_diagnostics.add(entry);
            save_diagnostics_data();
            if (auto_run || SettingsManager.get_auto_run_diagnostics()) {
                start_diagnostic(entry);
            }
            refresh_displays();
            show_toast_requested(_("Diagnostic '%s' created").printf(entry.get_display_name()));
        });
        config_dialog.present(get_root() as Gtk.Widget);
    }
    
    private void on_run_all_diagnostics_clicked() {
        uint running_count = 0;
        for (uint i = 0; i < active_diagnostics.length; i++) {
            var entry = active_diagnostics[i];
            if (entry.state == DiagnosticState.PENDING) {
                start_diagnostic(entry);
                running_count++;
            }
        }
        
        if (running_count > 0) {
            show_toast_requested(_("Started %u diagnostic tests").printf(running_count));
        } else {
            show_toast_requested(_("No pending diagnostics to run"));
        }
    }
    
    private void on_refresh_diagnostics_clicked() {
        load_diagnostics_data();
        refresh_displays();
        show_toast_requested(_("Diagnostics refreshed"));
    }
    
    private void on_clear_all_diagnostics_clicked() {
        if (active_diagnostics.length == 0) {
            show_toast_requested(_("No diagnostics to clear"));
            return;
        }
        
        var dialog = new Adw.AlertDialog(
            _("Clear All Diagnostics"),
            _("This will remove all pending diagnostics. Running diagnostics will be cancelled.")
        );
        
        dialog.add_response("cancel", _("Cancel"));
        dialog.add_response("clear", _("Clear All"));
        dialog.set_response_appearance("clear", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response("cancel");
        dialog.set_close_response("cancel");
        
        dialog.response.connect((response) => {
            if (response == "clear") {
                // Cancel any running diagnostics
                for (uint i = 0; i < active_diagnostics.length; i++) {
                    var entry = active_diagnostics[i];
                    if (entry.is_running()) {
                        entry.cancel(_("Cleared by user"));
                    }
                }
                
                // Clear all diagnostics
                active_diagnostics.remove_range(0, active_diagnostics.length);
                save_diagnostics_data();
                refresh_displays();
                show_toast_requested(_("All diagnostics cleared"));
            }
        });
        
        dialog.present(get_root() as Gtk.Window);
    }
    
    private void start_diagnostic(DiagnosticEntry entry) {
        entry.start();
        
        // Start the actual diagnostic process
        run_diagnostic_async.begin(entry, (obj, res) => {
            try {
                run_diagnostic_async.end(res);
            } catch (Error e) {
                warning("Diagnostic failed: %s", e.message);
                entry.fail(e.message);
                refresh_displays();
            }
        });
        
        refresh_displays();
        show_toast_requested(_("Starting diagnostic '%s'").printf(entry.get_display_name()));
    }
    
    private async void run_diagnostic_async(DiagnosticEntry entry) throws Error {
        var diagnostics_engine = new ConnectionDiagnostics();
        
        // Create diagnostic target from configuration
        var target = new DiagnosticTarget();
        target.hostname = entry.config.hostname;
        target.username = entry.config.username;
        target.port = entry.config.port;
        
        // Set authentication details based on method
        if (entry.config.auth_method == "key" && entry.config.ssh_key_path != "") {
            target.key_file = entry.config.ssh_key_path;
        } else if (entry.config.auth_method == "password") {
            target.password = entry.config.password;
        }
        
        // Create diagnostic options
        var options = new DiagnosticOptions();
        options.test_basic_connection = entry.config.test_basic_connection;
        options.test_dns_resolution = entry.config.test_dns_resolution;
        options.test_protocol_detection = entry.config.test_protocol_detection;
        options.test_performance = entry.config.test_performance;
        options.test_tunnel_capabilities = entry.config.test_tunnel_capabilities;
        options.test_permissions = entry.config.test_permissions;
        
        try {
            // Connect to progress updates
            diagnostics_engine.diagnostic_test_completed.connect((result) => {
                // Update progress - this would need to be more sophisticated
                // in a real implementation
                if (entry.is_running()) {
                    entry.progress_percentage += 20; // Rough estimate
                    entry.current_operation = result.test_name;
                    
                    Idle.add(() => {
                        refresh_displays();
                        return false;
                    });
                }
            });
            
            // Run the diagnostics - results come via signals
            var results = new GenericArray<DiagnosticResult>();
            
            // Store results from signal emissions
            ulong signal_id = diagnostics_engine.diagnostic_test_completed.connect((result) => {
                results.add(result);
            });
            
            yield diagnostics_engine.run_diagnostics(target, options);
            
            // Disconnect signal
            diagnostics_engine.disconnect(signal_id);
            
            if (entry.is_running()) {
                entry.complete(results);
                move_to_history(entry);
                
                // Save to history
                if (history_manager != null) {
                    try {
                        var history_target = new DiagnosticTarget();
                        history_target.hostname = entry.config.hostname;
                        history_target.username = entry.config.username;
                        history_target.port = entry.config.port;
                        
                        // Set authentication details based on method
                        if (entry.config.auth_method == "key" && entry.config.ssh_key_path != "") {
                            history_target.key_file = entry.config.ssh_key_path;
                        } else if (entry.config.auth_method == "password") {
                            history_target.password = entry.config.password;
                        }
                        
                        var history_options = new DiagnosticOptions();
                        history_options.test_basic_connection = entry.config.test_basic_connection;
                        history_options.test_dns_resolution = entry.config.test_dns_resolution;
                        history_options.test_protocol_detection = entry.config.test_protocol_detection;
                        history_options.test_performance = entry.config.test_performance;
                        history_options.test_tunnel_capabilities = entry.config.test_tunnel_capabilities;
                        history_options.test_permissions = entry.config.test_permissions;
                        
                        history_manager.add_entry_with_auth_method(history_target, history_options, results, entry.started_at, entry.config.auth_method, entry.config.name);
                    } catch (Error e) {
                        warning("Failed to save diagnostic history: %s", e.message);
                    }
                }
                
                Idle.add(() => {
                    refresh_displays();
                    show_toast_requested(_("Diagnostic '%s' completed").printf(entry.get_display_name()));
                    return false;
                });
            }
        } catch (Error e) {
            if (entry.is_running()) {
                entry.fail(e.message);
                move_to_history(entry);
                
                Idle.add(() => {
                    refresh_displays();
                    show_toast_requested(_("Diagnostic '%s' failed: %s").printf(entry.get_display_name(), e.message));
                    return false;
                });
            }
            throw e;
        }
    }
    
    private void cancel_diagnostic(DiagnosticEntry entry) {
        if (entry.is_running()) {
            entry.cancel(_("Cancelled by user"));
            move_to_history(entry);
            refresh_displays();
            show_toast_requested(_("Diagnostic '%s' cancelled").printf(entry.get_display_name()));
        }
    }
    
    private void move_to_history(DiagnosticEntry entry) {
        // Remove from active diagnostics
        for (uint i = 0; i < active_diagnostics.length; i++) {
            if (active_diagnostics[i] == entry) {
                active_diagnostics.remove_index(i);
                break;
            }
        }
        
        // Add to history
        history_entries.add(entry);
        save_diagnostics_data();
    }
    
    private void on_refresh_history_clicked() {
        load_history_from_manager();
    }
    
    private void load_history_from_manager() {
        load_history_from_manager_internal(true);
    }
    
    private void load_history_from_manager_silent() {
        load_history_from_manager_internal(false);
    }
    
    private void load_history_from_manager_internal(bool show_toast) {
        if (history_manager == null) return;
        
        try {
            var entries = history_manager.get_entries();
            
            // Convert history entries to diagnostic entries for display
            history_entries.remove_range(0, history_entries.length);
            
            for (uint i = 0; i < entries.length; i++) {
                var history_entry = entries[i];
                
                // Create a diagnostic config from the history entry
                var config = new DiagnosticConfiguration();
                config.name = history_entry.name != "" ? history_entry.name : @"$(history_entry.username)@$(history_entry.hostname)";
                config.hostname = history_entry.hostname;
                config.username = history_entry.username;
                config.port = history_entry.port;
                config.auth_method = history_entry.auth_method ?? "key";
                
                var entry = new DiagnosticEntry(config);
                entry.started_at = history_entry.timestamp;
                entry.completed_at = history_entry.timestamp;
                
                // Deserialize test results if available
                if (history_entry.test_results_json != null) {
                    entry.results = history_manager.deserialize_test_results(history_entry.test_results_json);
                }
                
                // Determine state based on test results
                if (entry.results != null && entry.results.length > 0) {
                    bool has_failures = false;
                    for (int j = 0; j < entry.results.length; j++) {
                        var result = entry.results[j];
                        if (result.status == TestStatus.FAILED) {
                            has_failures = true;
                            break;
                        }
                    }
                    entry.state = has_failures ? DiagnosticState.FAILED : DiagnosticState.COMPLETED;
                } else {
                    // No results available, assume completed
                    entry.state = DiagnosticState.COMPLETED;
                }
                
                history_entries.add(entry);
            }
            
            refresh_displays();
            if (show_toast) {
                show_toast_requested(_("History refreshed"));
            }
        } catch (Error e) {
            warning("Failed to load history: %s", e.message);
            if (show_toast) {
                show_toast_requested(_("Failed to refresh history: %s").printf(e.message));
            }
        }
    }
    
    private void on_clear_history_clicked() {
        var dialog = new Adw.AlertDialog(
            _("Clear All History"),
            _("This will permanently delete all diagnostic history. This action cannot be undone.")
        );
        
        dialog.add_response("cancel", _("Cancel"));
        dialog.add_response("clear", _("Clear All"));
        dialog.set_response_appearance("clear", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response("cancel");
        dialog.set_close_response("cancel");
        
        dialog.response.connect((response) => {
            if (response == "clear") {
                clear_all_history();
            }
        });
        
        dialog.present(get_root() as Gtk.Window);
    }
    
    private void clear_all_history() {
        history_entries.remove_range(0, history_entries.length);
        
        if (history_manager != null) {
            history_manager.clear_history();
        }
        
        save_diagnostics_data();
        refresh_displays();
        show_toast_requested(_("Diagnostic history cleared"));
    }
    
    private void refresh_displays() {
        refresh_diagnostics_display();
        refresh_history_display();
    }
    
    private void refresh_diagnostics_display() {
        // Clear current display (except placeholder)
        var child = diagnostics_list.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            if (child != diagnostics_placeholder) {
                diagnostics_list.remove(child);
            }
            child = next;
        }
        
        // Show/hide placeholder and add diagnostics
        if (active_diagnostics.length == 0) {
            diagnostics_placeholder.visible = true;
        } else {
            diagnostics_placeholder.visible = false;
            
            for (uint i = 0; i < active_diagnostics.length; i++) {
                var entry = active_diagnostics[i];
                var row = create_diagnostic_row(entry);
                diagnostics_list.append(row);
            }
        }
    }
    
    private void refresh_history_display() {
        // Clear current display (except placeholder)
        var child = history_list.get_first_child();
        while (child != null) {
            var next = child.get_next_sibling();
            if (child != history_placeholder) {
                history_list.remove(child);
            }
            child = next;
        }
        
        // Show/hide placeholder and add history
        if (history_entries.length == 0) {
            history_placeholder.visible = true;
        } else {
            history_placeholder.visible = false;
            
            for (uint i = 0; i < history_entries.length; i++) {
                var entry = history_entries[i];
                var row = create_history_row(entry);
                history_list.append(row);
            }
        }
    }
    
    private Adw.ActionRow create_diagnostic_row(DiagnosticEntry entry) {
        var row = new Adw.ActionRow();
        row.title = entry.get_display_name();
        
        // Set subtitle based on state
        switch (entry.state) {
            case DiagnosticState.PENDING:
                row.subtitle = _("Ready to run");
                break;
            case DiagnosticState.RUNNING:
                row.subtitle = @"$(entry.current_operation) ($(entry.progress_percentage)%)";
                break;
            default:
                row.subtitle = entry.config.description;
                break;
        }
        
        // Add prefix icon based on state
        var prefix_icon = new Gtk.Image();
        switch (entry.state) {
            case DiagnosticState.PENDING:
                prefix_icon.icon_name = "io.github.tobagin.keysmith-diagnostics-symbolic";
                break;
            case DiagnosticState.RUNNING:
                prefix_icon.icon_name = "io.github.tobagin.keysmith-diagnostics-symbolic";
                prefix_icon.add_css_class("accent");
                break;
            default:
                prefix_icon.icon_name = "io.github.tobagin.keysmith-diagnostics-symbolic";
                break;
        }
        row.add_prefix(prefix_icon);
        
        // Add suffix controls based on state
        var suffix_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        
        if (entry.state == DiagnosticState.PENDING) {
            // Run, View Parameters, Edit, Remove buttons
            var run_button = new Gtk.Button.from_icon_name("media-playback-start-symbolic");
            run_button.tooltip_text = _("Run Diagnostic");
            run_button.valign = Gtk.Align.CENTER;
            run_button.add_css_class("flat");
            run_button.clicked.connect(() => start_diagnostic(entry));
            
            var view_params_button = new Gtk.Button.from_icon_name("help-about-symbolic");
            view_params_button.tooltip_text = _("View Parameters");
            view_params_button.valign = Gtk.Align.CENTER;
            view_params_button.add_css_class("flat");
            view_params_button.clicked.connect(() => view_parameters(entry));
            
            var edit_button = new Gtk.Button.from_icon_name("document-edit-symbolic");
            edit_button.tooltip_text = _("Edit Configuration");
            edit_button.valign = Gtk.Align.CENTER;
            edit_button.add_css_class("flat");
            edit_button.clicked.connect(() => edit_diagnostic(entry));
            
            var remove_button = new Gtk.Button.from_icon_name("io.github.tobagin.keysmith-remove-symbolic");
            remove_button.tooltip_text = _("Remove Diagnostic");
            remove_button.valign = Gtk.Align.CENTER;
            remove_button.add_css_class("flat");
            remove_button.add_css_class("destructive-action");
            remove_button.clicked.connect(() => remove_diagnostic(entry));
            
            suffix_box.append(run_button);
            suffix_box.append(view_params_button);
            suffix_box.append(edit_button);
            suffix_box.append(remove_button);
        } else if (entry.state == DiagnosticState.RUNNING) {
            // Progress bar and cancel button
            var progress_bar = new Gtk.ProgressBar();
            progress_bar.fraction = entry.progress_percentage / 100.0;
            progress_bar.hexpand = true;
            progress_bar.valign = Gtk.Align.CENTER;
            progress_bar.width_request = 150;
            
            var cancel_button = new Gtk.Button.from_icon_name("process-stop-symbolic");
            cancel_button.tooltip_text = _("Cancel Diagnostic");
            cancel_button.valign = Gtk.Align.CENTER;
            cancel_button.add_css_class("flat");
            cancel_button.add_css_class("destructive-action");
            cancel_button.clicked.connect(() => cancel_diagnostic(entry));
            
            suffix_box.append(progress_bar);
            suffix_box.append(cancel_button);
        }
        
        row.add_suffix(suffix_box);
        return row;
    }
    
    private Adw.ActionRow create_history_row(DiagnosticEntry entry) {
        var row = new Adw.ActionRow();
        row.title = entry.get_display_name();
        
        // Format date and status
        string date_str = "";
        if (entry.completed_at != null) {
            date_str = entry.completed_at.format("%Y-%m-%d %H:%M");
        }
        
        string status_str = "";
        switch (entry.state) {
            case DiagnosticState.COMPLETED:
                status_str = _("Completed");
                break;
            case DiagnosticState.CANCELLED:
                status_str = _("Cancelled");
                break;
            case DiagnosticState.FAILED:
                status_str = _("Failed");
                break;
            default:
                status_str = _("Unknown");
                break;
        }
        
        row.subtitle = @"$(status_str) • $(date_str)";
        
        // Add prefix icon and styling based on state
        var prefix_icon = new Gtk.Image();
        switch (entry.state) {
            case DiagnosticState.COMPLETED:
                prefix_icon.icon_name = "io.github.tobagin.keysmith-diagnostics-symbolic";
                prefix_icon.add_css_class("success");
                break;
            case DiagnosticState.CANCELLED:
                prefix_icon.icon_name = "io.github.tobagin.keysmith-diagnostics-symbolic";
                prefix_icon.add_css_class("warning");
                break;
            case DiagnosticState.FAILED:
                prefix_icon.icon_name = "io.github.tobagin.keysmith-diagnostics-symbolic";
                prefix_icon.add_css_class("error");
                break;
            default:
                prefix_icon.icon_name = "io.github.tobagin.keysmith-diagnostics-symbolic";
                break;
        }
        row.add_prefix(prefix_icon);
        
        // Add suffix buttons
        var suffix_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        
        var run_again_button = new Gtk.Button.from_icon_name("io.github.tobagin.keysmith-rerun-symbolic");
        run_again_button.tooltip_text = _("Run Again");
        run_again_button.valign = Gtk.Align.CENTER;
        run_again_button.add_css_class("flat");
        run_again_button.clicked.connect(() => run_again_from_history(entry));
        
        var view_params_button = new Gtk.Button.from_icon_name("help-about-symbolic");
        view_params_button.tooltip_text = _("View Parameters");
        view_params_button.valign = Gtk.Align.CENTER;
        view_params_button.add_css_class("flat");
        view_params_button.clicked.connect(() => view_parameters(entry));
        
        // Create individual report action buttons
        var view_report_button = new Gtk.Button.from_icon_name("view-reveal-symbolic");
        view_report_button.tooltip_text = _("View Report");
        view_report_button.valign = Gtk.Align.CENTER;
        view_report_button.add_css_class("flat");
        view_report_button.clicked.connect(() => view_report(entry));
        
        var download_report_button = new Gtk.Button.from_icon_name("io.github.tobagin.keysmith-download-symbolic");
        download_report_button.tooltip_text = _("Download Report");
        download_report_button.valign = Gtk.Align.CENTER;
        download_report_button.add_css_class("flat");
        download_report_button.clicked.connect(() => download_report(entry));
        
        var print_report_button = new Gtk.Button.from_icon_name("printer-symbolic");
        print_report_button.tooltip_text = _("Print Report");
        print_report_button.valign = Gtk.Align.CENTER;
        print_report_button.add_css_class("flat");
        print_report_button.clicked.connect(() => print_report(entry));
        
        var remove_button = new Gtk.Button.from_icon_name("io.github.tobagin.keysmith-remove-symbolic");
        remove_button.tooltip_text = _("Remove from History");
        remove_button.valign = Gtk.Align.CENTER;
        remove_button.add_css_class("flat");
        remove_button.add_css_class("destructive-action");
        remove_button.clicked.connect(() => remove_from_history(entry));
        
        suffix_box.append(run_again_button);
        suffix_box.append(view_params_button);
        suffix_box.append(view_report_button);
        suffix_box.append(download_report_button);
        suffix_box.append(print_report_button);
        suffix_box.append(remove_button);
        
        row.add_suffix(suffix_box);
        return row;
    }
    
    private void edit_diagnostic(DiagnosticEntry entry) {
        var config_dialog = new KeyMaker.DiagnosticConfigurationDialog();
        
        // Pre-populate the dialog with existing configuration
        config_dialog.populate_from_config(entry.config);
        
        config_dialog.configuration_created.connect((config, auto_run) => {
            entry.config = config;
            save_diagnostics_data();
            refresh_displays();
            show_toast_requested(_("Diagnostic '%s' updated").printf(entry.get_display_name()));
            
            if (auto_run && entry.state == DiagnosticState.PENDING) {
                start_diagnostic(entry);
            }
        });
        
        config_dialog.present(get_root() as Gtk.Widget);
    }
    
    private void remove_diagnostic(DiagnosticEntry entry) {
        for (uint i = 0; i < active_diagnostics.length; i++) {
            if (active_diagnostics[i] == entry) {
                active_diagnostics.remove_index(i);
                break;
            }
        }
        
        save_diagnostics_data();
        refresh_displays();
        show_toast_requested(_("Diagnostic '%s' removed").printf(entry.get_display_name()));
    }
    
    private void run_again_from_history(DiagnosticEntry history_entry) {
        var new_entry = new DiagnosticEntry(history_entry.config);
        active_diagnostics.add(new_entry);
        
        if (SettingsManager.get_auto_run_diagnostics()) {
            start_diagnostic(new_entry);
        }
        
        save_diagnostics_data();
        refresh_displays();
        show_toast_requested(_("Diagnostic '%s' recreated").printf(new_entry.get_display_name()));
    }
    
    private void view_parameters(DiagnosticEntry entry) {
        show_parameters_dialog(entry.config);
    }
    
    private void show_parameters_dialog(DiagnosticConfiguration config) {
        var dialog = new Adw.AlertDialog(
            _("Diagnostic Parameters"),
            null
        );
        
        // Build parameter details
        var details = new StringBuilder();
        details.append_printf(_("Name: %s\n"), config.name);
        details.append_printf(_("Description: %s\n"), config.description);
        details.append_printf(_("Type: %s\n\n"), get_type_display_name(config.diagnostic_type));
        
        details.append(_("Connection Settings:\n"));
        details.append_printf(_("• Host: %s@%s:%d\n"), config.username, config.hostname, config.port);
        details.append_printf(_("• Authentication: %s\n"), get_auth_method_display(config.auth_method));
        if (config.ssh_key_path != "") {
            details.append_printf(_("• SSH Key: %s\n"), Path.get_basename(config.ssh_key_path));
        }
        details.append_printf(_("• Timeout: %d seconds\n"), config.timeout);
        if (config.proxy_jump != "") {
            details.append_printf(_("• Proxy Jump: %s\n"), config.proxy_jump);
        }
        
        details.append(_("\nTest Configuration:\n"));
        if (config.test_basic_connection) details.append(_("• Basic Connection Test\n"));
        if (config.test_dns_resolution) details.append(_("• DNS Resolution Test\n"));
        if (config.test_protocol_detection) details.append(_("• Protocol Detection Test\n"));
        if (config.test_performance) details.append(_("• Performance Test\n"));
        if (config.test_tunnel_capabilities) details.append(_("• Tunnel Capabilities Test\n"));
        if (config.test_permissions) details.append(_("• Permissions Test\n"));
        
        if (config.created_at != null) {
            details.append_printf(_("\nCreated: %s\n"), config.created_at.format("%Y-%m-%d %H:%M:%S"));
        }
        if (config.last_run != null) {
            details.append_printf(_("Last Run: %s\n"), config.last_run.format("%Y-%m-%d %H:%M:%S"));
        }
        
        dialog.body = details.str;
        dialog.add_response("ok", _("OK"));
        dialog.set_default_response("ok");
        dialog.present(get_root() as Gtk.Window);
    }
    
    private string get_type_display_name(DiagnosticType diagnostic_type) {
        switch (diagnostic_type) {
            case DiagnosticType.CONNECTION_TEST:
                return _("Connection Test");
            case DiagnosticType.PERFORMANCE_TEST:
                return _("Performance Test");
            case DiagnosticType.SECURITY_AUDIT:
                return _("Security Audit");
            case DiagnosticType.PROTOCOL_ANALYSIS:
                return _("Protocol Analysis");
            case DiagnosticType.TUNNEL_TEST:
                return _("Tunnel Test");
            case DiagnosticType.PERMISSION_CHECK:
                return _("Permission Check");
            default:
                return _("Unknown");
        }
    }
    
    private string get_auth_method_display(string auth_method) {
        switch (auth_method) {
            case "key":
                return _("SSH Key");
            case "password":
                return _("Password");
            case "agent":
                return _("SSH Agent");
            default:
                return auth_method;
        }
    }
    
    private void view_report(DiagnosticEntry entry) {
        if (entry.results == null || entry.results.length == 0) {
            show_toast_requested(_("No results available for this diagnostic"));
            return;
        }
        
        // Generate HTML report content
        var html_content = generate_html_report(entry);
        var target_name = entry.get_display_name();
        
        // Create and show the HTML report dialog
        var report_dialog = new KeyMaker.DiagnosticHtmlReportDialog(html_content, target_name);
        
        // Connect toast signals
        report_dialog.save_success_toast_requested.connect((msg) => {
            show_toast_requested(msg);
        });
        report_dialog.save_error_toast_requested.connect((msg) => {
            show_toast_requested(msg);
        });
        report_dialog.print_success_toast_requested.connect((msg) => {
            show_toast_requested(msg);
        });
        report_dialog.print_error_toast_requested.connect((msg) => {
            show_toast_requested(msg);
        });
        
        report_dialog.present(get_root() as Gtk.Widget);
    }
    
    private void print_report(DiagnosticEntry entry) {
        if (entry.results == null || entry.results.length == 0) {
            show_toast_requested(_("No results available to print"));
            return;
        }
        
        // Generate HTML report content
        var html_content = generate_html_report(entry);
        var target_name = entry.get_display_name();
        
        // Create a temporary HTML report dialog just for printing
        var print_dialog = new KeyMaker.DiagnosticHtmlReportDialog(html_content, target_name);
        
        // Connect toast signals
        print_dialog.print_success_toast_requested.connect((msg) => {
            show_toast_requested(msg);
            print_dialog.close(); // Close after successful print
        });
        print_dialog.print_error_toast_requested.connect((msg) => {
            show_toast_requested(msg);
        });
        
        // Present the dialog and trigger print immediately
        print_dialog.present(get_root() as Gtk.Widget);
        
        // Auto-trigger print after a small delay to let the WebView load
        Timeout.add(500, () => {
            print_dialog.trigger_print();
            return false;
        });
    }
    
    private void download_report(DiagnosticEntry entry) {
        if (entry.results == null || entry.results.length == 0) {
            show_toast_requested(_("No results available to export"));
            return;
        }
        
        var file_dialog = new Gtk.FileDialog();
        file_dialog.title = _("Export Diagnostic Report");
        
        // Set default filename
        var timestamp = entry.started_at.format("%Y%m%d_%H%M%S");
        var hostname = entry.config.hostname.replace(".", "_");
        var default_filename = @"diagnostic_$(hostname)_$(timestamp).html";
        file_dialog.initial_name = default_filename;
        
        // Add file filters
        var html_filter = new Gtk.FileFilter();
        html_filter.name = _("HTML Reports");
        html_filter.add_mime_type("text/html");
        html_filter.add_pattern("*.html");
        
        var json_filter = new Gtk.FileFilter();
        json_filter.name = _("JSON Reports");
        json_filter.add_mime_type("application/json");
        json_filter.add_pattern("*.json");
        
        var txt_filter = new Gtk.FileFilter();
        txt_filter.name = _("Text Reports");
        txt_filter.add_mime_type("text/plain");
        txt_filter.add_pattern("*.txt");
        
        var all_filter = new Gtk.FileFilter();
        all_filter.name = _("All Files");
        all_filter.add_pattern("*");
        
        var filter_list = new ListStore(typeof(Gtk.FileFilter));
        filter_list.append(html_filter);
        filter_list.append(json_filter);
        filter_list.append(txt_filter);
        filter_list.append(all_filter);
        file_dialog.filters = filter_list;
        
        file_dialog.save.begin(get_root() as Gtk.Window, null, (obj, res) => {
            try {
                var file = file_dialog.save.end(res);
                if (file != null) {
                    export_report_to_file.begin(entry, file, (obj2, res2) => {
                        try {
                            export_report_to_file.end(res2);
                            show_toast_requested(_("Report exported successfully"));
                        } catch (Error e) {
                            warning("Failed to export report: %s", e.message);
                            show_toast_requested(_("Failed to export report: %s").printf(e.message));
                        }
                    });
                }
            } catch (Error e) {
                // User cancelled or error occurred
            }
        });
    }
    
    private async void export_report_to_file(DiagnosticEntry entry, File file) throws Error {
        var file_path = file.get_path();
        var extension = "";
        if (file_path.contains(".")) {
            extension = file_path.substring(file_path.last_index_of(".") + 1).down();
        }
        
        string report_content = "";
        
        switch (extension) {
            case "html":
                report_content = generate_html_report(entry);
                break;
            case "txt":
                report_content = generate_text_report(entry);
                break;
            case "json":
            default:
                report_content = generate_json_report(entry);
                break;
        }
        
        yield file.replace_contents_async(
            report_content.data,
            null,
            false,
            FileCreateFlags.REPLACE_DESTINATION,
            null,
            null
        );
    }
    
    private string generate_html_report(DiagnosticEntry entry) {
        var html = new StringBuilder();
        
        html.append("<!DOCTYPE html>\n");
        html.append("<html>\n<head>\n");
        html.append("<meta charset='utf-8'>\n");
        html.append_printf("<title>Diagnostic Report - %s</title>\n", entry.get_display_name());
        html.append("<style>\n");
        html.append("body { font-family: -webkit-system-font, system-ui, sans-serif; margin: 40px; background: #fafafa; }\n");
        html.append(".container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }\n");
        html.append("h1 { color: #2d3436; border-bottom: 2px solid #74b9ff; padding-bottom: 10px; }\n");
        html.append("h2 { color: #636e72; margin-top: 30px; }\n");
        html.append(".info-section { background: #f8f9fa; padding: 20px; border-radius: 6px; margin: 20px 0; }\n");
        html.append(".test-result { margin: 10px 0; padding: 15px; border-radius: 6px; border-left: 4px solid; }\n");
        html.append(".test-passed { background: #d4edda; border-left-color: #28a745; }\n");
        html.append(".test-failed { background: #f8d7da; border-left-color: #dc3545; }\n");
        html.append(".test-warning { background: #fff3cd; border-left-color: #ffc107; }\n");
        html.append(".test-skipped { background: #e2e3e5; border-left-color: #6c757d; }\n");
        html.append(".status-badge { padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; }\n");
        html.append(".status-passed { background: #28a745; color: white; }\n");
        html.append(".status-failed { background: #dc3545; color: white; }\n");
        html.append(".status-warning { background: #ffc107; color: black; }\n");
        html.append(".status-skipped { background: #6c757d; color: white; }\n");
        html.append("</style>\n</head>\n<body>\n");
        
        html.append("<div class='container'>\n");
        html.append_printf("<h1>SSH Diagnostic Report</h1>\n");
        html.append_printf("<p><strong>Target:</strong> %s</p>\n", entry.get_display_name());
        html.append_printf("<p><strong>Generated:</strong> %s</p>\n", new DateTime.now_local().format("%Y-%m-%d %H:%M:%S"));
        
        // Connection Info
        html.append("<div class='info-section'>\n");
        html.append("<h2>Connection Information</h2>\n");
        html.append_printf("<p><strong>Hostname:</strong> %s</p>\n", entry.config.hostname);
        html.append_printf("<p><strong>Username:</strong> %s</p>\n", entry.config.username);
        html.append_printf("<p><strong>Port:</strong> %d</p>\n", entry.config.port);
        html.append_printf("<p><strong>Authentication:</strong> %s</p>\n", get_auth_method_display(entry.config.auth_method));
        if (entry.config.ssh_key_path != "") {
            html.append_printf("<p><strong>SSH Key:</strong> %s</p>\n", Path.get_basename(entry.config.ssh_key_path));
        }
        html.append_printf("<p><strong>Timeout:</strong> %d seconds</p>\n", entry.config.timeout);
        if (entry.started_at != null) {
            html.append_printf("<p><strong>Started:</strong> %s</p>\n", entry.started_at.format("%Y-%m-%d %H:%M:%S"));
        }
        if (entry.completed_at != null) {
            html.append_printf("<p><strong>Completed:</strong> %s</p>\n", entry.completed_at.format("%Y-%m-%d %H:%M:%S"));
        }
        html.append("</div>\n");
        
        // Test Results
        html.append("<h2>Test Results</h2>\n");
        
        if (entry.results != null && entry.results.length > 0) {
            int passed = 0, failed = 0, warnings = 0, skipped = 0;
            
            for (uint i = 0; i < entry.results.length; i++) {
                var result = entry.results[i];
                switch (result.status) {
                    case TestStatus.PASSED: passed++; break;
                    case TestStatus.FAILED: failed++; break;
                    case TestStatus.WARNING: warnings++; break;
                    case TestStatus.SKIPPED: skipped++; break;
                }
            }
            
            html.append("<div class='info-section'>\n");
            html.append_printf("<p><strong>Total Tests:</strong> %d</p>\n", (int)entry.results.length);
            html.append_printf("<p><strong>Passed:</strong> %d</p>\n", passed);
            html.append_printf("<p><strong>Failed:</strong> %d</p>\n", failed);
            if (warnings > 0) html.append_printf("<p><strong>Warnings:</strong> %d</p>\n", warnings);
            if (skipped > 0) html.append_printf("<p><strong>Skipped:</strong> %d</p>\n", skipped);
            html.append("</div>\n");
            
            for (uint i = 0; i < entry.results.length; i++) {
                var result = entry.results[i];
                var css_class = "test-result";
                var status_class = "";
                var status_text = "";
                
                switch (result.status) {
                    case TestStatus.PASSED:
                        css_class += " test-passed";
                        status_class = "status-passed";
                        status_text = "PASSED";
                        break;
                    case TestStatus.FAILED:
                        css_class += " test-failed";
                        status_class = "status-failed";
                        status_text = "FAILED";
                        break;
                    case TestStatus.WARNING:
                        css_class += " test-warning";
                        status_class = "status-warning";
                        status_text = "WARNING";
                        break;
                    case TestStatus.SKIPPED:
                        css_class += " test-skipped";
                        status_class = "status-skipped";
                        status_text = "SKIPPED";
                        break;
                }
                
                html.append_printf("<div class='%s'>\n", css_class);
                html.append_printf("<h3>%s <span class='status-badge %s'>%s</span></h3>\n", 
                    result.test_name ?? "Unknown Test", status_class, status_text);
                if (result.details != null && result.details != "") {
                    html.append_printf("<p>%s</p>\n", result.details.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"));
                }
                html.append_printf("<p><small>Execution time: %d ms</small></p>\n", result.execution_time_ms);
                html.append("</div>\n");
            }
        } else {
            html.append("<p>No test results available.</p>\n");
        }
        
        html.append("</div>\n</body>\n</html>\n");
        return html.str;
    }
    
    private string generate_text_report(DiagnosticEntry entry) {
        var report = new StringBuilder();
        
        report.append("SSH DIAGNOSTIC REPORT\n");
        report.append("===================\n\n");
        
        report.append_printf("Target: %s\n", entry.get_display_name());
        report.append_printf("Generated: %s\n\n", new DateTime.now_local().format("%Y-%m-%d %H:%M:%S"));
        
        report.append("CONNECTION INFORMATION\n");
        report.append("---------------------\n");
        report.append_printf("Hostname: %s\n", entry.config.hostname);
        report.append_printf("Username: %s\n", entry.config.username);
        report.append_printf("Port: %d\n", entry.config.port);
        report.append_printf("Authentication: %s\n", get_auth_method_display(entry.config.auth_method));
        if (entry.config.ssh_key_path != "") {
            report.append_printf("SSH Key: %s\n", Path.get_basename(entry.config.ssh_key_path));
        }
        report.append_printf("Timeout: %d seconds\n", entry.config.timeout);
        if (entry.started_at != null) {
            report.append_printf("Started: %s\n", entry.started_at.format("%Y-%m-%d %H:%M:%S"));
        }
        if (entry.completed_at != null) {
            report.append_printf("Completed: %s\n", entry.completed_at.format("%Y-%m-%d %H:%M:%S"));
        }
        report.append("\n");
        
        report.append("TEST RESULTS\n");
        report.append("-----------\n");
        
        if (entry.results != null && entry.results.length > 0) {
            int passed = 0, failed = 0, warnings = 0, skipped = 0;
            
            for (uint i = 0; i < entry.results.length; i++) {
                var result = entry.results[i];
                switch (result.status) {
                    case TestStatus.PASSED: passed++; break;
                    case TestStatus.FAILED: failed++; break;
                    case TestStatus.WARNING: warnings++; break;
                    case TestStatus.SKIPPED: skipped++; break;
                }
            }
            
            report.append_printf("Total Tests: %d\n", (int)entry.results.length);
            report.append_printf("Passed: %d\n", passed);
            report.append_printf("Failed: %d\n", failed);
            if (warnings > 0) report.append_printf("Warnings: %d\n", warnings);
            if (skipped > 0) report.append_printf("Skipped: %d\n", skipped);
            report.append("\nDETAILED RESULTS:\n\n");
            
            for (uint i = 0; i < entry.results.length; i++) {
                var result = entry.results[i];
                var status_text = "";
                
                switch (result.status) {
                    case TestStatus.PASSED: status_text = "PASSED"; break;
                    case TestStatus.FAILED: status_text = "FAILED"; break;
                    case TestStatus.WARNING: status_text = "WARNING"; break;
                    case TestStatus.SKIPPED: status_text = "SKIPPED"; break;
                }
                
                report.append_printf("%d. %s [%s]\n", (int)i + 1, result.test_name ?? "Unknown Test", status_text);
                if (result.details != null && result.details != "") {
                    report.append_printf("   %s\n", result.details);
                }
                report.append_printf("   Execution time: %d ms\n\n", result.execution_time_ms);
            }
        } else {
            report.append("No test results available.\n");
        }
        
        return report.str;
    }
    
    private string generate_json_report(DiagnosticEntry entry) {
        // Create comprehensive report JSON
        var report = new Json.Builder();
        report.begin_object();
        
        // Header information
        report.set_member_name("diagnostic_report");
        report.begin_object();
        
        report.set_member_name("metadata");
        report.begin_object();
        report.set_member_name("name").add_string_value(entry.config.name);
        report.set_member_name("description").add_string_value(entry.config.description);
        report.set_member_name("diagnostic_type").add_string_value(entry.config.diagnostic_type.to_string());
        report.set_member_name("created_at").add_string_value(entry.started_at.format_iso8601());
        report.set_member_name("completed_at").add_string_value(entry.completed_at.format_iso8601());
        report.set_member_name("state").add_string_value(entry.state.to_string());
        report.end_object();
        
        // Configuration details
        report.set_member_name("configuration");
        report.begin_object();
        report.set_member_name("hostname").add_string_value(entry.config.hostname);
        report.set_member_name("username").add_string_value(entry.config.username);
        report.set_member_name("port").add_int_value(entry.config.port);
        report.set_member_name("auth_method").add_string_value(entry.config.auth_method);
        report.set_member_name("timeout").add_int_value(entry.config.timeout);
        
        // Test selections
        report.set_member_name("test_selection");
        report.begin_object();
        report.set_member_name("test_basic_connection").add_boolean_value(entry.config.test_basic_connection);
        report.set_member_name("test_dns_resolution").add_boolean_value(entry.config.test_dns_resolution);
        report.set_member_name("test_protocol_detection").add_boolean_value(entry.config.test_protocol_detection);
        report.set_member_name("test_performance").add_boolean_value(entry.config.test_performance);
        report.set_member_name("test_tunnel_capabilities").add_boolean_value(entry.config.test_tunnel_capabilities);
        report.set_member_name("test_permissions").add_boolean_value(entry.config.test_permissions);
        report.end_object();
        report.end_object();
        
        // Test results
        report.set_member_name("results");
        report.begin_array();
        
        if (entry.results != null) {
            for (uint i = 0; i < entry.results.length; i++) {
                var result = entry.results[i];
                report.begin_object();
                report.set_member_name("test_name").add_string_value(result.test_name);
                report.set_member_name("status").add_string_value(result.status.to_string());
                report.set_member_name("success").add_boolean_value(result.status == TestStatus.PASSED);
                report.set_member_name("details").add_string_value(result.details ?? "");
                report.set_member_name("execution_time_ms").add_int_value(result.execution_time_ms);
                report.end_object();
            }
        }
        
        report.end_array();
        report.end_object();
        report.end_object();
        
        // Generate JSON and save to file
        var generator = new Json.Generator();
        generator.set_root(report.get_root());
        generator.pretty = true;
        generator.indent = 2;
        
        return generator.to_data(null);
    }
    
    private void remove_from_history(DiagnosticEntry entry) {
        var dialog = new Adw.AlertDialog(
            _("Remove from History?"),
            _("Are you sure you want to remove '%s' from the diagnostic history?").printf(entry.get_display_name())
        );
        
        dialog.add_response("cancel", _("Cancel"));
        dialog.add_response("remove", _("Remove"));
        dialog.set_response_appearance("remove", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response("cancel");
        dialog.set_close_response("cancel");
        
        dialog.response.connect((response_id) => {
            if (response_id == "remove") {
                // Remove the entry from the actual history manager
                if (history_manager != null) {
                    try {
                        var history_entries_from_manager = history_manager.get_entries();
                        
                        // Find the matching history entry by comparing key attributes
                        for (uint i = 0; i < history_entries_from_manager.length; i++) {
                            var hist_entry = history_entries_from_manager[i];
                            if (hist_entry.hostname == entry.config.hostname &&
                                hist_entry.username == entry.config.username &&
                                hist_entry.port == entry.config.port &&
                                hist_entry.timestamp.equal(entry.started_at ?? entry.completed_at)) {
                                
                                // Remove from the history manager
                                history_manager.remove_entry(i);
                                show_toast_requested(_("Entry removed from history"));
                                return; // Exit early since we found and removed the entry
                            }
                        }
                        
                        // If we get here, the entry wasn't found
                        show_toast_requested(_("Could not find entry in history to remove"));
                    } catch (Error e) {
                        warning("Failed to remove history entry: %s", e.message);
                        show_toast_requested(_("Failed to remove entry: %s").printf(e.message));
                    }
                } else {
                    show_toast_requested(_("History manager not available"));
                }
            }
        });
        
        dialog.present(get_root() as Gtk.Window);
    }
    
    private void load_diagnostics_data() {
        load_active_diagnostics();
        // History will be loaded automatically when DiagnosticHistory is ready via signal
    }
    
    private void save_diagnostics_data() {
        save_active_diagnostics();
    }
    
    private void save_active_diagnostics() {
        try {
            // Get user config directory
            var config_dir = File.new_for_path(Environment.get_user_config_dir())
                                .get_child("keymaker");
            
            // Ensure config directory exists
            if (!config_dir.query_exists()) {
                config_dir.make_directory_with_parents();
            }
            
            var diagnostics_file = config_dir.get_child("active_diagnostics.json");
            
            // Create JSON structure
            var root_object = new Json.Object();
            var diagnostics_array = new Json.Array();
            
            for (uint i = 0; i < active_diagnostics.length; i++) {
                var entry = active_diagnostics[i];
                diagnostics_array.add_object_element(entry.to_json());
            }
            
            root_object.set_array_member("active_diagnostics", diagnostics_array);
            
            // Generate JSON and save
            var generator = new Json.Generator();
            generator.set_root(new Json.Node(Json.NodeType.OBJECT));
            generator.root.set_object(root_object);
            generator.pretty = true;
            
            var json_string = generator.to_data(null);
            diagnostics_file.replace_contents(json_string.data, null, false, 
                                            FileCreateFlags.REPLACE_DESTINATION, null);
            
        } catch (Error e) {
            warning("Failed to save active diagnostics: %s", e.message);
        }
    }
    
    private void load_active_diagnostics() {
        try {
            var config_dir = File.new_for_path(Environment.get_user_config_dir())
                                .get_child("keymaker");
            var diagnostics_file = config_dir.get_child("active_diagnostics.json");
            
            if (!diagnostics_file.query_exists()) {
                return;
            }
            
            uint8[] contents;
            diagnostics_file.load_contents(null, out contents, null);
            
            var parser = new Json.Parser();
            parser.load_from_data((string)contents);
            
            var root_object = parser.get_root().get_object();
            var diagnostics_array = root_object.get_array_member("active_diagnostics");
            
            // Clear current diagnostics
            active_diagnostics.remove_range(0, active_diagnostics.length);
            
            diagnostics_array.foreach_element((array, index, element) => {
                var entry_object = element.get_object();
                var entry = DiagnosticEntry.from_json(entry_object);
                if (entry != null) {
                    active_diagnostics.add(entry);
                }
            });
            
        } catch (Error e) {
            warning("Failed to load active diagnostics: %s", e.message);
        }
    }
}