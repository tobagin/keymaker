/*
 * Key Maker - Tunnels Page
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/tunnels_page.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/tunnels_page.ui")]
#endif
public class KeyMaker.TunnelsPage : Adw.Bin {
    [GtkChild]
    private unowned Gtk.Button create_tunnel_button;
    [GtkChild]
    private unowned Adw.PreferencesGroup active_tunnels_group;
    [GtkChild]
    private unowned Adw.PreferencesGroup saved_tunnels_group;
    
    private GenericArray<ActiveTunnel> active_tunnels;
    private GenericArray<TunnelConfiguration> saved_tunnels;
    
    // Signals for window integration
    public signal void show_toast_requested (string message);
    
    construct {
        active_tunnels = new GenericArray<ActiveTunnel> ();
        saved_tunnels = new GenericArray<TunnelConfiguration> ();
        
        // Setup button signals
        create_tunnel_button.clicked.connect (on_create_tunnel_clicked);
        
        // Load tunnel data
        refresh_tunnel_data ();
    }
    
    private void on_create_tunnel_clicked () {
        var dialog = new KeyMaker.CreateTunnelDialog (get_root () as Gtk.Window);
        dialog.present (get_root () as Gtk.Window);
    }
    
    private void on_tunnel_created (TunnelConfiguration config) {
        // Add to saved tunnels
        saved_tunnels.add (config);
        
        refresh_saved_tunnels_display ();
        show_toast_requested (_("Tunnel configuration '%s' created successfully").printf (config.name));
    }
    
    public void refresh_tunnel_data () {
        refresh_active_tunnels_display ();
        refresh_saved_tunnels_display ();
    }
    
    private void refresh_active_tunnels_display () {
        // Clear current display
        var child = active_tunnels_group.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            if (child is Adw.ActionRow) {
                active_tunnels_group.remove (child);
            }
            child = next;
        }
        
        // Load active tunnels from system
        try {
            // This would normally check running SSH processes
            // For now, we'll show placeholder content
            
            if (active_tunnels.length == 0) {
                var placeholder_row = new Adw.ActionRow ();
                placeholder_row.title = _("No active tunnels");
                placeholder_row.subtitle = _("Start a tunnel from saved configurations or create a new one");
                placeholder_row.sensitive = false;
                
                var prefix_icon = new Gtk.Image ();
                prefix_icon.icon_name = "network-vpn-symbolic";
                prefix_icon.icon_size = Gtk.IconSize.LARGE;
                placeholder_row.add_prefix (prefix_icon);
                
                active_tunnels_group.add (placeholder_row);
            } else {
                for (int i = 0; i < active_tunnels.length; i++) {
                    var tunnel = active_tunnels[i];
                    var row = create_active_tunnel_row (tunnel);
                    active_tunnels_group.add (row);
                }
            }
            
        } catch (Error e) {
            warning ("Failed to load active tunnels: %s", e.message);
            show_toast_requested (_("Failed to load active tunnels: %s").printf (e.message));
        }
    }
    
    private void refresh_saved_tunnels_display () {
        // Clear current display
        var child = saved_tunnels_group.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            if (child is Adw.ActionRow) {
                saved_tunnels_group.remove (child);
            }
            child = next;
        }
        
        // Load saved tunnel configurations
        try {
            // This would normally load from configuration storage
            // For now, we'll show placeholder content
            
            if (saved_tunnels.length == 0) {
                var placeholder_row = new Adw.ActionRow ();
                placeholder_row.title = _("No saved tunnel configurations");
                placeholder_row.subtitle = _("Create reusable tunnel setups for quick access");
                placeholder_row.sensitive = false;
                
                var prefix_icon = new Gtk.Image ();
                prefix_icon.icon_name = "folder-symbolic";
                prefix_icon.icon_size = Gtk.IconSize.LARGE;
                placeholder_row.add_prefix (prefix_icon);
                
                saved_tunnels_group.add (placeholder_row);
            } else {
                for (int i = 0; i < saved_tunnels.length; i++) {
                    var config = saved_tunnels[i];
                    var row = create_saved_tunnel_row (config);
                    saved_tunnels_group.add (row);
                }
            }
            
        } catch (Error e) {
            warning ("Failed to load saved tunnels: %s", e.message);
            show_toast_requested (_("Failed to load saved tunnels: %s").printf (e.message));
        }
    }
    
    private Adw.ActionRow create_active_tunnel_row (ActiveTunnel tunnel) {
        var row = new Adw.ActionRow ();
        row.title = tunnel.config.name;
        row.subtitle = @"$(tunnel.config.local_port) → $(tunnel.config.remote_host):$(tunnel.config.remote_port)";
        
        // Add prefix icon with connection status
        var prefix_icon = new Gtk.Image ();
        prefix_icon.icon_name = "network-vpn-symbolic";
        prefix_icon.icon_size = Gtk.IconSize.LARGE;
        prefix_icon.add_css_class ("success"); // Green for active
        row.add_prefix (prefix_icon);
        
        // Add connection status
        var status_indicator = new Gtk.Label (_("Connected"));
        status_indicator.add_css_class ("success");
        status_indicator.add_css_class ("caption");
        row.add_suffix (status_indicator);
        
        // Add action buttons
        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        button_box.add_css_class ("linked");
        
        var stop_button = new Gtk.Button.from_icon_name ("media-playback-stop-symbolic");
        stop_button.tooltip_text = _("Stop Tunnel");
        stop_button.add_css_class ("flat");
        stop_button.add_css_class ("destructive-action");
        stop_button.clicked.connect (() => on_stop_tunnel_clicked (tunnel));
        
        var details_button = new Gtk.Button.from_icon_name ("dialog-information-symbolic");
        details_button.tooltip_text = _("View Details");
        details_button.add_css_class ("flat");
        details_button.clicked.connect (() => on_tunnel_details_clicked (tunnel));
        
        button_box.append (stop_button);
        button_box.append (details_button);
        row.add_suffix (button_box);
        
        return row;
    }
    
    private Adw.ActionRow create_saved_tunnel_row (TunnelConfiguration config) {
        var row = new Adw.ActionRow ();
        row.title = config.name;
        
        var subtitle = new StringBuilder ();
        subtitle.append (@"$(config.tunnel_type.to_string ()) ");
        if (config.local_port > 0) {
            subtitle.append (@"$(config.local_port) → ");
        }
        subtitle.append (@"$(config.remote_host):$(config.remote_port)");
        row.subtitle = subtitle.str;
        
        // Add prefix icon based on tunnel type
        var prefix_icon = new Gtk.Image ();
        prefix_icon.icon_name = config.tunnel_type.get_icon_name ();
        prefix_icon.icon_size = Gtk.IconSize.LARGE;
        row.add_prefix (prefix_icon);
        
        // Add action buttons
        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        button_box.add_css_class ("linked");
        
        var start_button = new Gtk.Button.from_icon_name ("media-playback-start-symbolic");
        start_button.tooltip_text = _("Start Tunnel");
        start_button.add_css_class ("flat");
        start_button.add_css_class ("suggested-action");
        start_button.clicked.connect (() => on_start_tunnel_clicked (config));
        
        var edit_button = new Gtk.Button.from_icon_name ("document-edit-symbolic");
        edit_button.tooltip_text = _("Edit Configuration");
        edit_button.add_css_class ("flat");
        edit_button.clicked.connect (() => on_edit_tunnel_clicked (config));
        
        var delete_button = new Gtk.Button.from_icon_name ("edit-delete-symbolic");
        delete_button.tooltip_text = _("Delete Configuration");
        delete_button.add_css_class ("flat");
        delete_button.add_css_class ("destructive-action");
        delete_button.clicked.connect (() => on_delete_tunnel_clicked (config));
        
        button_box.append (start_button);
        button_box.append (edit_button);
        button_box.append (delete_button);
        row.add_suffix (button_box);
        
        return row;
    }
    
    private void on_start_tunnel_clicked (TunnelConfiguration config) {
        // This would start the SSH tunnel
        show_toast_requested (_("Starting tunnel '%s'").printf (config.name));
    }
    
    private void on_stop_tunnel_clicked (ActiveTunnel tunnel) {
        // This would stop the active tunnel
        show_toast_requested (_("Stopping tunnel '%s'").printf (tunnel.config.name));
    }
    
    private void on_edit_tunnel_clicked (TunnelConfiguration config) {
        var dialog = new KeyMaker.CreateTunnelDialog (get_root () as Gtk.Window, config);
        dialog.present (get_root () as Gtk.Window);
    }
    
    private void on_delete_tunnel_clicked (TunnelConfiguration config) {
        // Remove from local list
        for (int i = 0; i < saved_tunnels.length; i++) {
            if (saved_tunnels[i].name == config.name) {
                saved_tunnels.remove_index (i);
                break;
            }
        }
        
        refresh_saved_tunnels_display ();
        show_toast_requested (_("Tunnel configuration '%s' deleted").printf (config.name));
    }
    
    private void on_tunnel_details_clicked (ActiveTunnel tunnel) {
        // This would show tunnel connection details
        show_toast_requested (_("Tunnel details not yet implemented"));
    }
    
    private void on_tunnel_updated (TunnelConfiguration config) {
        // Update existing config in the list
        for (int i = 0; i < saved_tunnels.length; i++) {
            if (saved_tunnels[i].name == config.name) {
                saved_tunnels[i] = config;
                break;
            }
        }
        
        refresh_saved_tunnels_display ();
        show_toast_requested (_("Tunnel configuration '%s' updated").printf (config.name));
    }
}