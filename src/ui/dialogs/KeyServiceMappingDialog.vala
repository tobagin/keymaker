/*
 * SSHer - Key Service Mapping Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/key_service_mapping_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/key_service_mapping_dialog.ui")]
#endif
public class KeyMaker.KeyServiceMappingDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.EntryRow service_name_row;
    
    [GtkChild]
    private unowned Adw.ComboRow service_type_row;
    
    [GtkChild]
    private unowned Adw.EntryRow hostname_row;
    
    [GtkChild]
    private unowned Adw.EntryRow username_row;
    
    [GtkChild]
    private unowned Adw.EntryRow description_row;
    
    [GtkChild]
    private unowned Gtk.Button save_button;
    
    [GtkChild]
    private unowned Gtk.Button cancel_button;
    
    public SSHKey ssh_key { get; construct; }
    public KeyServiceMapping? existing_mapping { get; construct; }
    
    private KeyServiceMappingManager mapping_manager;
    
    public signal void mapping_saved (KeyServiceMapping mapping);
    
    public KeyServiceMappingDialog (Gtk.Window parent, SSHKey key, KeyServiceMapping? mapping = null) {
        Object (
            ssh_key: key,
            existing_mapping: mapping
        );
    }
    
    construct {
        mapping_manager = new KeyServiceMappingManager ();
        
        setup_service_types ();
        setup_signals ();
        
        if (existing_mapping != null) {
            populate_from_existing ();
        } else {
            // Try to suggest mapping based on key comment
            suggest_mapping_from_comment ();
        }
        
        update_ui_state ();
    }
    
    private void setup_service_types () {
        var types = new string[] {
            "GitHub",
            "GitLab", 
            "Bitbucket",
            "Server",
            "Work",
            "Personal",
            "Client",
            "Other"
        };
        
        var model = new Gtk.StringList (types);
        service_type_row.model = model;
    }
    
    private void setup_signals () {
        save_button.clicked.connect (on_save_clicked);
        cancel_button.clicked.connect (on_cancel_clicked);
        
        // Update UI state when fields change
        service_name_row.notify["text"].connect (update_ui_state);
        service_type_row.notify["selected"].connect (on_service_type_changed);
    }
    
    private void populate_from_existing () {
        service_name_row.text = existing_mapping.service_name;
        service_type_row.selected = get_service_type_index (existing_mapping.service_type);
        hostname_row.text = existing_mapping.hostname ?? "";
        username_row.text = existing_mapping.username ?? "";
        description_row.text = existing_mapping.description ?? "";
    }
    
    private void suggest_mapping_from_comment () {
        var comment = ssh_key.comment ?? "";
        var comment_lower = comment.down ();
        
        if ("github" in comment_lower) {
            service_name_row.text = "GitHub";
            service_type_row.selected = get_service_type_index (ServiceType.GITHUB);
        } else if ("gitlab" in comment_lower) {
            service_name_row.text = "GitLab";
            service_type_row.selected = get_service_type_index (ServiceType.GITLAB);
        } else if ("bitbucket" in comment_lower) {
            service_name_row.text = "Bitbucket";
            service_type_row.selected = get_service_type_index (ServiceType.BITBUCKET);
        } else if ("work" in comment_lower || "office" in comment_lower) {
            service_name_row.text = "Work";
            service_type_row.selected = get_service_type_index (ServiceType.WORK);
        } else {
            service_name_row.text = comment != "" ? comment : "Unnamed Service";
            service_type_row.selected = get_service_type_index (ServiceType.OTHER);
        }
    }
    
    private uint get_service_type_index (ServiceType type) {
        switch (type) {
            case ServiceType.GITHUB: return 0;
            case ServiceType.GITLAB: return 1;
            case ServiceType.BITBUCKET: return 2;
            case ServiceType.SERVER: return 3;
            case ServiceType.WORK: return 4;
            case ServiceType.PERSONAL: return 5;
            case ServiceType.CLIENT: return 6;
            case ServiceType.OTHER: return 7;
            default: return 7;
        }
    }
    
    private ServiceType get_service_type_from_index (uint index) {
        switch (index) {
            case 0: return ServiceType.GITHUB;
            case 1: return ServiceType.GITLAB;
            case 2: return ServiceType.BITBUCKET;
            case 3: return ServiceType.SERVER;
            case 4: return ServiceType.WORK;
            case 5: return ServiceType.PERSONAL;
            case 6: return ServiceType.CLIENT;
            case 7: return ServiceType.OTHER;
            default: return ServiceType.OTHER;
        }
    }
    
    private void on_service_type_changed () {
        var selected_type = get_service_type_from_index (service_type_row.selected);
        
        // Show/hide hostname and username based on service type
        bool show_connection_fields = (
            selected_type == ServiceType.SERVER ||
            selected_type == ServiceType.WORK ||
            selected_type == ServiceType.CLIENT
        );
        
        hostname_row.visible = show_connection_fields;
        username_row.visible = show_connection_fields;
        
        update_ui_state ();
    }
    
    private void update_ui_state () {
        var service_name = service_name_row.text.strip ();
        save_button.sensitive = (service_name.length > 0);
    }
    
    private void on_save_clicked () {
        var service_name = service_name_row.text.strip ();
        var service_type = get_service_type_from_index (service_type_row.selected);
        
        if (service_name.length == 0) {
            return;
        }
        
        KeyServiceMapping mapping;
        
        if (existing_mapping != null) {
            mapping = existing_mapping;
            mapping.service_name = service_name;
            mapping.service_type = service_type;
        } else {
            mapping = new KeyServiceMapping (ssh_key.fingerprint, service_name, service_type);
        }
        
        mapping.hostname = hostname_row.text.strip () != "" ? hostname_row.text.strip () : null;
        mapping.username = username_row.text.strip () != "" ? username_row.text.strip () : null;
        mapping.description = description_row.text.strip () != "" ? description_row.text.strip () : null;
        
        mapping_manager.add_mapping (mapping);
        mapping_saved (mapping);
        
        close ();
    }
    
    private void on_cancel_clicked () {
        close ();
    }
}