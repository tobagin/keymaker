/*
 * Key Maker - Diagnostic Type Selection Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/diagnostic_type_selection_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/diagnostic_type_selection_dialog.ui")]
#endif
public class KeyMaker.DiagnosticTypeSelectionDialog : Adw.Dialog {
    [GtkChild]
    private unowned Gtk.ListBox diagnostic_types_list;
    
    [GtkChild]
    private unowned Adw.ActionRow connection_test_row;
    [GtkChild]
    private unowned Adw.ActionRow performance_test_row;
    [GtkChild]
    private unowned Adw.ActionRow security_audit_row;
    [GtkChild]
    private unowned Adw.ActionRow protocol_analysis_row;
    [GtkChild]
    private unowned Adw.ActionRow tunnel_test_row;
    [GtkChild]
    private unowned Adw.ActionRow permission_check_row;
    
    private DiagnosticType? selected_type = null;
    
    public signal void diagnostic_type_selected(DiagnosticType type);
    
    public DiagnosticTypeSelectionDialog() {
        Object();
    }
    
    construct {
        
        // Setup list box selection
        diagnostic_types_list.row_selected.connect(on_row_selected);
        diagnostic_types_list.row_activated.connect(on_row_activated);
        
        // Map rows to diagnostic types
        connection_test_row.set_data("diagnostic_type", DiagnosticType.CONNECTION_TEST);
        performance_test_row.set_data("diagnostic_type", DiagnosticType.PERFORMANCE_TEST);
        security_audit_row.set_data("diagnostic_type", DiagnosticType.SECURITY_AUDIT);
        protocol_analysis_row.set_data("diagnostic_type", DiagnosticType.PROTOCOL_ANALYSIS);
        tunnel_test_row.set_data("diagnostic_type", DiagnosticType.TUNNEL_TEST);
        permission_check_row.set_data("diagnostic_type", DiagnosticType.PERMISSION_CHECK);
    }
    
    private void on_row_selected(Gtk.ListBoxRow? row) {
        if (row != null) {
            selected_type = row.get_data<DiagnosticType>("diagnostic_type");
        } else {
            selected_type = null;
        }
    }
    
    private void on_row_activated(Gtk.ListBoxRow row) {
        selected_type = row.get_data<DiagnosticType>("diagnostic_type");
        if (selected_type != null) {
            diagnostic_type_selected(selected_type);
            close();
        }
    }
    
    public static DiagnosticType? run_dialog(Gtk.Window parent) {
        var dialog = new DiagnosticTypeSelectionDialog();
        DiagnosticType? result = null;
        
        dialog.diagnostic_type_selected.connect((type) => {
            result = type;
        });
        
        dialog.present(parent);
        return result;
    }
}