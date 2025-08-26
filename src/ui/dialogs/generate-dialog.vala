/*
 * Key Maker - Generate Key Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/generate_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/generate_dialog.ui")]
#endif
public class KeyMaker.GenerateKeyDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.EntryRow filename_row;
    
    [GtkChild]
    private unowned Adw.ComboRow key_type_row;
    
    [GtkChild]
    private unowned Adw.ComboRow rsa_bits_row;
    
    [GtkChild]
    private unowned Adw.EntryRow comment_row;
    
    [GtkChild]
    private unowned Adw.SwitchRow passphrase_switch;
    
    [GtkChild]
    private unowned Adw.PasswordEntryRow passphrase_row;
    
    [GtkChild]
    private unowned Adw.PasswordEntryRow passphrase_confirm_row;
    
    [GtkChild]
    private unowned Gtk.Label error_label;
    
    [GtkChild]
    private unowned Gtk.Button generate_button;
    
    [GtkChild]
    private unowned Gtk.Box progress_box;
    
    [GtkChild]
    private unowned Gtk.Spinner progress_spinner;
    
    // toast_overlay not available in Blueprint
    
    private Gtk.StringList key_type_model;
    private Gtk.StringList rsa_bits_model;
    private Settings settings;
    
    // Signals
    public signal void key_generated (SSHKey ssh_key);
    
    
    public GenerateKeyDialog (Gtk.Window parent) {
        Object ();
    }
    
    construct {
        // Get settings
#if DEVELOPMENT
        settings = new Settings ("io.github.tobagin.keysmith.Devel");
#else
        settings = new Settings ("io.github.tobagin.keysmith");
#endif
        
        // Setup key type model
        key_type_model = new Gtk.StringList (null);
        key_type_model.append (_("Ed25519 (Recommended)"));
        key_type_model.append (_("RSA"));
        key_type_model.append (_("ECDSA"));
        key_type_row.set_model (key_type_model);
        
        // Setup RSA bits model
        rsa_bits_model = new Gtk.StringList (null);
        rsa_bits_model.append ("2048");
        rsa_bits_model.append ("3072");
        rsa_bits_model.append ("4096");
        rsa_bits_model.append ("8192");
        rsa_bits_row.set_model (rsa_bits_model);
        
        // Connect signals
        key_type_row.notify["selected"].connect (on_key_type_changed);
        filename_row.changed.connect (validate_form);
        passphrase_row.notify["text"].connect (validate_form);
        passphrase_confirm_row.notify["text"].connect (validate_form);
        passphrase_switch.notify["active"].connect (on_passphrase_switch_changed);
        generate_button.clicked.connect (() => generate_key_async.begin ());
        
        // Load settings defaults
        load_settings_defaults ();
        
        // Set default filename
        var default_filename = generate_default_filename ();
        filename_row.set_text (default_filename);
        
        // Initial form validation
        validate_form ();
        update_rsa_bits_visibility ();
        update_passphrase_fields_visibility ();
    }
    
    private void load_settings_defaults () {
        // Load default key type
        var default_key_type = settings.get_string ("default-key-type");
        switch (default_key_type) {
            case "rsa":
                key_type_row.set_selected (1);
                break;
            case "ecdsa":
                key_type_row.set_selected (2);
                break;
            default: // "ed25519"
                key_type_row.set_selected (0);
                break;
        }
        
        // Load default RSA bits
        var default_rsa_bits = settings.get_int ("default-rsa-bits");
        switch (default_rsa_bits) {
            case 2048:
                rsa_bits_row.set_selected (0);
                break;
            case 3072:
                rsa_bits_row.set_selected (1);
                break;
            case 4096:
                rsa_bits_row.set_selected (2);
                break;
            case 8192:
                rsa_bits_row.set_selected (3);
                break;
            default:
                rsa_bits_row.set_selected (2); // 4096
                break;
        }
        
        // Load default comment
        var default_comment = settings.get_string ("default-comment");
        comment_row.set_text (default_comment);
        
        // Load use passphrase by default
        var use_passphrase_by_default = settings.get_boolean ("use-passphrase-by-default");
        passphrase_switch.set_active (use_passphrase_by_default);
    }
    
    private void on_key_type_changed () {
        update_rsa_bits_visibility ();
        
        // Update filename to reflect new key type
        var new_filename = generate_default_filename ();
        filename_row.set_text (new_filename);
        
        validate_form ();
    }
    
    private void update_rsa_bits_visibility () {
        // Show RSA bits row only for RSA keys
        var is_rsa = key_type_row.get_selected () == 1;
        rsa_bits_row.set_visible (is_rsa);
    }
    
    private void on_passphrase_switch_changed () {
        update_passphrase_fields_visibility ();
        validate_form ();
    }
    
    private void update_passphrase_fields_visibility () {
        // Enable/disable passphrase fields based on switch state
        var use_passphrase = passphrase_switch.get_active ();
        passphrase_row.set_sensitive (use_passphrase);
        passphrase_confirm_row.set_sensitive (use_passphrase);
        
        // Clear passphrase fields when disabled
        if (!use_passphrase) {
            passphrase_row.set_text ("");
            passphrase_confirm_row.set_text ("");
        }
    }
    
    private void validate_form () {
        var is_valid = true;
        var error_message = "";
        
        // Validate filename
        var filename = filename_row.get_text ().strip ();
        if (filename == "") {
            is_valid = false;
            error_message = _("Filename is required");
        } else {
            try {
                var request = new KeyGenerationRequest (filename);
                request.validate ();
            } catch (KeyMakerError e) {
                is_valid = false;
                error_message = e.message;
            }
        }
        
        // Validate passphrase confirmation only if passphrase is enabled
        if (passphrase_switch.get_active ()) {
            var passphrase = passphrase_row.get_text ();
            var confirm_passphrase = passphrase_confirm_row.get_text ();
            
            // Require non-empty passphrases when protection is enabled
            if (passphrase.strip () == "" || confirm_passphrase.strip () == "") {
                is_valid = false;
                if (error_message == "") {
                    error_message = _("Passphrase cannot be empty");
                }
            } else if (passphrase != confirm_passphrase) {
                is_valid = false;
                if (error_message == "") {
                    error_message = _("Passphrases do not match");
                }
            }
        }
        
        // Update UI
        generate_button.set_sensitive (is_valid);
        
        // Show or hide error message
        if (!is_valid && error_message != "") {
            error_label.set_text (error_message);
            error_label.set_visible (true);
        } else {
            error_label.set_visible (false);
        }
    }
    
    private string generate_default_filename () {
        var key_type = get_selected_key_type ();
        var timestamp = new DateTime.now_local ().format ("%Y%m%d_%H%M%S");
        return "id_%s_%s".printf (key_type.to_string (), timestamp);
    }
    
    private SSHKeyType get_selected_key_type () {
        switch (key_type_row.get_selected ()) {
            case 0:
                return SSHKeyType.ED25519;
            case 1:
                return SSHKeyType.RSA;
            case 2:
                return SSHKeyType.ECDSA;
            default:
                return SSHKeyType.ED25519;
        }
    }
    
    private int get_selected_rsa_bits () {
        switch (rsa_bits_row.get_selected ()) {
            case 0:
                return 2048;
            case 1:
                return 3072;
            case 2:
                return 4096;
            case 3:
                return 8192;
            default:
                return 4096;
        }
    }
    
    
    private async void generate_key_async () {
        // Disable the generate button to prevent double-clicking
        generate_button.set_sensitive (false);
        generate_button.set_label (_("Generating..."));
        
        try {
            // Create request
            var request = new KeyGenerationRequest (filename_row.get_text ().strip ()) {
                key_type = get_selected_key_type (),
                comment = comment_row.get_text ().strip (),
                passphrase = passphrase_switch.get_active () && passphrase_row.get_text () != "" ? passphrase_row.get_text () : null,
                rsa_bits = get_selected_rsa_bits ()
            };
            
            // Generate the key
            var ssh_key = yield SSHOperations.generate_key (request);
            
            // Emit signal and close dialog
            key_generated (ssh_key);
            close ();
            
        } catch (KeyMakerError e) {
            show_toast (_("Failed to generate SSH key: %s").printf (e.message));
            warning ("Failed to generate SSH key: %s", e.message);
            
            // Re-enable the button
            generate_button.set_sensitive (true);
            generate_button.set_label (_("Generate"));
        }
    }
    
    private void show_toast (string message) {
        var toast = new Adw.Toast (message) {
            timeout = 5
        };
        // toast_overlay.add_toast (toast); // TODO: Fix toast implementation
    }
}