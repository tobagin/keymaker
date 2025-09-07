/*
 * Key Maker - Key List Widget
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/key_list.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/key_list.ui")]
#endif
public class KeyMaker.KeyListWidget : Gtk.Box {
    [GtkChild]
    private unowned Adw.StatusPage empty_state;
    
    [GtkChild]
    private unowned Gtk.ScrolledWindow list_scroll;
    
    [GtkChild]
    private unowned Gtk.ListBox key_list_box;
    
    [GtkChild]
    private unowned Gtk.Label key_count_label;
    
    [GtkChild]
    private unowned Gtk.Button refresh_button;
    
    [GtkChild]
    private unowned Gtk.MenuButton generate_button;
    
    private GenericArray<KeyMaker.KeyRowWidget> key_rows;
    
    // Signals
    public signal void key_copy_requested (SSHKey ssh_key);
    public signal void key_delete_requested (SSHKey ssh_key);
    public signal void key_details_requested (SSHKey ssh_key);
    public signal void key_passphrase_change_requested (SSHKey ssh_key);
    public signal void key_copy_id_requested (SSHKey ssh_key);
    
    
    construct {
        key_rows = new GenericArray<KeyMaker.KeyRowWidget> ();
        
        // Setup the listbox (UI loaded from template)
        key_list_box.set_selection_mode (Gtk.SelectionMode.NONE);
        
        // Initial state - show empty state by default
        empty_state.visible = true;
        list_scroll.visible = false;
    }
    
    public void add_key (SSHKey ssh_key) {
        var key_row = new KeyMaker.KeyRowWidget (ssh_key);
        
        // Connect signals
        key_row.copy_requested.connect ((key) => key_copy_requested (key));
        key_row.delete_requested.connect ((key) => key_delete_requested (key));
        key_row.details_requested.connect ((key) => key_details_requested (key));
        key_row.passphrase_change_requested.connect ((key) => key_passphrase_change_requested (key));
        key_row.copy_id_requested.connect ((key) => key_copy_id_requested (key));
        
        key_rows.add (key_row);
        key_list_box.append (key_row);
        
        // Show the key list
        empty_state.visible = false;
        list_scroll.visible = true;
    }
    
    public void remove_key (SSHKey ssh_key) {
        // Find and remove the key row
        for (int i = 0; i < key_rows.length; i++) {
            var row = key_rows[i];
            if (row.ssh_key == ssh_key) {
                key_list_box.remove (row);
                key_rows.remove_index (i);
                break;
            }
        }
        
        // Show empty state if no keys left
        if (key_rows.length == 0) {
            show_empty_state ();
        }
    }
    
    public void clear () {
        // Remove all key rows
        while (key_rows.length > 0) {
            var row = key_rows[0];
            key_list_box.remove (row);
            key_rows.remove_index (0);
        }
        
        show_empty_state ();
    }
    
    public void show_empty_state () {
        empty_state.visible = true;
        list_scroll.visible = false;
    }
    
    public void refresh_key (SSHKey ssh_key) {
        // Find the key row and refresh it
        for (int i = 0; i < key_rows.length; i++) {
            var row = key_rows[i];
            if (row.ssh_key == ssh_key) {
                row.refresh ();
                break;
            }
        }
    }
}