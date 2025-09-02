/*
 * Key Maker - SSH Tunneling Management
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

public enum TunnelType {
    LOCAL_FORWARD,    // -L local_port:remote_host:remote_port
    REMOTE_FORWARD,   // -R remote_port:local_host:local_port  
    DYNAMIC_FORWARD,  // -D local_port (SOCKS proxy)
    X11_FORWARD;      // -X/-Y (X11 forwarding)
    
    public string to_string () {
        switch (this) {
            case LOCAL_FORWARD:
                return "Local Forward";
            case REMOTE_FORWARD:
                return "Remote Forward";
            case DYNAMIC_FORWARD:
                return "Dynamic Forward (SOCKS)";
            case X11_FORWARD:
                return "X11 Forward";
            default:
                return "Unknown";
        }
    }
    
    public string get_icon_name () {
        switch (this) {
            case LOCAL_FORWARD:
                return "go-down-symbolic";
            case REMOTE_FORWARD:
                return "go-up-symbolic";
            case DYNAMIC_FORWARD:
                return "network-proxy-symbolic";
            case X11_FORWARD:
                return "applications-graphics-symbolic";
            default:
                return "network-transmit-symbolic";
        }
    }
}

public enum TunnelStatus {
    INACTIVE,
    CONNECTING,
    ACTIVE,
    ERROR,
    DISCONNECTING;
    
    public string to_string () {
        switch (this) {
            case INACTIVE:
                return "Inactive";
            case CONNECTING:
                return "Connecting";
            case ACTIVE:
                return "Active";
            case ERROR:
                return "Error";
            case DISCONNECTING:
                return "Disconnecting";
            default:
                return "Unknown";
        }
    }
    
    public string get_css_class () {
        switch (this) {
            case ACTIVE:
                return "success";
            case CONNECTING:
            case DISCONNECTING:
                return "warning";
            case ERROR:
                return "error";
            default:
                return "";
        }
    }
}

public class TunnelConfiguration : Object {
    public string name { get; set; }
    public string description { get; set; }
    public TunnelType tunnel_type { get; set; }
    public string ssh_host { get; set; }
    public string ssh_user { get; set; }
    public string ssh_key_path { get; set; }
    public int ssh_port { get; set; default = 22; }
    
    // Tunnel-specific settings
    public string local_host { get; set; default = "localhost"; }
    public int local_port { get; set; }
    public string remote_host { get; set; default = "localhost"; }
    public int remote_port { get; set; }
    
    // Advanced options
    public bool compression { get; set; default = false; }
    public bool keep_alive { get; set; default = true; }
    public int connection_timeout { get; set; default = 30; }
    public bool auto_reconnect { get; set; default = true; }
    public bool bind_to_localhost_only { get; set; default = true; }
    
    // X11 forwarding options
    public bool trusted_x11 { get; set; default = false; }
    public string? x11_display { get; set; }
    
    public TunnelConfiguration () {
        name = "New Tunnel";
        description = "";
        tunnel_type = TunnelType.LOCAL_FORWARD;
        ssh_host = "";
        ssh_user = Environment.get_user_name () ?? "user";
        ssh_key_path = "";
        local_port = 8080;
        remote_port = 80;
    }
    
    public string get_ssh_command () {
        var cmd = new StringBuilder ("ssh");
        
        // Basic connection parameters
        cmd.append_printf (" -p %d", ssh_port);
        cmd.append_printf (" %s@%s", ssh_user, ssh_host);
        
        if (ssh_key_path.length > 0) {
            cmd.append_printf (" -i \"%s\"", ssh_key_path);
        }
        
        // Tunnel configuration
        switch (tunnel_type) {
            case TunnelType.LOCAL_FORWARD:
                if (bind_to_localhost_only) {
                    cmd.append_printf (" -L %s:%d:%s:%d", local_host, local_port, remote_host, remote_port);
                } else {
                    cmd.append_printf (" -L *:%d:%s:%d", local_port, remote_host, remote_port);
                }
                break;
                
            case TunnelType.REMOTE_FORWARD:
                if (bind_to_localhost_only) {
                    cmd.append_printf (" -R %s:%d:%s:%d", remote_host, remote_port, local_host, local_port);
                } else {
                    cmd.append_printf (" -R *:%d:%s:%d", remote_port, local_host, local_port);
                }
                break;
                
            case TunnelType.DYNAMIC_FORWARD:
                if (bind_to_localhost_only) {
                    cmd.append_printf (" -D %s:%d", local_host, local_port);
                } else {
                    cmd.append_printf (" -D *:%d", local_port);
                }
                break;
                
            case TunnelType.X11_FORWARD:
                if (trusted_x11) {
                    cmd.append (" -Y");
                } else {
                    cmd.append (" -X");
                }
                break;
        }
        
        // Additional options
        if (compression) {
            cmd.append (" -C");
        }
        
        if (keep_alive) {
            cmd.append (" -o ServerAliveInterval=60 -o ServerAliveCountMax=3");
        }
        
        cmd.append_printf (" -o ConnectTimeout=%d", connection_timeout);
        cmd.append (" -o BatchMode=yes");
        cmd.append (" -N"); // Don't execute remote command
        
        return cmd.str;
    }
    
    public bool validate () {
        if (name.strip ().length == 0) return false;
        if (ssh_host.strip ().length == 0) return false;
        if (ssh_user.strip ().length == 0) return false;
        
        switch (tunnel_type) {
            case TunnelType.LOCAL_FORWARD:
            case TunnelType.REMOTE_FORWARD:
                if (local_port <= 0 || local_port > 65535) return false;
                if (remote_port <= 0 || remote_port > 65535) return false;
                if (remote_host.strip ().length == 0) return false;
                break;
                
            case TunnelType.DYNAMIC_FORWARD:
                if (local_port <= 0 || local_port > 65535) return false;
                break;
        }
        
        return true;
    }
    
    public Variant to_variant () {
        var builder = new VariantBuilder (new VariantType ("a{sv}"));
        builder.add ("{sv}", "name", new Variant.string (name));
        builder.add ("{sv}", "description", new Variant.string (description));
        builder.add ("{sv}", "tunnel_type", new Variant.int32 ((int32) tunnel_type));
        builder.add ("{sv}", "ssh_host", new Variant.string (ssh_host));
        builder.add ("{sv}", "ssh_user", new Variant.string (ssh_user));
        builder.add ("{sv}", "ssh_key_path", new Variant.string (ssh_key_path));
        builder.add ("{sv}", "ssh_port", new Variant.int32 (ssh_port));
        builder.add ("{sv}", "local_host", new Variant.string (local_host));
        builder.add ("{sv}", "local_port", new Variant.int32 (local_port));
        builder.add ("{sv}", "remote_host", new Variant.string (remote_host));
        builder.add ("{sv}", "remote_port", new Variant.int32 (remote_port));
        builder.add ("{sv}", "compression", new Variant.boolean (compression));
        builder.add ("{sv}", "keep_alive", new Variant.boolean (keep_alive));
        builder.add ("{sv}", "connection_timeout", new Variant.int32 (connection_timeout));
        builder.add ("{sv}", "auto_reconnect", new Variant.boolean (auto_reconnect));
        builder.add ("{sv}", "bind_to_localhost_only", new Variant.boolean (bind_to_localhost_only));
        builder.add ("{sv}", "trusted_x11", new Variant.boolean (trusted_x11));
        if (x11_display != null) {
            builder.add ("{sv}", "x11_display", new Variant.string (x11_display));
        }
        return builder.end ();
    }
    
    public static TunnelConfiguration? from_variant (Variant variant) {
        if (!variant.is_of_type (new VariantType ("a{sv}"))) {
            return null;
        }
        
        var config = new TunnelConfiguration ();
        var iter = variant.iterator ();
        string key;
        Variant value;
        
        while (iter.next ("{sv}", out key, out value)) {
            switch (key) {
                case "name":
                    if (value.is_of_type (VariantType.STRING)) {
                        config.name = value.get_string ();
                    }
                    break;
                case "description":
                    if (value.is_of_type (VariantType.STRING)) {
                        config.description = value.get_string ();
                    }
                    break;
                case "tunnel_type":
                    if (value.is_of_type (VariantType.INT32)) {
                        config.tunnel_type = (TunnelType) value.get_int32 ();
                    }
                    break;
                case "ssh_host":
                    if (value.is_of_type (VariantType.STRING)) {
                        config.ssh_host = value.get_string ();
                    }
                    break;
                case "ssh_user":
                    if (value.is_of_type (VariantType.STRING)) {
                        config.ssh_user = value.get_string ();
                    }
                    break;
                case "ssh_key_path":
                    if (value.is_of_type (VariantType.STRING)) {
                        config.ssh_key_path = value.get_string ();
                    }
                    break;
                case "ssh_port":
                    if (value.is_of_type (VariantType.INT32)) {
                        config.ssh_port = value.get_int32 ();
                    }
                    break;
                case "local_host":
                    if (value.is_of_type (VariantType.STRING)) {
                        config.local_host = value.get_string ();
                    }
                    break;
                case "local_port":
                    if (value.is_of_type (VariantType.INT32)) {
                        config.local_port = value.get_int32 ();
                    }
                    break;
                case "remote_host":
                    if (value.is_of_type (VariantType.STRING)) {
                        config.remote_host = value.get_string ();
                    }
                    break;
                case "remote_port":
                    if (value.is_of_type (VariantType.INT32)) {
                        config.remote_port = value.get_int32 ();
                    }
                    break;
                case "compression":
                    if (value.is_of_type (VariantType.BOOLEAN)) {
                        config.compression = value.get_boolean ();
                    }
                    break;
                case "keep_alive":
                    if (value.is_of_type (VariantType.BOOLEAN)) {
                        config.keep_alive = value.get_boolean ();
                    }
                    break;
                case "connection_timeout":
                    if (value.is_of_type (VariantType.INT32)) {
                        config.connection_timeout = value.get_int32 ();
                    }
                    break;
                case "auto_reconnect":
                    if (value.is_of_type (VariantType.BOOLEAN)) {
                        config.auto_reconnect = value.get_boolean ();
                    }
                    break;
                case "bind_to_localhost_only":
                    if (value.is_of_type (VariantType.BOOLEAN)) {
                        config.bind_to_localhost_only = value.get_boolean ();
                    }
                    break;
                case "trusted_x11":
                    if (value.is_of_type (VariantType.BOOLEAN)) {
                        config.trusted_x11 = value.get_boolean ();
                    }
                    break;
                case "x11_display":
                    if (value.is_of_type (VariantType.STRING)) {
                        config.x11_display = value.get_string ();
                    }
                    break;
            }
        }
        
        return config;
    }
}

public class ActiveTunnel : Object {
    public TunnelConfiguration config { get; construct; }
    public TunnelStatus status { get; private set; default = TunnelStatus.INACTIVE; }
    public string? error_message { get; private set; }
    public DateTime? started_at { get; private set; }
    public DateTime? last_activity { get; private set; }
    public int64 bytes_sent { get; private set; default = 0; }
    public int64 bytes_received { get; private set; default = 0; }
    
    private Subprocess? process;
    private uint heartbeat_timeout_id;
    
    public signal void status_changed (TunnelStatus status);
    public signal void error_occurred (string message);
    public signal void statistics_updated ();
    
    public ActiveTunnel (TunnelConfiguration config) {
        Object (config: config);
    }
    
    public async bool start () throws KeyMaker.KeyMakerError {
        if (status == TunnelStatus.ACTIVE || status == TunnelStatus.CONNECTING) {
            throw new KeyMaker.KeyMakerError.OPERATION_FAILED ("Tunnel is already active or connecting");
        }
        
        if (!config.validate ()) {
            throw new KeyMaker.KeyMakerError.INVALID_INPUT ("Tunnel configuration is invalid");
        }
        
        update_status (TunnelStatus.CONNECTING);
        
        try {
            var cmd = config.get_ssh_command ();
            string[] argv;
            Shell.parse_argv (cmd, out argv);
            
            process = new Subprocess.newv (argv, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
            
            // Monitor process
            monitor_process.begin ();
            
            // Start heartbeat
            if (config.keep_alive) {
                start_heartbeat ();
            }
            
            started_at = new DateTime.now_local ();
            last_activity = started_at;
            update_status (TunnelStatus.ACTIVE);
            
            return true;
            
        } catch (Error e) {
            error_message = e.message;
            update_status (TunnelStatus.ERROR);
            error_occurred (e.message);
            throw new KeyMaker.KeyMakerError.OPERATION_FAILED (@"Failed to start tunnel: $(e.message)");
        }
    }
    
    public async void stop () {
        if (status == TunnelStatus.INACTIVE) {
            return;
        }
        
        update_status (TunnelStatus.DISCONNECTING);
        stop_heartbeat ();
        
        if (process != null) {
            try {
                process.force_exit ();
                yield process.wait_async ();
            } catch (Error e) {
                warning ("Error stopping tunnel process: %s", e.message);
            }
        }
        
        process = null;
        update_status (TunnelStatus.INACTIVE);
    }
    
    private async void monitor_process () {
        if (process == null) return;
        
        try {
            yield process.wait_async ();
            
            if (process.get_if_exited ()) {
                var exit_status = process.get_exit_status ();
                if (exit_status != 0) {
                    error_message = @"SSH process exited with status $exit_status";
                    update_status (TunnelStatus.ERROR);
                    error_occurred (error_message);
                    
                    // Auto-reconnect if enabled
                    if (config.auto_reconnect && status == TunnelStatus.ERROR) {
                        yield attempt_reconnect ();
                    }
                } else {
                    update_status (TunnelStatus.INACTIVE);
                }
            }
        } catch (Error e) {
            error_message = e.message;
            update_status (TunnelStatus.ERROR);
            error_occurred (e.message);
        }
    }
    
    private async void attempt_reconnect () {
        // Wait before reconnecting
        Timeout.add (5000, () => {
            attempt_reconnect.callback ();
            return false;
        });
        yield;
        
        if (status == TunnelStatus.ERROR) {
            try {
                yield start ();
            } catch (KeyMaker.KeyMakerError e) {
                warning ("Failed to reconnect tunnel: %s", e.message);
            }
        }
    }
    
    private void start_heartbeat () {
        heartbeat_timeout_id = Timeout.add_seconds (60, () => {
            last_activity = new DateTime.now_local ();
            statistics_updated ();
            return Source.CONTINUE;
        });
    }
    
    private void stop_heartbeat () {
        if (heartbeat_timeout_id > 0) {
            Source.remove (heartbeat_timeout_id);
            heartbeat_timeout_id = 0;
        }
    }
    
    private void update_status (TunnelStatus new_status) {
        if (status != new_status) {
            status = new_status;
            status_changed (status);
        }
    }
    
    public string get_duration_string () {
        if (started_at == null) return "Not started";
        
        var now = new DateTime.now_local ();
        var duration = now.difference (started_at) / TimeSpan.SECOND;
        
        if (duration < 60) {
            return @"$(duration)s";
        } else if (duration < 3600) {
            return @"$(duration / 60)m $(duration % 60)s";
        } else {
            var hours = duration / 3600;
            var minutes = (duration % 3600) / 60;
            return @"$(hours)h $(minutes)m";
        }
    }
}

public class SSHTunneling : Object {
    private GenericArray<TunnelConfiguration> saved_configurations;
    private GenericArray<ActiveTunnel> active_tunnels;
    private Settings settings;
    
    public signal void tunnel_added (TunnelConfiguration config);
    public signal void tunnel_removed (TunnelConfiguration config);
    public signal void tunnel_started (ActiveTunnel tunnel);
    public signal void tunnel_stopped (ActiveTunnel tunnel);
    
    public SSHTunneling () {
        saved_configurations = new GenericArray<TunnelConfiguration> ();
        active_tunnels = new GenericArray<ActiveTunnel> ();
        settings = new Settings (Config.APP_ID);
        
        load_configurations ();
    }
    
    public void add_configuration (TunnelConfiguration config) {
        saved_configurations.add (config);
        save_configurations ();
        tunnel_added (config);
    }
    
    public void remove_configuration (TunnelConfiguration config) {
        // Stop tunnel if active
        var active_tunnel = find_active_tunnel (config);
        if (active_tunnel != null) {
            stop_tunnel.begin (config);
        }
        
        // Remove from saved configurations
        for (int i = 0; i < saved_configurations.length; i++) {
            if (saved_configurations[i] == config) {
                saved_configurations.remove_index (i);
                break;
            }
        }
        
        save_configurations ();
        tunnel_removed (config);
    }
    
    public GenericArray<TunnelConfiguration> get_configurations () {
        return saved_configurations;
    }
    
    public GenericArray<ActiveTunnel> get_active_tunnels () {
        return active_tunnels;
    }
    
    public async bool start_tunnel (TunnelConfiguration config) throws KeyMaker.KeyMakerError {
        // Check if already active
        var existing = find_active_tunnel (config);
        if (existing != null) {
            throw new KeyMaker.KeyMakerError.OPERATION_FAILED ("Tunnel is already active");
        }
        
        var tunnel = new ActiveTunnel (config);
        active_tunnels.add (tunnel);
        
        try {
            yield tunnel.start ();
            tunnel_started (tunnel);
            return true;
        } catch (KeyMaker.KeyMakerError e) {
            active_tunnels.remove (tunnel);
            throw e;
        }
    }
    
    public async void stop_tunnel (TunnelConfiguration config) {
        var tunnel = find_active_tunnel (config);
        if (tunnel != null) {
            yield tunnel.stop ();
            active_tunnels.remove (tunnel);
            tunnel_stopped (tunnel);
        }
    }
    
    public bool is_tunnel_active (TunnelConfiguration config) {
        return find_active_tunnel (config) != null;
    }
    
    private ActiveTunnel? find_active_tunnel (TunnelConfiguration config) {
        for (int i = 0; i < active_tunnels.length; i++) {
            if (active_tunnels[i].config == config) {
                return active_tunnels[i];
            }
        }
        return null;
    }
    
    private void load_configurations () {
        var configs = settings.get_value ("tunnel-configurations");
        if (configs.get_type_string () == "aa{sv}") {
            var iter = configs.iterator ();
            Variant? config_variant;
            while (iter.next ("a{sv}", out config_variant)) {
                var config = TunnelConfiguration.from_variant (config_variant);
                if (config != null) {
                    saved_configurations.add (config);
                }
            }
        }
        
        // If no configurations loaded, add some examples
        if (saved_configurations.length == 0) {
            var example1 = new TunnelConfiguration ();
            example1.name = "Database Forward";
            example1.description = "Forward local port 5432 to remote PostgreSQL";
            example1.tunnel_type = TunnelType.LOCAL_FORWARD;
            example1.local_port = 5432;
            example1.remote_host = "localhost";
            example1.remote_port = 5432;
            saved_configurations.add (example1);
            
            var example2 = new TunnelConfiguration ();
            example2.name = "SOCKS Proxy";
            example2.description = "Dynamic SOCKS proxy for web browsing";
            example2.tunnel_type = TunnelType.DYNAMIC_FORWARD;
            example2.local_port = 1080;
            saved_configurations.add (example2);
        }
    }
    
    private void save_configurations () {
        var builder = new VariantBuilder (new VariantType ("aa{sv}"));
        for (int i = 0; i < saved_configurations.length; i++) {
            var config = saved_configurations[i];
            var config_variant = config.to_variant ();
            builder.add_value (config_variant);
        }
        settings.set_value ("tunnel-configurations", builder.end ());
    }
    
    public void stop_all_tunnels () {
        for (int i = 0; i < active_tunnels.length; i++) {
            active_tunnels[i].stop.begin ();
        }
        active_tunnels.remove_range (0, active_tunnels.length);
    }
}