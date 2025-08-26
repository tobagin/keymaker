/*
 * Key Maker - Key Details Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/key_details_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/key_details_dialog.ui")]
#endif
public class KeyMaker.KeyDetailsDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.ActionRow key_type_row;
    
    [GtkChild]
    private unowned Adw.ActionRow bit_size_row;
    
    [GtkChild]
    private unowned Adw.ActionRow fingerprint_row;
    
    [GtkChild]
    private unowned Adw.ActionRow comment_row;
    
    [GtkChild]
    private unowned Adw.ActionRow private_path_row;
    
    [GtkChild]
    private unowned Adw.ActionRow public_path_row;
    
    [GtkChild]
    private unowned Adw.ActionRow modified_row;
    
    [GtkChild]
    private unowned Gtk.Button copy_fingerprint_button;
    
    [GtkChild]
    private unowned Gtk.Button copy_private_path_button;
    
    [GtkChild]
    private unowned Gtk.Button copy_public_path_button;
    
    [GtkChild]
    private unowned Gtk.TextView public_key_text;
    
    public SSHKey ssh_key { get; construct; }
    
    
    public KeyDetailsDialog (Gtk.Window parent, SSHKey ssh_key) {
        Object (
            ssh_key: ssh_key
        );
    }
    
    construct {
        update_display ();
    }
    
    private void update_display () {
        // Set key type
        key_type_row.set_subtitle (ssh_key.get_type_description ());
        
        // Set fingerprint
        fingerprint_row.set_subtitle (ssh_key.fingerprint);
        
        // Set comment
        if (ssh_key.comment != null && ssh_key.comment.strip () != "") {
            comment_row.set_subtitle (ssh_key.comment);
            comment_row.set_visible (true);
        } else {
            comment_row.set_visible (false);
        }
        
        // Set paths
        private_path_row.set_subtitle (ssh_key.private_path.get_path ());
        public_path_row.set_subtitle (ssh_key.public_path.get_path ());
        
        // Set last modified
        var formatted_date = ssh_key.last_modified.format (_("%B %d, %Y at %I:%M %p"));
        modified_row.set_subtitle (formatted_date);
        
        // Show bit size only for RSA keys
        if (ssh_key.key_type == SSHKeyType.RSA && ssh_key.bit_size > 0) {
            bit_size_row.set_subtitle (ssh_key.bit_size.to_string ());
            bit_size_row.set_visible (true);
        } else {
            bit_size_row.set_visible (false);
        }
        
        // Set public key content
        try {
            var content = SSHOperations.get_public_key_content (ssh_key);
            var buffer = public_key_text.get_buffer ();
            buffer.set_text (content, -1);
        } catch (KeyMakerError e) {
            var buffer = public_key_text.get_buffer ();
            buffer.set_text (_("Error loading public key content"), -1);
        }
    }
    
    
    
    private async void copy_public_key_async () {
        try {
            var content = SSHOperations.get_public_key_content (ssh_key);
            
            var clipboard = get_clipboard ();
            clipboard.set_text (content);
            
            // Public key copied successfully (no visual feedback for now)
            
        } catch (KeyMakerError e) {
            warning ("Failed to copy public key: %s", e.message);
        }
    }
}