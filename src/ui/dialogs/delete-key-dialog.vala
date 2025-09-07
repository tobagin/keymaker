/*
 * Key Maker - Delete Key Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

public class KeyMaker.DeleteKeyDialog : GLib.Object {
    public SSHKey ssh_key { get; construct; }
    
    // Signals
    public signal void key_deleted (SSHKey ssh_key);
    
    private Gtk.Window parent_window;
    
    public DeleteKeyDialog (Gtk.Window parent, SSHKey ssh_key) {
        Object (ssh_key: ssh_key);
        parent_window = parent;
    }
    
    public async void show () {
        var dialog = new Adw.AlertDialog (
            _("Delete SSH Key?"),
            _("This will permanently delete the key pair '%s'.\n\nThis action cannot be undone.").printf (ssh_key.get_display_name ())
        );
        
        // Add responses
        dialog.add_response ("cancel", _("Cancel"));
        dialog.add_response ("delete", _("Delete"));
        
        dialog.set_response_appearance ("delete", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response ("cancel");
        dialog.set_close_response ("cancel");
        
        var response = yield dialog.choose (parent_window, null);
        
        if (response == "delete") {
            yield delete_key();
        }
    }
    
    private async void delete_key () {
        try {
            // Delete the key pair
            yield SSHOperations.delete_key_pair (ssh_key);
            
            // Emit signal
            key_deleted (ssh_key);
            
        } catch (KeyMakerError e) {
            // Show error dialog
            var error_dialog = new Adw.AlertDialog (
                _("Delete Failed"),
                _("Failed to delete SSH key: %s").printf (e.message)
            );
            error_dialog.add_response ("ok", _("OK"));
            error_dialog.set_default_response ("ok");
            error_dialog.set_close_response ("ok");
            error_dialog.present (parent_window);
            
            warning ("Failed to delete SSH key: %s", e.message);
        }
    }
}