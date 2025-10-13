/*
 * SSHer - Change Passphrase Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/change_passphrase_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/change_passphrase_dialog.ui")]
#endif
public class KeyMaker.ChangePassphraseDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.WindowTitle window_title;
    
    [GtkChild]
    private unowned Adw.PreferencesGroup current_passphrase_group;
    
    [GtkChild]
    private unowned Adw.PasswordEntryRow current_passphrase_row;
    
    [GtkChild]
    private unowned Adw.PasswordEntryRow new_passphrase_row;
    
    [GtkChild]
    private unowned Adw.PasswordEntryRow confirm_passphrase_row;
    
    [GtkChild]
    private unowned Gtk.Button change_button;
    
    [GtkChild]
    private unowned Gtk.Box progress_box;
    
    [GtkChild]
    private unowned Gtk.Spinner progress_spinner;
    
    public SSHKey ssh_key { get; construct; }
    
    // Signals
    public signal void passphrase_changed (SSHKey ssh_key);
    
    private bool key_has_passphrase = false;
    
    
    public ChangePassphraseDialog (Gtk.Window parent, SSHKey ssh_key) {
        Object (
            ssh_key: ssh_key
        );
    }
    
    construct {
        // Connect validation signals
        current_passphrase_row.notify["text"].connect (validate_form);
        new_passphrase_row.notify["text"].connect (validate_form);
        confirm_passphrase_row.notify["text"].connect (validate_form);
        
        // Connect button signals
        change_button.clicked.connect (() => {
            change_passphrase_async.begin ();
        });
        
        // Initialize dialog based on key state
        initialize_dialog.begin ();
    }
    
    private async void initialize_dialog () {
        try {
            // Check if key has passphrase
            key_has_passphrase = yield SSHMetadata.has_passphrase (ssh_key);
            
            // Update UI based on key state
            if (key_has_passphrase) {
                // Key has passphrase - show current passphrase field
                window_title.set_title (_("Change Passphrase"));
                window_title.set_subtitle (_("Update your SSH key passphrase"));
                change_button.set_label (_("Change Passphrase"));
                current_passphrase_group.set_visible (true);
            } else {
                // Key has no passphrase - hide current passphrase field
                window_title.set_title (_("Add Passphrase"));
                window_title.set_subtitle (_("Add a passphrase to your SSH key"));
                change_button.set_label (_("Add Passphrase"));
                current_passphrase_group.set_visible (false);
            }
            
            // Initial validation
            validate_form ();
            
        } catch (KeyMakerError e) {
            warning ("Failed to check passphrase status: %s", e.message);
            // Default to assuming key has passphrase for safety
            key_has_passphrase = true;
            change_button.set_label (_("Change Passphrase"));
            current_passphrase_group.set_visible (true);
            validate_form ();
        }
    }
    
    private void validate_form () {
        var current_passphrase = current_passphrase_row.get_text ();
        var new_passphrase = new_passphrase_row.get_text ();
        var confirm_passphrase = confirm_passphrase_row.get_text ();
        
        bool is_valid = false;
        
        // Check if new passphrase matches confirmation
        if (new_passphrase != confirm_passphrase) {
            is_valid = false;
        } else {
            if (key_has_passphrase) {
                // Key has passphrase - current passphrase is required
                is_valid = current_passphrase.length > 0;
            } else {
                // Key has no passphrase - require non-empty new passphrase to add one
                is_valid = new_passphrase.length > 0;
            }
        }
        
        change_button.set_sensitive (is_valid);
    }
    
    
    
    private async void change_passphrase_async () {
        var original_label = change_button.get_label ();
        
        // Disable the change button to prevent double-clicking
        change_button.set_sensitive (false);
        change_button.set_label (key_has_passphrase ? _("Changing...") : _("Adding..."));
        
        try {
            // Create request
            var current_pass = key_has_passphrase ? current_passphrase_row.get_text () : "";
            var new_pass = new_passphrase_row.get_text ();
            
            var request = new PassphraseChangeRequest (ssh_key) {
                current_passphrase = current_pass.length > 0 ? current_pass : null,
                new_passphrase = new_pass.length > 0 ? new_pass : null
            };
            
            // Change the passphrase
            yield SSHOperations.change_passphrase (request);
            
            // Emit signal and close dialog
            passphrase_changed (ssh_key);
            close ();
            
        } catch (KeyMakerError e) {
            warning ("Failed to change passphrase: %s", e.message);
            
            // Re-enable the button with original label
            change_button.set_sensitive (true);
            change_button.set_label (original_label);
        }
    }
    
    // Toast functionality removed - no overlay in this template
}