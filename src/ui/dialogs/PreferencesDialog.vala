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
    
    [GtkChild]
    private unowned Adw.ComboRow preferred_terminal_row;

    private Gtk.StringList theme_model;
    private Gtk.StringList key_type_model;
    private Gtk.StringList rsa_bits_model;
    private Gtk.StringList terminal_model;
    
    
    public PreferencesDialog (Gtk.Window parent) {
        Object ();
    }
    
    construct {
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
        
        // Setup terminal model
        terminal_model = new Gtk.StringList (null);
        terminal_model.append (_("Auto (Detect Automatically)"));
        terminal_model.append ("Alacritty");
        terminal_model.append ("GNOME Console");
        terminal_model.append ("GNOME Terminal");
        terminal_model.append ("Kitty");
        terminal_model.append ("Konsole");
        terminal_model.append ("LXTerminal");
        terminal_model.append ("MATE Terminal");
        terminal_model.append ("Ptyxis");
        terminal_model.append ("Terminator");
        terminal_model.append ("Tilix");
        terminal_model.append ("XFCE Terminal");
        terminal_model.append ("XTerm");
        preferred_terminal_row.set_model (terminal_model);
        
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
        preferred_terminal_row.notify["selected"].connect (on_preferred_terminal_changed);
    }
    
    private void load_settings () {
        // Load theme setting
        var theme = SettingsManager.theme;
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
        var default_key_type = SettingsManager.default_key_type;
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
        var default_rsa_bits = SettingsManager.default_rsa_bits;
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
        var default_comment = SettingsManager.default_comment;
        default_comment_row.set_text (default_comment);
        
        // Load use passphrase by default
        var use_passphrase_by_default = SettingsManager.use_passphrase_by_default;
        use_passphrase_by_default_row.set_active (use_passphrase_by_default);
        
        // Load auto refresh interval
        var auto_refresh_interval = SettingsManager.auto_refresh_interval;
        auto_refresh_interval_row.set_value (auto_refresh_interval);
        
        // Load confirm deletions
        var confirm_deletions = SettingsManager.confirm_deletions;
        confirm_deletions_row.set_active (confirm_deletions);
        
        // Load show fingerprints
        var show_fingerprints = SettingsManager.show_fingerprints;
        show_fingerprints_row.set_active (show_fingerprints);
        
        // Load preferred terminal
        var preferred_terminal = SettingsManager.preferred_terminal;
        var terminal_index = 0; // Default to "Auto"
        switch (preferred_terminal) {
            case "alacritty":
                terminal_index = 1;
                break;
            case "gnome-console":
                terminal_index = 2;
                break;
            case "gnome-terminal":
                terminal_index = 3;
                break;
            case "kitty":
                terminal_index = 4;
                break;
            case "konsole":
                terminal_index = 5;
                break;
            case "lxterminal":
                terminal_index = 6;
                break;
            case "mate-terminal":
                terminal_index = 7;
                break;
            case "ptyxis":
                terminal_index = 8;
                break;
            case "terminator":
                terminal_index = 9;
                break;
            case "tilix":
                terminal_index = 10;
                break;
            case "xfce4-terminal":
                terminal_index = 11;
                break;
            case "xterm":
                terminal_index = 12;
                break;
            default: // "auto"
                terminal_index = 0;
                break;
        }
        preferred_terminal_row.set_selected (terminal_index);
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
        SettingsManager.theme = theme;
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
        SettingsManager.default_key_type = key_type;
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
        SettingsManager.default_rsa_bits = rsa_bits;
    }
    
    private void on_default_comment_changed () {
        var comment = default_comment_row.get_text ();
        SettingsManager.default_comment = comment;
    }
    
    private void on_use_passphrase_by_default_changed () {
        var active = use_passphrase_by_default_row.get_active ();
        SettingsManager.use_passphrase_by_default = active;
    }
    
    private void on_auto_refresh_interval_changed () {
        var value = (int) auto_refresh_interval_row.get_value ();
        SettingsManager.auto_refresh_interval = value;
    }
    
    private void on_confirm_deletions_changed () {
        var active = confirm_deletions_row.get_active ();
        
        if (!active) {
            // Warn user about disabling delete confirmations
            show_deletion_warning.begin ();
        } else {
            SettingsManager.confirm_deletions = active;
        }
    }
    
    private async void show_deletion_warning () {
        var warning_dialog = new Adw.AlertDialog (
            _("Disable Delete Confirmations?"),
            _("Disabling delete confirmations is not recommended. SSH keys that are deleted cannot be restored.\n\nAre you sure you want to continue?")
        );
        
        warning_dialog.add_response ("cancel", _("Cancel"));
        warning_dialog.add_response ("disable", _("Disable Confirmations"));
        warning_dialog.set_response_appearance ("disable", Adw.ResponseAppearance.DESTRUCTIVE);
        warning_dialog.set_default_response ("cancel");
        warning_dialog.set_close_response ("cancel");
        
        var response = yield warning_dialog.choose ((Gtk.Window) get_root(), null);
        
        if (response == "disable") {
            // User confirmed, disable confirmations
            SettingsManager.confirm_deletions = false;
        } else {
            // User canceled, restore the switch to on
            confirm_deletions_row.set_active (true);
        }
    }
    
    private void on_show_fingerprints_changed () {
        var active = show_fingerprints_row.get_active ();
        SettingsManager.show_fingerprints = active;
    }
    
    private void on_preferred_terminal_changed () {
        string terminal;
        switch (preferred_terminal_row.get_selected ()) {
            case 1:
                terminal = "alacritty";
                break;
            case 2:
                terminal = "gnome-console";
                break;
            case 3:
                terminal = "gnome-terminal";
                break;
            case 4:
                terminal = "kitty";
                break;
            case 5:
                terminal = "konsole";
                break;
            case 6:
                terminal = "lxterminal";
                break;
            case 7:
                terminal = "mate-terminal";
                break;
            case 8:
                terminal = "ptyxis";
                break;
            case 9:
                terminal = "terminator";
                break;
            case 10:
                terminal = "tilix";
                break;
            case 11:
                terminal = "xfce4-terminal";
                break;
            case 12:
                terminal = "xterm";
                break;
            default: // "auto"
                terminal = "auto";
                break;
        }
        SettingsManager.preferred_terminal = terminal;
    }
}