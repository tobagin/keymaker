/*
 * Key Maker - Copy ID Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/copy_id_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/copy_id_dialog.ui")]
#endif
public class KeyMaker.CopyIdDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.EntryRow hostname_row;
    
    [GtkChild]
    private unowned Adw.EntryRow username_row;
    
    [GtkChild]
    private unowned Adw.SpinRow port_row;
    
    [GtkChild]
    private unowned Gtk.Button copy_button;
    
    [GtkChild]
    private unowned Gtk.Box progress_box;
    
    [GtkChild]
    private unowned Gtk.Spinner progress_spinner;
    
    public SSHKey ssh_key { get; construct; }
    
    
    public CopyIdDialog (Gtk.Window parent, SSHKey ssh_key) {
        Object (
            ssh_key: ssh_key
        );
    }
    
    construct {
        // Set key information
        // Set dialog title with key information in the window title
        
        // Setup port spin button
        port_row.set_range (1, 65535);
        port_row.set_value (22);
        // Note: set_increments is not available in this version of libadwaita
        
        // Connect signals for form validation
        hostname_row.notify["text"].connect (validate_form);
        username_row.notify["text"].connect (validate_form);
        
        
        // Set initial focus
        hostname_row.grab_focus ();
        
        // Initial form validation
        validate_form ();
    }
    
    private void validate_form () {
        var hostname = hostname_row.get_text ().strip ();
        var username = username_row.get_text ().strip ();
        
        // Enable copy button only if both hostname and username are filled
        copy_button.set_sensitive (hostname != "" && username != "");
    }
    
    // Toast functionality removed - no overlay in this template
}