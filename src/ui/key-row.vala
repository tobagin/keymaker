/*
 * Key Maker - Key Row Widget
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
    
    public SSHKey ssh_key { get; construct; }
    private Settings settings;
    
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
        // Get settings
#if DEVELOPMENT
        settings = new Settings ("io.github.tobagin.keysmith.Devel");
#else
        settings = new Settings ("io.github.tobagin.keysmith");
#endif
        
        // Listen for settings changes
        settings.changed["show-fingerprints"].connect (() => {
            update_display ();
        });
        
        // Connect button signals
        copy_button.clicked.connect (() => copy_requested (ssh_key));
        details_button.clicked.connect (() => details_requested (ssh_key));
        copy_id_button.clicked.connect (() => copy_id_requested (ssh_key));
        change_passphrase_button.clicked.connect (() => passphrase_change_requested (ssh_key));
        delete_button.clicked.connect (() => delete_requested (ssh_key));
        
        // Update display
        update_display ();
    }
    
    private void update_display () {
        // Set title and subtitle using ActionRow properties
        set_title (ssh_key.get_display_name ());
        
        // Build subtitle based on settings
        var show_fingerprints = settings.get_boolean ("show-fingerprints");
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
                key_icon.icon_name = "security-high-symbolic";
                break;
            case SSHKeyType.RSA:
                // Blue/accent for RSA (good compatibility)
                key_type_label.add_css_class ("accent");
                key_icon.add_css_class ("accent");
                key_icon.icon_name = "security-medium-symbolic";
                break;
            case SSHKeyType.ECDSA:
                // Yellow/warning for ECDSA (compatibility issues)
                key_type_label.add_css_class ("warning");
                key_icon.add_css_class ("warning");
                key_icon.icon_name = "security-low-symbolic";
                break;
        }
    }
    
    public void refresh () {
        update_display ();
    }
    
}