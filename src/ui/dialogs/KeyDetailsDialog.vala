/*
 * SSHer - Key Details Dialog
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
    private unowned Adw.ActionRow private_permissions_row;
    
    [GtkChild]
    private unowned Adw.ActionRow public_permissions_row;
    
    [GtkChild]
    private unowned Gtk.Button copy_fingerprint_button;
    
    [GtkChild]
    private unowned Gtk.Button copy_private_path_button;
    
    [GtkChild]
    private unowned Gtk.Button copy_public_path_button;
    
    [GtkChild]
    private unowned Gtk.TextView public_key_text;
    
    [GtkChild]
    private unowned Gtk.Button copy_public_key_button;
    
    public SSHKey ssh_key { get; construct; }
    
    
    public KeyDetailsDialog (Gtk.Window parent, SSHKey ssh_key) {
        Object (
            ssh_key: ssh_key
        );
    }
    
    construct {
        update_display ();
        
        // Connect copy button signals
        copy_fingerprint_button.clicked.connect (copy_fingerprint);
        copy_private_path_button.clicked.connect (copy_private_path);
        copy_public_path_button.clicked.connect (copy_public_path);
        copy_public_key_button.clicked.connect (copy_public_key_content);
    }
    
    private void update_display () {
        // Set key type
        key_type_row.set_subtitle (ssh_key.get_type_description ());
        
        // Set fingerprint
        fingerprint_row.set_subtitle (ssh_key.fingerprint);
        
        // Set comment (always visible)
        if (ssh_key.comment != null && ssh_key.comment.strip () != "") {
            comment_row.set_subtitle (ssh_key.comment);
        } else {
            comment_row.set_subtitle (_("(No comment)"));
        }
        
        // Set paths
        private_path_row.set_subtitle (ssh_key.private_path.get_path ());
        public_path_row.set_subtitle (ssh_key.public_path.get_path ());
        
        // Set file permissions
        set_file_permissions ();
        
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
    
    private void set_file_permissions () {
        try {
            // Get private key permissions
            var private_info = ssh_key.private_path.query_info (FileAttribute.UNIX_MODE, FileQueryInfoFlags.NONE);
            var private_mode = private_info.get_attribute_uint32 (FileAttribute.UNIX_MODE);
            var private_permissions = private_mode & 0x1FF; // Last 9 bits (permissions)
            var private_perm_str = format_permissions (private_permissions);
            
            // Check if private key has secure permissions
            if (private_permissions == KeyMaker.Filesystem.PERM_FILE_PRIVATE) {
                private_permissions_row.set_subtitle (@"$private_perm_str ✓");
                private_permissions_row.remove_css_class ("error");
            } else {
                private_permissions_row.set_subtitle (@"$private_perm_str ⚠️ (should be 600)");
                private_permissions_row.add_css_class ("error");
            }
            
        } catch (Error e) {
            private_permissions_row.set_subtitle (_("Error reading permissions"));
            warning ("Failed to get private key permissions: %s", e.message);
        }
        
        try {
            // Get public key permissions
            var public_info = ssh_key.public_path.query_info (FileAttribute.UNIX_MODE, FileQueryInfoFlags.NONE);
            var public_mode = public_info.get_attribute_uint32 (FileAttribute.UNIX_MODE);
            var public_permissions = public_mode & 0x1FF; // Last 9 bits (permissions)
            var public_perm_str = format_permissions (public_permissions);
            
            // Check if public key has appropriate permissions (644 or 600)
            if (public_permissions == KeyMaker.Filesystem.PERM_FILE_PUBLIC || 
                public_permissions == KeyMaker.Filesystem.PERM_FILE_PRIVATE) {
                public_permissions_row.set_subtitle (@"$public_perm_str ✓");
                public_permissions_row.remove_css_class ("error");
            } else {
                public_permissions_row.set_subtitle (@"$public_perm_str ⚠️ (should be 644 or 600)");
                public_permissions_row.add_css_class ("error");
            }
            
        } catch (Error e) {
            public_permissions_row.set_subtitle (_("Error reading permissions"));
            warning ("Failed to get public key permissions: %s", e.message);
        }
    }
    
    private string format_permissions (uint32 permissions) {
        var octal = "%03o".printf (permissions);
        var owner = format_permission_triplet ((permissions >> 6) & 0x7);
        var group = format_permission_triplet ((permissions >> 3) & 0x7);
        var other = format_permission_triplet (permissions & 0x7);
        return @"$octal ($owner$group$other)";
    }
    
    private string format_permission_triplet (uint32 triplet) {
        var result = new StringBuilder ();
        result.append ((triplet & 0x4) != 0 ? "r" : "-");
        result.append ((triplet & 0x2) != 0 ? "w" : "-");
        result.append ((triplet & 0x1) != 0 ? "x" : "-");
        return result.str;
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
    
    private void copy_fingerprint () {
        var clipboard = get_clipboard ();
        clipboard.set_text (ssh_key.fingerprint);
    }
    
    private void copy_private_path () {
        var clipboard = get_clipboard ();
        clipboard.set_text (ssh_key.private_path.get_path ());
    }
    
    private void copy_public_path () {
        var clipboard = get_clipboard ();
        clipboard.set_text (ssh_key.public_path.get_path ());
    }
    
    private void copy_public_key_content () {
        try {
            var content = SSHOperations.get_public_key_content (ssh_key);
            var clipboard = get_clipboard ();
            clipboard.set_text (content.strip());
        } catch (KeyMakerError e) {
            warning ("Failed to copy public key content: %s", e.message);
        }
    }
}