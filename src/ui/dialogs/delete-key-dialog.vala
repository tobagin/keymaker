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

public class KeyMaker.DeleteKeyDialog : Adw.MessageDialog {
    public SSHKey ssh_key { get; construct; }
    
    // Signals
    public signal void key_deleted (SSHKey ssh_key);
    
    public DeleteKeyDialog (Gtk.Window parent, SSHKey ssh_key) {
        Object (
            ssh_key: ssh_key,
            transient_for: parent,
            modal: true
        );
    }
    
    construct {
        // Configure the message dialog
        set_heading (_("Delete SSH Key?"));
        set_body (_("This will permanently delete the key pair '%s'.\n\nThis action cannot be undone.").printf (ssh_key.get_display_name ()));
        
        // Add responses
        add_response ("cancel", _("Cancel"));
        add_response ("delete", _("Delete"));
        
        set_response_appearance ("delete", Adw.ResponseAppearance.DESTRUCTIVE);
        set_default_response ("cancel");
        set_close_response ("cancel");
        
        // Connect response signal
        response.connect (on_response);
    }
    
    private void on_response (string response_id) {
        if (response_id == "delete") {
            delete_key_async.begin ();
        }
    }
    
    private async void delete_key_async () {
        try {
            // Delete the key pair
            yield SSHOperations.delete_key_pair (ssh_key);
            
            // Emit signal
            key_deleted (ssh_key);
            
        } catch (KeyMakerError e) {
            // Show error dialog
            var error_dialog = new Adw.MessageDialog (
                get_transient_for (),
                _("Delete Failed"),
                _("Failed to delete SSH key: %s").printf (e.message)
            );
            error_dialog.add_response ("ok", _("OK"));
            error_dialog.set_default_response ("ok");
            error_dialog.set_close_response ("ok");
            error_dialog.present ();
            
            warning ("Failed to delete SSH key: %s", e.message);
        }
    }
}