/*
 * SSHer - SSH Config Parser and Manager
 * 
 * Manages SSH client configuration files.
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {
    
    public class SSHConfigHost : GLib.Object {
        public string name { get; set; }
        public string? hostname { get; set; }
        public string? user { get; set; }
        public int? port { get; set; }
        public string? identity_file { get; set; }
        public string? proxy_jump { get; set; }
        public string? proxy_command { get; set; }
        public bool? forward_agent { get; set; }
        public bool? strict_host_key_checking { get; set; }
        public string? user_known_hosts_file { get; set; }
        public GenericArray<SSHConfigOption> custom_options { get; set; }
        public int line_number { get; set; default = -1; }
        
        construct {
            custom_options = new GenericArray<SSHConfigOption> ();
        }
        
        public SSHConfigHost (string host_name) {
            name = host_name;
        }
        
        public void add_custom_option (string key, string value) {
            custom_options.add (new SSHConfigOption (key, value));
        }
        
        public string? get_custom_option (string key) {
            for (int i = 0; i < custom_options.length; i++) {
                if (custom_options[i].key.down () == key.down ()) {
                    return custom_options[i].value;
                }
            }
            return null;
        }
        
        public bool has_jump_host () {
            return proxy_jump != null || proxy_command != null;
        }
        
        public string get_display_name () {
            if (hostname != null && hostname != name) {
                return @"$(name) ($(hostname))";
            }
            return name;
        }
    }
    
    public class SSHConfigOption : GLib.Object {
        public string key { get; set; }
        public string value { get; set; }
        
        public SSHConfigOption (string option_key, string option_value) {
            key = option_key;
            value = option_value;
        }
    }
    
    public class SSHConfig : GLib.Object {
        private GenericArray<SSHConfigHost> hosts;
        private File config_file;
        private GenericArray<string> original_lines;
        
        public signal void config_changed ();
        
        construct {
            hosts = new GenericArray<SSHConfigHost> ();
            original_lines = new GenericArray<string> ();
            
            var ssh_dir = File.new_for_path (Path.build_filename (Environment.get_home_dir (), ".ssh"));
            config_file = ssh_dir.get_child ("config");
        }
        
        public async void load_config () throws KeyMakerError {
            try {
                hosts.remove_range (0, hosts.length);
                original_lines.remove_range (0, original_lines.length);
                
                if (!config_file.query_exists ()) {
                    return; // No config file exists yet
                }
                
                uint8[] contents;
                config_file.load_contents (null, out contents, null);
                var content = (string) contents;
                
                var lines = content.split ("\n");
                for (int i = 0; i < lines.length; i++) {
                    original_lines.add (lines[i]);
                }
                
                parse_config_content (lines);
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to load SSH config: %s", e.message);
            }
        }
        
        public async void save_config () throws KeyMakerError {
            try {
                var content = generate_config_content ();
                
                // Ensure .ssh directory exists
                var ssh_dir = config_file.get_parent ();
                if (!ssh_dir.query_exists ()) {
                    ssh_dir.make_directory_with_parents ();
                }
                // Ensure proper permissions
                KeyMaker.Filesystem.ensure_directory_with_perms (ssh_dir);
                
                // Write config file
                yield config_file.replace_contents_async (
                    content.data,
                    null,
                    false,
                    FileCreateFlags.NONE,
                    null,
                    null
                );
                
                // Set proper permissions
                KeyMaker.Filesystem.chmod_private (config_file);
                
                config_changed ();
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to save SSH config: %s", e.message);
            }
        }
        
        private void parse_config_content (string[] lines) {
            SSHConfigHost? current_host = null;
            
            for (int i = 0; i < lines.length; i++) {
                var line = lines[i].strip ();
                
                // Skip empty lines and comments
                if (line.length == 0 || line.has_prefix ("#")) {
                    continue;
                }
                
                // Check for Host directive
                if (line.down ().has_prefix ("host ")) {
                    if (current_host != null) {
                        hosts.add (current_host);
                    }
                    
                    var host_pattern = line.substring (5).strip ();
                    current_host = new SSHConfigHost (host_pattern);
                    current_host.line_number = i;
                    continue;
                }
                
                // Parse host options
                if (current_host != null) {
                    parse_host_option (current_host, line);
                }
            }
            
            // Add the last host
            if (current_host != null) {
                hosts.add (current_host);
            }
        }
        
        private void parse_host_option (SSHConfigHost host, string line) {
            var parts = line.split_set (" \t", 2);
            if (parts.length < 2) return;
            
            var key = parts[0].down ();
            var value = parts[1].strip ();
            
            switch (key) {
                case "hostname":
                    host.hostname = value;
                    break;
                case "user":
                    host.user = value;
                    break;
                case "port":
                    host.port = int.parse (value);
                    break;
                case "identityfile":
                    host.identity_file = value;
                    break;
                case "proxyjump":
                    host.proxy_jump = value;
                    break;
                case "proxycommand":
                    host.proxy_command = value;
                    break;
                case "forwardagent":
                    host.forward_agent = (value.down () == "yes");
                    break;
                case "stricthostkeychecking":
                    host.strict_host_key_checking = (value.down () == "yes");
                    break;
                case "userknownhostsfile":
                    host.user_known_hosts_file = value;
                    break;
                default:
                    host.add_custom_option (parts[0], value);
                    break;
            }
        }
        
        private string generate_config_content () {
            var builder = new StringBuilder ();
            
            // Add header comment
            builder.append ("# SSH Client Configuration\n");
            builder.append ("# Generated by SSHer\n\n");
            
            for (int i = 0; i < hosts.length; i++) {
                var host = hosts[i];
                
                builder.append_printf ("Host %s\n", host.name);
                
                if (host.hostname != null) {
                    builder.append_printf ("    HostName %s\n", host.hostname);
                }
                
                if (host.user != null) {
                    builder.append_printf ("    User %s\n", host.user);
                }
                
                if (host.port != null && host.port != 22) {
                    builder.append_printf ("    Port %d\n", host.port);
                }
                
                if (host.identity_file != null) {
                    builder.append_printf ("    IdentityFile %s\n", host.identity_file);
                }
                
                if (host.proxy_jump != null) {
                    builder.append_printf ("    ProxyJump %s\n", host.proxy_jump);
                }
                
                if (host.proxy_command != null) {
                    builder.append_printf ("    ProxyCommand %s\n", host.proxy_command);
                }
                
                if (host.forward_agent != null) {
                    builder.append_printf ("    ForwardAgent %s\n", host.forward_agent ? "yes" : "no");
                }
                
                if (host.strict_host_key_checking != null) {
                    builder.append_printf ("    StrictHostKeyChecking %s\n", host.strict_host_key_checking ? "yes" : "no");
                }
                
                if (host.user_known_hosts_file != null) {
                    builder.append_printf ("    UserKnownHostsFile %s\n", host.user_known_hosts_file);
                }
                
                // Add custom options
                for (int j = 0; j < host.custom_options.length; j++) {
                    var option = host.custom_options[j];
                    builder.append_printf ("    %s %s\n", option.key, option.value);
                }
                
                builder.append ("\n");
            }
            
            return builder.str;
        }
        
        public GenericArray<SSHConfigHost> get_hosts () {
            return hosts;
        }
        
        public SSHConfigHost? get_host (string name) {
            for (int i = 0; i < hosts.length; i++) {
                if (hosts[i].name == name) {
                    return hosts[i];
                }
            }
            return null;
        }
        
        public void add_host (SSHConfigHost host) {
            // Check if host already exists
            var existing = get_host (host.name);
            if (existing != null) {
                remove_host (host.name);
            }
            
            hosts.add (host);
        }
        
        public bool remove_host (string name) {
            for (int i = 0; i < hosts.length; i++) {
                if (hosts[i].name == name) {
                    hosts.remove_index (i);
                    return true;
                }
            }
            return false;
        }
        
        public GenericArray<SSHConfigHost> search_hosts (string query) {
            var results = new GenericArray<SSHConfigHost> ();
            var query_lower = query.down ();
            
            for (int i = 0; i < hosts.length; i++) {
                var host = hosts[i];
                
                if (query_lower in host.name.down () ||
                    (host.hostname != null && query_lower in host.hostname.down ()) ||
                    (host.user != null && query_lower in host.user.down ())) {
                    results.add (host);
                }
            }
            
            return results;
        }
        
        public bool validate_config () {
            // Basic validation
            for (int i = 0; i < hosts.length; i++) {
                var host = hosts[i];
                
                // Check for valid host name
                if (host.name.length == 0) {
                    return false;
                }
                
                // Check for valid port
                if (host.port != null && (host.port < 1 || host.port > 65535)) {
                    return false;
                }
                
                // Check identity file exists if specified
                if (host.identity_file != null) {
                    var identity_path = host.identity_file;
                    
                    // Expand ~ if present
                    if (identity_path.has_prefix ("~/")) {
                        identity_path = Path.build_filename (Environment.get_home_dir (), identity_path.substring (2));
                    }
                    
                    var file = File.new_for_path (identity_path);
                    if (!file.query_exists ()) {
                        warning ("Identity file %s does not exist for host %s", identity_path, host.name);
                    }
                }
            }
            
            return true;
        }
        
        public GenericArray<string> get_host_templates () {
            var templates = new GenericArray<string> ();
            templates.add ("Basic Server");
            templates.add ("GitHub");
            templates.add ("GitLab");
            templates.add ("Jump Host");
            templates.add ("Development Server");
            return templates;
        }
        
        public SSHConfigHost create_from_template (string template_name, string host_name) {
            var host = new SSHConfigHost (host_name);
            
            switch (template_name) {
                case "GitHub":
                    host.hostname = "github.com";
                    host.user = "git";
                    host.port = 22;
                    break;
                    
                case "GitLab":
                    host.hostname = "gitlab.com";
                    host.user = "git";
                    host.port = 22;
                    break;
                    
                case "Jump Host":
                    host.forward_agent = true;
                    host.add_custom_option ("ControlMaster", "auto");
                    host.add_custom_option ("ControlPath", "~/.ssh/control-%h-%p-%r");
                    host.add_custom_option ("ControlPersist", "10m");
                    break;
                    
                case "Development Server":
                    host.forward_agent = true;
                    host.strict_host_key_checking = false;
                    host.add_custom_option ("LogLevel", "ERROR");
                    break;
                    
                default: // Basic Server
                    host.port = 22;
                    break;
            }
            
            return host;
        }
    }
}