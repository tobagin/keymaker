/*
 * Key Maker - Help Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

public class KeyMaker.HelpDialog : Adw.MessageDialog {
    
    public HelpDialog (Gtk.Window parent) {
        Object ();
    }
    
    construct {
        // Configure the help dialog
        set_heading (_("Key Maker Help"));
        
        var help_text = _("""Key Maker is a modern SSH key management application.

<b>Generating SSH Keys:</b>
• Click the "+" button to create a new SSH key
• Ed25519 keys are recommended for best security
• Use a strong passphrase to protect your private key

<b>Managing Keys:</b>
• Click the copy button to copy the public key
• Use the server button to generate ssh-copy-id commands
• Click the info button to view detailed key information

<b>Security Tips:</b>
• Always use passphrases for important keys
• Regularly rotate your SSH keys
• Keep your private keys secure and never share them

For more information, visit the project website.""");
        
        set_body (help_text);
        set_body_use_markup (true);
        
        // Add response
        add_response ("close", _("Close"));
        set_default_response ("close");
        set_close_response ("close");
    }
}