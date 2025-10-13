/*
 * SSHer - SSH Tunnel Configuration
 * 
 * Data structures for tunnel configurations and types.
 */

namespace KeyMaker {
    
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
        
        public string get_description () {
            switch (this) {
                case LOCAL_FORWARD:
                    return "Forward local port to remote host";
                case REMOTE_FORWARD:
                    return "Forward remote port to local host";
                case DYNAMIC_FORWARD:
                    return "Create SOCKS proxy on local port";
                case X11_FORWARD:
                    return "Forward X11 connections";
                default:
                    return "Unknown tunnel type";
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
        
        public string get_icon_name () {
            switch (this) {
                case INACTIVE:
                    return "network-offline-symbolic";
                case CONNECTING:
                    return "network-transmit-symbolic";
                case ACTIVE:
                    return "network-receive-symbolic";
                case ERROR:
                    return "dialog-error-symbolic";
                case DISCONNECTING:
                    return "network-offline-symbolic";
                default:
                    return "help-about-symbolic";
            }
        }
    }

    public class TunnelConfiguration : Object {
        public string name { get; set; }
        public string description { get; set; }
        public TunnelType tunnel_type { get; set; }
        public string hostname { get; set; }
        public string username { get; set; }
        public int ssh_port { get; set; default = 22; }
        public string? ssh_key_path { get; set; }
        
        // Port forwarding specific
        public int local_port { get; set; }
        public int remote_port { get; set; }
        public string? remote_host { get; set; default = "localhost"; }
        public string? local_host { get; set; default = "localhost"; }
        
        // Options
        public bool auto_start { get; set; default = false; }
        public bool keep_alive { get; set; default = true; }
        public int connection_timeout { get; set; default = 30; }
        public bool compression { get; set; default = false; }
        public bool auto_reconnect { get; set; default = true; }
        public bool bind_to_localhost_only { get; set; default = true; }
        public bool trusted_x11 { get; set; default = false; }
        public string? x11_display { get; set; }
        
        // Compatibility aliases
        public string ssh_host { get { return hostname; } set { hostname = value; } }
        public string ssh_user { get { return username; } set { username = value; } }
        
        // Metadata
        public DateTime created_at { get; set; }
        public DateTime? last_used { get; set; }
        public string config_id { get; set; }
        
        construct {
            created_at = new DateTime.now_local();
            config_id = generate_config_id();
        }
        
        public TunnelConfiguration () {
            name = "Unnamed Tunnel";
            description = "";
            tunnel_type = TunnelType.LOCAL_FORWARD;
            hostname = "";
            username = "";
        }
        
        private string generate_config_id () {
            var timestamp = new DateTime.now_local ().format ("%Y%m%d_%H%M%S");
            var random = Random.int_range (1000, 9999);
            return @"tunnel_$(timestamp)_$(random)";
        }
        
        public string get_display_name () {
            if (name.length > 0) {
                return name;
            }
            
            switch (tunnel_type) {
                case TunnelType.LOCAL_FORWARD:
                    return @"$(local_port) → $(hostname):$(remote_port)";
                case TunnelType.REMOTE_FORWARD:
                    return @"$(hostname):$(remote_port) → $(local_port)";
                case TunnelType.DYNAMIC_FORWARD:
                    return @"SOCKS proxy on :$(local_port)";
                case TunnelType.X11_FORWARD:
                    return @"X11 → $(hostname)";
                default:
                    return @"$(hostname)";
            }
        }
        
        public string get_connection_string () {
            if (ssh_port != 22) {
                return @"$(username)@$(hostname):$(ssh_port)";
            } else {
                return @"$(username)@$(hostname)";
            }
        }
        
        public bool validate () {
            if (hostname.length == 0 || username.length == 0) {
                return false;
            }
            
            switch (tunnel_type) {
                case TunnelType.LOCAL_FORWARD:
                case TunnelType.REMOTE_FORWARD:
                    return local_port > 0 && remote_port > 0;
                case TunnelType.DYNAMIC_FORWARD:
                    return local_port > 0;
                case TunnelType.X11_FORWARD:
                    return true; // No additional validation needed
                default:
                    return false;
            }
        }
        
        public GenericArray<string> get_ssh_arguments () {
            var args = new GenericArray<string>();
            
            // Basic SSH arguments
            args.add("ssh");
            
            // Port
            if (ssh_port != 22) {
                args.add("-p");
                args.add(ssh_port.to_string());
            }
            
            // Key file
            if (ssh_key_path != null && ssh_key_path.length > 0) {
                args.add("-i");
                args.add(ssh_key_path);
            }
            
            // Connection options
            args.add("-o");
            args.add("BatchMode=yes");
            args.add("-o");
            args.add("ExitOnForwardFailure=yes");
            args.add("-o");
            args.add(@"ConnectTimeout=$(connection_timeout)");
            
            if (keep_alive) {
                args.add("-o");
                args.add("ServerAliveInterval=60");
                args.add("-o");
                args.add("ServerAliveCountMax=3");
            }
            
            if (compression) {
                args.add("-C");
            }
            
            // Tunnel-specific arguments
            switch (tunnel_type) {
                case TunnelType.LOCAL_FORWARD:
                    args.add("-L");
                    args.add(@"$(local_port):$(remote_host):$(remote_port)");
                    break;
                case TunnelType.REMOTE_FORWARD:
                    args.add("-R");
                    args.add(@"$(remote_port):$(local_host):$(local_port)");
                    break;
                case TunnelType.DYNAMIC_FORWARD:
                    args.add("-D");
                    args.add(local_port.to_string());
                    break;
                case TunnelType.X11_FORWARD:
                    args.add("-X");
                    break;
            }
            
            // Disable TTY allocation for port forwarding
            if (tunnel_type != TunnelType.X11_FORWARD) {
                args.add("-N");
            }
            
            // Host
            args.add(get_connection_string());
            
            return args;
        }
        
        public Variant to_variant () {
            var builder = new VariantBuilder(VariantType.VARDICT);
            builder.add("{sv}", "name", new Variant.string(name));
            builder.add("{sv}", "description", new Variant.string(description));
            builder.add("{sv}", "tunnel_type", new Variant.int32(tunnel_type));
            builder.add("{sv}", "hostname", new Variant.string(hostname));
            builder.add("{sv}", "username", new Variant.string(username));
            builder.add("{sv}", "ssh_port", new Variant.int32(ssh_port));
            builder.add("{sv}", "local_port", new Variant.int32(local_port));
            builder.add("{sv}", "remote_port", new Variant.int32(remote_port));
            builder.add("{sv}", "auto_start", new Variant.boolean(auto_start));
            builder.add("{sv}", "keep_alive", new Variant.boolean(keep_alive));
            builder.add("{sv}", "connection_timeout", new Variant.int32(connection_timeout));
            builder.add("{sv}", "compression", new Variant.boolean(compression));
            builder.add("{sv}", "auto_reconnect", new Variant.boolean(auto_reconnect));
            builder.add("{sv}", "bind_to_localhost_only", new Variant.boolean(bind_to_localhost_only));
            builder.add("{sv}", "trusted_x11", new Variant.boolean(trusted_x11));
            builder.add("{sv}", "config_id", new Variant.string(config_id));
            
            if (ssh_key_path != null) {
                builder.add("{sv}", "ssh_key_path", new Variant.string(ssh_key_path));
            }
            if (remote_host != null) {
                builder.add("{sv}", "remote_host", new Variant.string(remote_host));
            }
            if (local_host != null) {
                builder.add("{sv}", "local_host", new Variant.string(local_host));
            }
            if (x11_display != null) {
                builder.add("{sv}", "x11_display", new Variant.string(x11_display));
            }
            
            return builder.end();
        }
        
        public static TunnelConfiguration? from_variant (Variant variant) {
            if (!variant.is_of_type(VariantType.VARDICT)) {
                return null;
            }
            
            var config = new TunnelConfiguration();
            var dict = variant.get_child_value(0);
            
            try {
                config.name = dict.lookup_value("name", VariantType.STRING)?.get_string() ?? "";
                config.description = dict.lookup_value("description", VariantType.STRING)?.get_string() ?? "";
                config.tunnel_type = (TunnelType)(dict.lookup_value("tunnel_type", VariantType.INT32)?.get_int32() ?? 0);
                config.hostname = dict.lookup_value("hostname", VariantType.STRING)?.get_string() ?? "";
                config.username = dict.lookup_value("username", VariantType.STRING)?.get_string() ?? "";
                config.ssh_port = dict.lookup_value("ssh_port", VariantType.INT32)?.get_int32() ?? 22;
                config.local_port = dict.lookup_value("local_port", VariantType.INT32)?.get_int32() ?? 0;
                config.remote_port = dict.lookup_value("remote_port", VariantType.INT32)?.get_int32() ?? 0;
                config.auto_start = dict.lookup_value("auto_start", VariantType.BOOLEAN)?.get_boolean() ?? false;
                config.keep_alive = dict.lookup_value("keep_alive", VariantType.BOOLEAN)?.get_boolean() ?? true;
                config.connection_timeout = dict.lookup_value("connection_timeout", VariantType.INT32)?.get_int32() ?? 30;
                config.compression = dict.lookup_value("compression", VariantType.BOOLEAN)?.get_boolean() ?? false;
                config.auto_reconnect = dict.lookup_value("auto_reconnect", VariantType.BOOLEAN)?.get_boolean() ?? true;
                config.bind_to_localhost_only = dict.lookup_value("bind_to_localhost_only", VariantType.BOOLEAN)?.get_boolean() ?? true;
                config.trusted_x11 = dict.lookup_value("trusted_x11", VariantType.BOOLEAN)?.get_boolean() ?? false;
                config.config_id = dict.lookup_value("config_id", VariantType.STRING)?.get_string() ?? config.generate_config_id();
                config.ssh_key_path = dict.lookup_value("ssh_key_path", VariantType.STRING)?.get_string();
                config.remote_host = dict.lookup_value("remote_host", VariantType.STRING)?.get_string();
                config.local_host = dict.lookup_value("local_host", VariantType.STRING)?.get_string();
                config.x11_display = dict.lookup_value("x11_display", VariantType.STRING)?.get_string();
                
                return config;
                
            } catch (Error e) {
                KeyMaker.Log.warning(KeyMaker.Log.Categories.TUNNELING, "Failed to deserialize tunnel configuration: %s", e.message);
                return null;
            }
        }
    }
}