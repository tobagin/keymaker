/*
 * Key Maker - Change Passphrase Dialog
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
    
    
    public ChangePassphraseDialog (Gtk.Window parent, SSHKey ssh_key) {
        Object (
            ssh_key: ssh_key
        );
    }
    
    construct {
        // Set key information
        // Key info shown in dialog title
        
        // Connect validation signals
        new_passphrase_row.notify["text"].connect (validate_form);
        confirm_passphrase_row.notify["text"].connect (validate_form);
        
        // Initial validation
        validate_form ();
    }
    
    private void validate_form () {
        var new_passphrase = new_passphrase_row.get_text ();
        var confirm_passphrase = confirm_passphrase_row.get_text ();
        
        var is_valid = new_passphrase == confirm_passphrase;
        change_button.set_sensitive (is_valid);
        
        if (!is_valid && confirm_passphrase.length > 0) {
            // Could show error message if needed
        }
    }
    
    
    
    private async void change_passphrase_async () {
        // Disable the change button to prevent double-clicking
        change_button.set_sensitive (false);
        change_button.set_label (_("Changing..."));
        
        try {
            // Create request
            var request = new PassphraseChangeRequest (ssh_key) {
                current_passphrase = current_passphrase_row.get_text () != "" ? current_passphrase_row.get_text () : null,
                new_passphrase = new_passphrase_row.get_text () != "" ? new_passphrase_row.get_text () : null
            };
            
            // Change the passphrase
            yield SSHOperations.change_passphrase (request);
            
            // Emit signal and close dialog
            passphrase_changed (ssh_key);
            close ();
            
        } catch (KeyMakerError e) {
            warning ("Failed to change passphrase: %s", e.message);
            warning ("Failed to change passphrase: %s", e.message);
            
            // Re-enable the button
            change_button.set_sensitive (true);
            change_button.set_label (_("Change Passphrase"));
        }
    }
    
    // Toast functionality removed - no overlay in this template
}