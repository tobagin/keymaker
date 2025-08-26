/*
 * Key Maker - Preferences Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/preferences_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/preferences_dialog.ui")]
#endif
public class KeyMaker.PreferencesDialog : Adw.PreferencesDialog {
    [GtkChild]
    private unowned Adw.ComboRow theme_row;
    
    [GtkChild]
    private unowned Adw.ComboRow default_key_type_row;
    
    [GtkChild]
    private unowned Adw.ComboRow default_rsa_bits_row;
    
    [GtkChild]
    private unowned Adw.EntryRow default_comment_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow use_passphrase_by_default_row;
    
    [GtkChild]
    private unowned Adw.SpinRow auto_refresh_interval_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow confirm_deletions_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow show_fingerprints_row;
    
    private Settings settings;
    private Gtk.StringList theme_model;
    private Gtk.StringList key_type_model;
    private Gtk.StringList rsa_bits_model;
    
    
    public PreferencesDialog (Gtk.Window parent) {
        Object ();
    }
    
    construct {
        // Get settings
#if DEVELOPMENT
        settings = new Settings ("io.github.tobagin.keysmith.Devel");
#else
        settings = new Settings ("io.github.tobagin.keysmith");
#endif
        
        // Setup theme model
        theme_model = new Gtk.StringList (null);
        theme_model.append (_("Follow System"));
        theme_model.append (_("Light"));
        theme_model.append (_("Dark"));
        theme_row.set_model (theme_model);
        
        // Setup default key type model
        key_type_model = new Gtk.StringList (null);
        key_type_model.append (_("Ed25519"));
        key_type_model.append (_("RSA"));
        key_type_model.append (_("ECDSA"));
        default_key_type_row.set_model (key_type_model);
        
        // Setup RSA bits model
        rsa_bits_model = new Gtk.StringList (null);
        rsa_bits_model.append ("2048");
        rsa_bits_model.append ("3072");
        rsa_bits_model.append ("4096");
        rsa_bits_model.append ("8192");
        default_rsa_bits_row.set_model (rsa_bits_model);
        
        // Load current settings
        load_settings ();
        
        // Connect signals
        theme_row.notify["selected"].connect (on_theme_changed);
        default_key_type_row.notify["selected"].connect (on_default_key_type_changed);
        default_rsa_bits_row.notify["selected"].connect (on_default_rsa_bits_changed);
        default_comment_row.notify["text"].connect (on_default_comment_changed);
        use_passphrase_by_default_row.notify["active"].connect (on_use_passphrase_by_default_changed);
        auto_refresh_interval_row.notify["value"].connect (on_auto_refresh_interval_changed);
        confirm_deletions_row.notify["active"].connect (on_confirm_deletions_changed);
        show_fingerprints_row.notify["active"].connect (on_show_fingerprints_changed);
    }
    
    private void load_settings () {
        // Load theme setting
        var theme = settings.get_string ("theme");
        switch (theme) {
            case "light":
                theme_row.set_selected (1);
                break;
            case "dark":
                theme_row.set_selected (2);
                break;
            default: // "auto"
                theme_row.set_selected (0);
                break;
        }
        
        // Load default key type
        var default_key_type = settings.get_string ("default-key-type");
        switch (default_key_type) {
            case "rsa":
                default_key_type_row.set_selected (1);
                break;
            case "ecdsa":
                default_key_type_row.set_selected (2);
                break;
            default: // "ed25519"
                default_key_type_row.set_selected (0);
                break;
        }
        
        // Load default RSA bits
        var default_rsa_bits = settings.get_int ("default-rsa-bits");
        switch (default_rsa_bits) {
            case 2048:
                default_rsa_bits_row.set_selected (0);
                break;
            case 3072:
                default_rsa_bits_row.set_selected (1);
                break;
            case 4096:
                default_rsa_bits_row.set_selected (2);
                break;
            case 8192:
                default_rsa_bits_row.set_selected (3);
                break;
            default:
                default_rsa_bits_row.set_selected (2); // 4096
                break;
        }
        
        // Load default comment
        var default_comment = settings.get_string ("default-comment");
        default_comment_row.set_text (default_comment);
        
        // Load use passphrase by default
        var use_passphrase_by_default = settings.get_boolean ("use-passphrase-by-default");
        use_passphrase_by_default_row.set_active (use_passphrase_by_default);
        
        // Load auto refresh interval
        var auto_refresh_interval = settings.get_int ("auto-refresh-interval");
        auto_refresh_interval_row.set_value (auto_refresh_interval);
        
        // Load confirm deletions
        var confirm_deletions = settings.get_boolean ("confirm-deletions");
        confirm_deletions_row.set_active (confirm_deletions);
        
        // Load show fingerprints
        var show_fingerprints = settings.get_boolean ("show-fingerprints");
        show_fingerprints_row.set_active (show_fingerprints);
    }
    
    private void on_theme_changed () {
        string theme;
        switch (theme_row.get_selected ()) {
            case 1:
                theme = "light";
                break;
            case 2:
                theme = "dark";
                break;
            default:
                theme = "auto";
                break;
        }
        settings.set_string ("theme", theme);
    }
    
    private void on_default_key_type_changed () {
        string key_type;
        switch (default_key_type_row.get_selected ()) {
            case 1:
                key_type = "rsa";
                break;
            case 2:
                key_type = "ecdsa";
                break;
            default:
                key_type = "ed25519";
                break;
        }
        settings.set_string ("default-key-type", key_type);
    }
    
    private void on_default_rsa_bits_changed () {
        int rsa_bits;
        switch (default_rsa_bits_row.get_selected ()) {
            case 0:
                rsa_bits = 2048;
                break;
            case 1:
                rsa_bits = 3072;
                break;
            case 2:
                rsa_bits = 4096;
                break;
            case 3:
                rsa_bits = 8192;
                break;
            default:
                rsa_bits = 4096;
                break;
        }
        settings.set_int ("default-rsa-bits", rsa_bits);
    }
    
    private void on_default_comment_changed () {
        var comment = default_comment_row.get_text ();
        settings.set_string ("default-comment", comment);
    }
    
    private void on_use_passphrase_by_default_changed () {
        var active = use_passphrase_by_default_row.get_active ();
        settings.set_boolean ("use-passphrase-by-default", active);
    }
    
    private void on_auto_refresh_interval_changed () {
        var value = (int) auto_refresh_interval_row.get_value ();
        settings.set_int ("auto-refresh-interval", value);
    }
    
    private void on_confirm_deletions_changed () {
        var active = confirm_deletions_row.get_active ();
        
        if (!active) {
            // Warn user about disabling delete confirmations
            show_deletion_warning.begin ();
        } else {
            settings.set_boolean ("confirm-deletions", active);
        }
    }
    
    private async void show_deletion_warning () {
        var warning_dialog = new Adw.MessageDialog (
            (Gtk.Window) get_root (),
            _("Disable Delete Confirmations?"),
            _("Disabling delete confirmations is not recommended. SSH keys that are deleted cannot be restored.\n\nAre you sure you want to continue?")
        );
        
        warning_dialog.add_response ("cancel", _("Cancel"));
        warning_dialog.add_response ("disable", _("Disable Confirmations"));
        warning_dialog.set_response_appearance ("disable", Adw.ResponseAppearance.DESTRUCTIVE);
        warning_dialog.set_default_response ("cancel");
        warning_dialog.set_close_response ("cancel");
        
        var response = yield warning_dialog.choose (null);
        
        if (response == "disable") {
            // User confirmed, disable confirmations
            settings.set_boolean ("confirm-deletions", false);
        } else {
            // User canceled, restore the switch to on
            confirm_deletions_row.set_active (true);
        }
    }
    
    private void on_show_fingerprints_changed () {
        var active = show_fingerprints_row.get_active ();
        settings.set_boolean ("show-fingerprints", active);
    }
}