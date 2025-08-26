/*
 * Key Maker - Keyboard Shortcuts Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/shortcuts_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/shortcuts_dialog.ui")]
#endif
public class KeyMaker.ShortcutsDialog : Adw.Dialog {
    
    public ShortcutsDialog () {
        Object ();
    }
    
    public static void show (Gtk.Window? parent = null) {
        var dialog = new KeyMaker.ShortcutsDialog ();
        dialog.present (parent);
    }
}