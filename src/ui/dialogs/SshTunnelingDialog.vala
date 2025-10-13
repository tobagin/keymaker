/*
 * SSHer - SSH Tunneling Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/ssh_tunneling_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/ssh_tunneling_dialog.ui")]
#endif
public class KeyMaker.SSHTunnelingDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.HeaderBar header_bar;
    
    [GtkChild]
    private unowned Gtk.Stack main_stack;
    
    [GtkChild]
    private unowned Gtk.ListBox tunnels_list;
    
    [GtkChild]
    private unowned Gtk.Button add_tunnel_button;
    
    [GtkChild]
    private unowned Adw.StatusPage empty_state_page;
    
    [GtkChild]
    private unowned Gtk.ListBox active_tunnels_list;
    
    [GtkChild]
    private unowned Adw.PreferencesGroup active_group;
    
    [GtkChild]
    private unowned Adw.PreferencesGroup saved_group;
    
    private SSHTunneling tunneling;
    
    public SSHTunnelingDialog (Gtk.Window parent) {
        Object ();
    }
    
    construct {
        tunneling = new SSHTunneling ();
        setup_signals ();
        populate_tunnels_list ();
        populate_active_tunnels_list ();
        update_ui_state ();
    }
    
    private void setup_signals () {
        if (add_tunnel_button != null) {
            add_tunnel_button.clicked.connect (on_add_tunnel);
        }
        
        if (tunneling != null) {
            tunneling.tunnel_added.connect (on_tunnel_added);
            tunneling.tunnel_removed.connect (on_tunnel_removed);
            tunneling.tunnel_started.connect (on_tunnel_started);
            tunneling.tunnel_stopped.connect (on_tunnel_stopped);
        }
    }
    
    private void populate_tunnels_list () {
        clear_tunnels_list ();
        
        var configurations = tunneling.get_configurations ();
        for (int i = 0; i < configurations.length; i++) {
            add_tunnel_row (configurations[i]);
        }
    }
    
    private void clear_tunnels_list () {
        Gtk.Widget? child = tunnels_list.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            tunnels_list.remove (child);
            child = next;
        }
    }
    
    private void add_tunnel_row (TunnelConfiguration config) {
        var row = new Adw.ExpanderRow ();
        row.title = config.name;
        row.subtitle = get_tunnel_subtitle (config);
        
        // Add type icon
        var type_icon = new Gtk.Image ();
        type_icon.icon_name = config.tunnel_type.get_icon_name ();
        row.add_prefix (type_icon);
        
        // Add status indicator and control buttons
        var status_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        
        var status_indicator = new Gtk.Image ();
        status_indicator.icon_name = "media-playback-stop-symbolic";
        status_indicator.add_css_class ("dim-label");
        status_indicator.tooltip_text = "Inactive";
        
        if (tunneling.is_tunnel_active (config)) {
            status_indicator.icon_name = "media-playback-start-symbolic";
            status_indicator.remove_css_class ("dim-label");
            status_indicator.add_css_class ("success");
            status_indicator.tooltip_text = "Active";
        }
        
        var toggle_button = new Gtk.Button ();
        toggle_button.icon_name = tunneling.is_tunnel_active (config) ? "media-playback-stop-symbolic" : "media-playback-start-symbolic";
        toggle_button.tooltip_text = tunneling.is_tunnel_active (config) ? "Stop Tunnel" : "Start Tunnel";
        toggle_button.add_css_class ("flat");
        toggle_button.clicked.connect (() => {
            toggle_tunnel.begin (config);
        });
        
        status_box.append (status_indicator);
        status_box.append (toggle_button);
        row.add_suffix (status_box);
        
        // Add details to expander
        add_tunnel_details (row, config);
        
        // Store config reference
        row.set_data<TunnelConfiguration> ("config", config);
        
        tunnels_list.append (row);
    }
    
    private string get_tunnel_subtitle (TunnelConfiguration config) {
        switch (config.tunnel_type) {
            case TunnelType.LOCAL_FORWARD:
                return @"$(config.local_port) → $(config.ssh_host):$(config.remote_port)";
            case TunnelType.REMOTE_FORWARD:
                return @"$(config.ssh_host):$(config.remote_port) → $(config.local_port)";
            case TunnelType.DYNAMIC_FORWARD:
                return @"SOCKS proxy on port $(config.local_port)";
            case TunnelType.X11_FORWARD:
                return @"X11 forwarding to $(config.ssh_host)";
            default:
                return config.tunnel_type.to_string ();
        }
    }
    
    private void add_tunnel_details (Adw.ExpanderRow row, TunnelConfiguration config) {
        var details_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        details_box.margin_start = 12;
        details_box.margin_end = 12;
        details_box.margin_top = 12;
        details_box.margin_bottom = 12;
        
        // Connection info
        var connection_group = new Adw.PreferencesGroup ();
        connection_group.title = "Connection Details";
        
        var host_row = new Adw.ActionRow ();
        host_row.title = "SSH Host";
        host_row.subtitle = @"$(config.ssh_user)@$(config.ssh_host):$(config.ssh_port)";
        connection_group.add (host_row);
        
        if (config.ssh_key_path.length > 0) {
            var key_row = new Adw.ActionRow ();
            key_row.title = "SSH Key";
            key_row.subtitle = Path.get_basename (config.ssh_key_path);
            connection_group.add (key_row);
        }
        
        details_box.append (connection_group);
        
        // Tunnel configuration
        var tunnel_group = new Adw.PreferencesGroup ();
        tunnel_group.title = "Tunnel Configuration";
        
        var type_row = new Adw.ActionRow ();
        type_row.title = "Type";
        type_row.subtitle = config.tunnel_type.to_string ();
        tunnel_group.add (type_row);
        
        switch (config.tunnel_type) {
            case TunnelType.LOCAL_FORWARD:
                var local_row = new Adw.ActionRow ();
                local_row.title = "Local Address";
                local_row.subtitle = @"$(config.local_host):$(config.local_port)";
                tunnel_group.add (local_row);
                
                var remote_row = new Adw.ActionRow ();
                remote_row.title = "Remote Address";
                remote_row.subtitle = @"$(config.remote_host):$(config.remote_port)";
                tunnel_group.add (remote_row);
                break;
                
            case TunnelType.REMOTE_FORWARD:
                var remote_row = new Adw.ActionRow ();
                remote_row.title = "Remote Address";
                remote_row.subtitle = @"$(config.remote_host):$(config.remote_port)";
                tunnel_group.add (remote_row);
                
                var local_row = new Adw.ActionRow ();
                local_row.title = "Local Address";
                local_row.subtitle = @"$(config.local_host):$(config.local_port)";
                tunnel_group.add (local_row);
                break;
                
            case TunnelType.DYNAMIC_FORWARD:
                var proxy_row = new Adw.ActionRow ();
                proxy_row.title = "SOCKS Proxy";
                proxy_row.subtitle = @"$(config.local_host):$(config.local_port)";
                tunnel_group.add (proxy_row);
                break;
                
            case TunnelType.X11_FORWARD:
                var x11_row = new Adw.ActionRow ();
                x11_row.title = "X11 Display";
                x11_row.subtitle = config.x11_display ?? "Auto-detect";
                tunnel_group.add (x11_row);
                break;
        }
        
        details_box.append (tunnel_group);
        
        // Actions
        var actions_group = new Adw.PreferencesGroup ();
        actions_group.title = "Actions";
        
        var edit_row = new Adw.ActionRow ();
        edit_row.title = "Edit Tunnel";
        edit_row.subtitle = "Modify tunnel settings";
        edit_row.activatable = true;
        edit_row.activated.connect (() => {
            edit_tunnel (config);
        });
        
        var edit_icon = new Gtk.Image ();
        edit_icon.icon_name = "document-edit-symbolic";
        edit_row.add_prefix (edit_icon);
        
        actions_group.add (edit_row);
        
        var delete_row = new Adw.ActionRow ();
        delete_row.title = "Delete Tunnel";
        delete_row.subtitle = "Remove tunnel configuration";
        delete_row.activatable = true;
        delete_row.activated.connect (() => {
            delete_tunnel (config);
        });
        
        var delete_icon = new Gtk.Image ();
        delete_icon.icon_name = "user-trash-symbolic";
        delete_icon.add_css_class ("error");
        delete_row.add_prefix (delete_icon);
        
        actions_group.add (delete_row);
        
        details_box.append (actions_group);
        row.add_row (details_box);
    }
    
    private void populate_active_tunnels_list () {
        clear_active_tunnels_list ();
        
        var active_tunnels = tunneling.get_active_tunnels ();
        for (int i = 0; i < active_tunnels.length; i++) {
            add_active_tunnel_row (active_tunnels[i]);
        }
    }
    
    private void clear_active_tunnels_list () {
        Gtk.Widget? child = active_tunnels_list.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            active_tunnels_list.remove (child);
            child = next;
        }
    }
    
    private void add_active_tunnel_row (ActiveTunnel tunnel) {
        var row = new Adw.ActionRow ();
        row.title = tunnel.config.name;
        row.subtitle = @"$(tunnel.status.to_string ()) • $(tunnel.get_duration_string ())";
        
        // Status indicator
        var status_icon = new Gtk.Image ();
        status_icon.icon_name = "network-transmit-symbolic";
        status_icon.add_css_class (tunnel.status.get_css_class ());
        row.add_prefix (status_icon);
        
        // Stop button
        var stop_button = new Gtk.Button ();
        stop_button.icon_name = "media-playback-stop-symbolic";
        stop_button.tooltip_text = "Stop Tunnel";
        stop_button.add_css_class ("flat");
        stop_button.clicked.connect (() => {
            tunneling.stop_tunnel.begin (tunnel.config);
        });
        row.add_suffix (stop_button);
        
        // Update on status changes
        tunnel.status_changed.connect ((status) => {
            row.subtitle = @"$(status.to_string ()) • $(tunnel.get_duration_string ())";
            status_icon.remove_css_class ("success");
            status_icon.remove_css_class ("warning");
            status_icon.remove_css_class ("error");
            status_icon.add_css_class (status.get_css_class ());
        });
        
        active_tunnels_list.append (row);
    }
    
    private void update_ui_state () {
        var has_tunnels = tunneling.get_configurations ().length > 0;
        var has_active = tunneling.get_active_tunnels ().length > 0;
        
        if (has_tunnels || has_active) {
            main_stack.visible_child_name = "tunnels_page";
        } else {
            main_stack.visible_child_name = "empty_page";
        }
        
        active_group.visible = has_active;
    }
    
    private void on_add_tunnel () {
        var dialog = new CreateTunnelDialog ((Gtk.Window) this.get_root ());
        dialog.present (this);
    }
    
    private void edit_tunnel (TunnelConfiguration config) {
        var dialog = new CreateTunnelDialog ((Gtk.Window) this.get_root (), config);
        dialog.present (this);
    }
    
    private void delete_tunnel (TunnelConfiguration config) {
        var confirm_dialog = new Adw.AlertDialog (
            @"Delete Tunnel \"$(config.name)\"?",
            "This will permanently remove the tunnel configuration. Active connections will be stopped."
        );
        
        confirm_dialog.add_response ("cancel", "Cancel");
        confirm_dialog.add_response ("delete", "Delete Tunnel");
        confirm_dialog.set_response_appearance ("delete", Adw.ResponseAppearance.DESTRUCTIVE);
        confirm_dialog.set_default_response ("cancel");
        confirm_dialog.set_close_response ("cancel");
        
        confirm_dialog.response.connect ((response) => {
            if (response == "delete") {
                tunneling.remove_configuration (config);
            }
        });
        
        confirm_dialog.present (this);
    }
    
    private async void toggle_tunnel (TunnelConfiguration config) {
        try {
            if (tunneling.is_tunnel_active (config)) {
                yield tunneling.stop_tunnel (config);
            } else {
                yield tunneling.start_tunnel (config);
            }
        } catch (KeyMakerError e) {
            show_error ("Tunnel Operation Failed", e.message);
        }
    }
    
    private void on_tunnel_added (TunnelConfiguration config) {
        add_tunnel_row (config);
        update_ui_state ();
    }
    
    private void on_tunnel_removed (TunnelConfiguration config) {
        populate_tunnels_list ();
        update_ui_state ();
    }
    
    private void on_tunnel_started (ActiveTunnel tunnel) {
        add_active_tunnel_row (tunnel);
        populate_tunnels_list (); // Refresh to update status indicators
        update_ui_state ();
    }
    
    private void on_tunnel_stopped (ActiveTunnel tunnel) {
        populate_active_tunnels_list ();
        populate_tunnels_list (); // Refresh to update status indicators
        update_ui_state ();
    }
    
    private void show_error (string title, string message) {
        var error_dialog = new Adw.AlertDialog (title, message);
        error_dialog.add_response ("ok", "OK");
        error_dialog.set_default_response ("ok");
        error_dialog.present (this);
    }
}