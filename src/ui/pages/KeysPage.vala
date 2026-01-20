/*
 * SSHer - Keys Page
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/keys_page.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/keys_page.ui")]
#endif
public class KeyMaker.KeysPage : Adw.Bin {
    [GtkChild]
    private unowned Gtk.Box child_box;
    [GtkChild]
    private unowned Gtk.ListBox key_list_box;
    [GtkChild]
    private unowned Gtk.Button refresh_button;
    [GtkChild]
    private unowned Gtk.MenuButton generate_button;
    [GtkChild]
    private unowned Gtk.Button mobile_menu_button; // Changed to Button
    
    private GenericArray<KeyMaker.KeyRowWidget> key_rows;
    private GenericArray<SSHKey> ssh_keys;
    private Cancellable? refresh_cancellable;

    
    // Signals for window integration
    public signal void key_copy_requested (SSHKey ssh_key);
    public signal void key_delete_requested (SSHKey ssh_key);
    public signal void key_details_requested (SSHKey ssh_key);
    public signal void key_passphrase_change_requested (SSHKey ssh_key);
    public signal void key_copy_id_requested (SSHKey ssh_key);
    public signal void generate_key_requested ();
    public signal void add_existing_key_requested ();
    public signal void show_toast_requested (string message);
    
    public bool mobile_view { get; set; default = false; }

    construct {
        // Initialize arrays
        ssh_keys = new GenericArray<SSHKey> ();
        key_rows = new GenericArray<KeyMaker.KeyRowWidget> ();

        // Listen for mobile view changes
        notify["mobile-view"].connect (on_mobile_view_changed);
        
        // SSH agent will be initialized when needed
        

        
        // ...
        
        // Setup SSH Keys buttons with null checks
        if (refresh_button != null) {
            refresh_button.clicked.connect (() => refresh_keys ());
        }
        
        if (mobile_menu_button != null) {
            mobile_menu_button.clicked.connect (show_header_mobile_menu);
        }
        
        // Setup the key list box
        if (key_list_box != null) {
            key_list_box.set_selection_mode (Gtk.SelectionMode.NONE);
        }
        
        // Load SSH keys and agent keys
        refresh_keys ();
    }

    private void on_mobile_view_changed () {
        for (int i = 0; i < key_rows.length; i++) {
            key_rows[i].set_mobile_mode (mobile_view);
        }
    }

    private void show_header_mobile_menu () {
        var sheet = new Adw.Dialog ();
        sheet.title = _("Page Actions");
        
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.margin_top = 12;
        box.margin_bottom = 12;
        box.margin_start = 12;
        box.margin_end = 12;
        box.spacing = 12;
        
        var actions_group = new Adw.PreferencesGroup ();
        
        // Generate Key
        var row_generate = new Adw.ButtonRow ();
        row_generate.title = _("Generate New SSH Key");
        row_generate.start_icon_name = "tab-new-symbolic";
        row_generate.activated.connect (() => {
            sheet.close ();
            generate_key_requested ();
        });
        actions_group.add (row_generate);
        
        // Import Key
        var row_import = new Adw.ButtonRow ();
        row_import.title = _("Import Existing Key");
        row_import.start_icon_name = "document-open-symbolic"; // Assuming icon for import
        row_import.activated.connect (() => {
            sheet.close ();
            add_existing_key_requested ();
        });
        actions_group.add (row_import);
        
        // Refresh
        var row_refresh = new Adw.ButtonRow ();
        row_refresh.title = _("Refresh Key List");
        row_refresh.start_icon_name = "view-refresh-symbolic";
        row_refresh.activated.connect (() => {
            sheet.close ();
            refresh_keys ();
        });
        actions_group.add (row_refresh);

        box.append (actions_group);
        sheet.child = box;
        sheet.present (this.get_root () as Gtk.Widget);
    }
    
    
    public GenericArray<SSHKey> get_ssh_keys () {
        return ssh_keys;
    }
    
    public void refresh_keys () {
        refresh_key_list_async.begin ();
    }
    
    private async void refresh_key_list_async () {
        // Cancel any in-flight scan
        if (refresh_cancellable != null) {
            try { refresh_cancellable.cancel (); } catch (Error e) { }
        }
        refresh_cancellable = new Cancellable ();

        debug ("KeysPage: starting async key scan");
        try {
            var keys = yield KeyMaker.KeyScanner.scan_ssh_directory_with_cancellable (null, refresh_cancellable);

            // Clear current list
            clear_key_list ();
            ssh_keys.remove_range (0, ssh_keys.length);
            
            // Add keys
            for (int i = 0; i < keys.length; i++) {
                ssh_keys.add (keys[i]);
                add_key_to_list (keys[i]);
            }


            debug ("KeysPage: async key scan complete: %d keys", keys.length);
        } catch (IOError.CANCELLED e) {
            debug ("KeysPage: key scan cancelled");
        } catch (KeyMakerError e) {
            show_toast_requested (_("Failed to scan SSH keys: %s").printf (e.message));
            clear_key_list ();
        } catch (Error e) {
            show_toast_requested (_("Failed to scan SSH keys: %s").printf (e.message));
            clear_key_list ();
        }
    }
    
    public void on_key_deleted (SSHKey deleted_key) {
        // Remove the key from our list
        for (int i = 0; i < ssh_keys.length; i++) {
            if (ssh_keys[i] == deleted_key) {
                ssh_keys.remove_index (i);
                break;
            }
        }
        
        remove_key_from_list (deleted_key);
    }
    

    
    public void on_passphrase_changed (SSHKey updated_key) {
        // Refresh the key list to update button tooltips and UI state
        refresh_key_in_list (updated_key);
    }
    
    public void on_key_generated (SSHKey new_key) {
        // Refresh the key list to ensure everything is properly updated
        refresh_keys ();
    }
    
    private void clear_key_list () {
        if (key_list_box == null) return;
        
        // Remove all key rows
        while (key_rows.length > 0) {
            var row = key_rows[0];
            key_list_box.remove (row);
            key_rows.remove_index (0);
        }
    }
    
    private void add_key_to_list (SSHKey ssh_key) {
        if (key_list_box == null) return;
        
        var key_row = new KeyMaker.KeyRowWidget (ssh_key);
        key_row.set_mobile_mode (mobile_view);
        
        // Connect signals
        key_row.copy_requested.connect ((key) => key_copy_requested (key));
        key_row.delete_requested.connect ((key) => key_delete_requested (key));
        key_row.details_requested.connect ((key) => key_details_requested (key));
        key_row.passphrase_change_requested.connect ((key) => key_passphrase_change_requested (key));
        key_row.copy_id_requested.connect ((key) => key_copy_id_requested (key));
        
        key_rows.add (key_row);
        key_list_box.append (key_row);
    }
    
    private void remove_key_from_list (SSHKey ssh_key) {
        if (key_list_box == null) return;
        
        // Find and remove the key row
        for (int i = 0; i < key_rows.length; i++) {
            var row = key_rows[i];
            if (row.ssh_key == ssh_key) {
                key_list_box.remove (row);
                key_rows.remove_index (i);
                break;
            }
        }
    }
    
    private void refresh_key_in_list (SSHKey ssh_key) {
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