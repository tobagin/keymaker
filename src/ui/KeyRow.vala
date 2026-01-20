/*
 * SSHer - Key Row Widget
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/key_row.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/key_row.ui")]
#endif
public class KeyMaker.KeyRowWidget : Adw.ActionRow {
    [GtkChild]
    private unowned Gtk.Image key_icon;
    
    [GtkChild]
    private unowned Gtk.Label key_type_label;
    
    [GtkChild]
    private unowned Gtk.Button copy_button;
    
    [GtkChild]
    private unowned Gtk.Button details_button;
    
    [GtkChild]
    private unowned Gtk.Button copy_id_button;
    
    [GtkChild]
    private unowned Gtk.Button change_passphrase_button;
    
    [GtkChild]
    private unowned Gtk.Button delete_button;
    
    [GtkChild]
    private unowned Gtk.Box desktop_buttons_box;

    [GtkChild]
    private unowned Gtk.Button mobile_menu_button;

    public SSHKey ssh_key { get; construct; }

    // Signals
    public signal void copy_requested (SSHKey ssh_key);
    public signal void delete_requested (SSHKey ssh_key);
    public signal void details_requested (SSHKey ssh_key);
    public signal void passphrase_change_requested (SSHKey ssh_key);
    public signal void copy_id_requested (SSHKey ssh_key);
    
    
    public KeyRowWidget (SSHKey ssh_key) {
        Object (ssh_key: ssh_key);
    }
    
    construct {
        // Listen for settings changes
        SettingsManager.app.changed["show-fingerprints"].connect (() => {
            update_display ();
        });
        
        // Connect desktop button signals
        copy_button.clicked.connect (() => copy_requested (ssh_key));
        details_button.clicked.connect (() => details_requested (ssh_key));
        copy_id_button.clicked.connect (() => copy_id_requested (ssh_key));
        change_passphrase_button.clicked.connect (() => passphrase_change_requested (ssh_key));
        delete_button.clicked.connect (() => delete_requested (ssh_key));

        // Connect mobile menu button
        mobile_menu_button.clicked.connect (show_mobile_menu);
        
        // Update display
        update_display ();
        
        // Update passphrase button asynchronously
        update_passphrase_button.begin ();
    }
    
    private void show_mobile_menu () {
        var sheet = new Adw.Dialog ();
        sheet.title = _("Actions"); // Good practice to set title for dialogs
        
        // Main container
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.margin_top = 12;
        box.margin_bottom = 12;
        box.margin_start = 12;
        box.margin_end = 12;
        box.spacing = 12;
        
        // Actions Group
        var actions_group = new Adw.PreferencesGroup ();
        
        // Details
        var row_details = new Adw.ButtonRow ();
        row_details.title = _("View Details");
        row_details.start_icon_name = "view-reveal-symbolic";
        row_details.activated.connect (() => {
            sheet.close ();
            details_requested (ssh_key);
        });
        actions_group.add (row_details);
        
        // Copy Public Key
        var row_copy = new Adw.ButtonRow ();
        row_copy.title = _("Copy Public Key");
        row_copy.start_icon_name = "edit-copy-symbolic";
        row_copy.activated.connect (() => {
            sheet.close ();
            copy_requested (ssh_key);
        });
        actions_group.add (row_copy);
        
        // Copy to Server
        var row_copy_id = new Adw.ButtonRow ();
        row_copy_id.title = _("Copy to Server");
        row_copy_id.start_icon_name = "network-server-symbolic";
        row_copy.activated.connect (() => {
            sheet.close ();
            copy_id_requested (ssh_key);
        });
        actions_group.add (row_copy_id);
        
        // Passphrase
        var row_passphrase = new Adw.ButtonRow ();
        // Determine label based on current state (async check would be ideal but we use cached state or check)
        // For simplicity and UX speed, we use the same text logic as the desktop button tooltip if possible, 
        // or re-check. Since we can't easily sync-wait here, we'll check the desktop button's tooltip 
        // which acts as a proxy for the state, or use a generic "Manage Passphrase".
        // A better approach is to store the state. 
        // For now, let's use "Change/Add Passphrase" based on the button tooltip which is updated by update_passphrase_button.
        string passphrase_label = change_passphrase_button.tooltip_text ?? _("Change Passphrase");
        row_passphrase.title = passphrase_label;
        row_passphrase.start_icon_name = "io.github.tobagin.keysmith-change-passphrase-symbolic";
        row_passphrase.activated.connect (() => {
            sheet.close ();
            passphrase_change_requested (ssh_key);
        });
        actions_group.add (row_passphrase);
        
        box.append (actions_group);
        
        // Destructive Group
        var destructive_group = new Adw.PreferencesGroup ();
        
        // Delete
        var row_delete = new Adw.ButtonRow ();
        row_delete.title = _("Delete Key");
        row_delete.start_icon_name = "io.github.tobagin.keysmith-remove-symbolic";
        row_delete.add_css_class ("destructive-action");
        row_delete.activated.connect (() => {
            sheet.close ();
            delete_requested (ssh_key);
        });
        destructive_group.add (row_delete);
        
        box.append (destructive_group);
        
        // Set content and present
        sheet.child = box;
        var root = this.get_root () as Gtk.Widget;
        sheet.present (root);
    }

    public void set_mobile_mode (bool mobile) {
        desktop_buttons_box.visible = !mobile;
        mobile_menu_button.visible = mobile;
    }
    
    private void update_display () {
        // Set title and subtitle using ActionRow properties
        set_title (ssh_key.get_display_name ());
        
        // Build subtitle based on settings
        var show_fingerprints = SettingsManager.show_fingerprints;
        var subtitle_parts = new GenericArray<string> ();
        
        if (show_fingerprints) {
            subtitle_parts.add (ssh_key.fingerprint);
        }
        
        if (ssh_key.comment != null && ssh_key.comment.strip () != "") {
            subtitle_parts.add (ssh_key.comment.strip ());
        }
        
        if (subtitle_parts.length > 0) {
            var parts_array = new string[subtitle_parts.length + 1];
            for (int i = 0; i < subtitle_parts.length; i++) {
                parts_array[i] = subtitle_parts[i];
            }
            parts_array[subtitle_parts.length] = null;
            var subtitle = string.joinv (" • ", parts_array);
            set_subtitle (subtitle);
        } else {
            set_subtitle ("");
        }
        
        // Set key type label with color coding
        key_type_label.set_text (ssh_key.get_type_description ());
        update_key_type_styling ();
    }
    
    private void update_key_type_styling () {
        // Remove existing style classes
        key_type_label.remove_css_class ("success");
        key_type_label.remove_css_class ("accent");
        key_type_label.remove_css_class ("warning");
        key_type_label.remove_css_class ("error");
        key_icon.remove_css_class ("success");
        key_icon.remove_css_class ("accent");
        key_icon.remove_css_class ("warning");
        key_icon.remove_css_class ("error");
        
        // Apply color coding and icons based on key type
        switch (ssh_key.key_type) {
            case SSHKeyType.ED25519:
                // Green for ED25519 (most secure)
                key_type_label.add_css_class ("success");
                key_icon.add_css_class ("success");
                key_icon.icon_name = ssh_key.key_type.get_icon_name ();
                break;
            case SSHKeyType.RSA:
                // Blue/accent for RSA (good compatibility)
                key_type_label.add_css_class ("accent");
                key_icon.add_css_class ("accent");
                key_icon.icon_name = ssh_key.key_type.get_icon_name ();
                break;
            case SSHKeyType.ECDSA:
                // Yellow/warning for ECDSA (compatibility issues)
                key_type_label.add_css_class ("warning");
                key_icon.add_css_class ("warning");
                key_icon.icon_name = ssh_key.key_type.get_icon_name ();
                break;
        }
    }
    
    private async void update_passphrase_button () {
        try {
            bool has_passphrase = yield SSHMetadata.has_passphrase (ssh_key);
            
            if (has_passphrase) {
                change_passphrase_button.set_tooltip_text (_("Change Passphrase"));
            } else {
                change_passphrase_button.set_tooltip_text (_("Add Passphrase"));
            }
            
        } catch (KeyMakerError e) {
            // Default to "Change Passphrase" if detection fails
            change_passphrase_button.set_tooltip_text (_("Change Passphrase"));
        }
    }
    
    public void refresh () {
        update_display ();
        // Also update passphrase button when refreshing
        update_passphrase_button.begin ();
    }
    
}