/*
 * SSHer - Keyboard Shortcuts Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

public class KeyMaker.ShortcutsDialog : GLib.Object {
    
    public static void show (Gtk.Window? parent = null) {
        try {
            #if DEVELOPMENT
            var resource_path = "/io/github/tobagin/keysmith/Devel/shortcuts_dialog.ui";
            #else
            var resource_path = "/io/github/tobagin/keysmith/shortcuts_dialog.ui";
            #endif
            
            var builder = new Gtk.Builder.from_resource (resource_path);
            var dialog = builder.get_object ("shortcuts_dialog") as Adw.ShortcutsDialog;
            
            if (dialog != null) {
                dialog.present (parent);
            } else {
                warning ("Could not find shortcuts_dialog object in %s", resource_path);
            }
        } catch (Error e) {
            warning ("Could not load shortcuts dialog: %s", e.message);
        }
    }
}