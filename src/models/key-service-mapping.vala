/*
 * Key Maker - Key to Service Mapping Model
 * 
 * Manages associations between SSH keys and services/servers.
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {
    
    public enum ServiceType {
        GITHUB,
        GITLAB,
        BITBUCKET,
        SERVER,
        WORK,
        PERSONAL,
        CLIENT,
        OTHER;
        
        public string to_string () {
            switch (this) {
                case GITHUB: return "GitHub";
                case GITLAB: return "GitLab";
                case BITBUCKET: return "Bitbucket";
                case SERVER: return "Server";
                case WORK: return "Work";
                case PERSONAL: return "Personal";
                case CLIENT: return "Client";
                case OTHER: return "Other";
                default: return "Unknown";
            }
        }
        
        public string get_icon_name () {
            switch (this) {
                case GITHUB: return "github-symbolic";
                case GITLAB: return "gitlab-symbolic";
                case BITBUCKET: return "bitbucket-symbolic";
                case SERVER: return "network-server-symbolic";
                case WORK: return "briefcase-symbolic";
                case PERSONAL: return "user-home-symbolic";
                case CLIENT: return "avatar-default-symbolic";
                case OTHER: return "applications-other-symbolic";
                default: return "emblem-system-symbolic";
            }
        }
        
        public static ServiceType from_string (string str) {
            switch (str.down ()) {
                case "github": return GITHUB;
                case "gitlab": return GITLAB;
                case "bitbucket": return BITBUCKET;
                case "server": return SERVER;
                case "work": return WORK;
                case "personal": return PERSONAL;
                case "client": return CLIENT;
                case "other": return OTHER;
                default: return OTHER;
            }
        }
    }
    
    public class KeyServiceMapping : GLib.Object {
        public string key_fingerprint { get; set; }
        public string service_name { get; set; }
        public ServiceType service_type { get; set; }
        public string? hostname { get; set; }
        public string? username { get; set; }
        public string? description { get; set; }
        public DateTime created_at { get; set; }
        public DateTime last_used { get; set; }
        public int usage_count { get; set; default = 0; }
        public bool is_active { get; set; default = true; }
        
        public KeyServiceMapping (string fingerprint, string name, ServiceType type) {
            key_fingerprint = fingerprint;
            service_name = name;
            service_type = type;
            created_at = new DateTime.now_local ();
            last_used = new DateTime.now_local ();
        }
        
        public void update_usage () {
            usage_count++;
            last_used = new DateTime.now_local ();
        }
        
        public bool is_recently_used (int days = 30) {
            var cutoff = new DateTime.now_local ().add_days (-days);
            return last_used.compare (cutoff) > 0;
        }
        
        public string get_display_name () {
            if (hostname != null && username != null) {
                return @"$(username)@$(hostname)";
            } else if (hostname != null) {
                return hostname;
            } else {
                return service_name;
            }
        }
    }
    
    public class KeyServiceMappingManager : GLib.Object {
        private GenericArray<KeyServiceMapping> mappings;
        private Settings settings;
        private string settings_key = "key-service-mappings";
        
        public signal void mappings_changed ();
        
        construct {
#if DEVELOPMENT
            settings = new Settings ("io.github.tobagin.keysmith.Devel");
#else
            settings = new Settings ("io.github.tobagin.keysmith");
#endif
            mappings = new GenericArray<KeyServiceMapping> ();
            load_mappings ();
        }
        
        public void add_mapping (KeyServiceMapping mapping) {
            // Check if mapping already exists
            for (int i = 0; i < mappings.length; i++) {
                var existing = mappings[i];
                if (existing.key_fingerprint == mapping.key_fingerprint &&
                    existing.service_name == mapping.service_name &&
                    existing.service_type == mapping.service_type) {
                    // Update existing mapping
                    existing.hostname = mapping.hostname;
                    existing.username = mapping.username;
                    existing.description = mapping.description;
                    existing.is_active = mapping.is_active;
                    save_mappings ();
                    mappings_changed ();
                    return;
                }
            }
            
            // Add new mapping
            mappings.add (mapping);
            save_mappings ();
            mappings_changed ();
        }
        
        public void remove_mapping (string key_fingerprint, string service_name, ServiceType service_type) {
            for (int i = 0; i < mappings.length; i++) {
                var mapping = mappings[i];
                if (mapping.key_fingerprint == key_fingerprint &&
                    mapping.service_name == service_name &&
                    mapping.service_type == service_type) {
                    mappings.remove_index (i);
                    save_mappings ();
                    mappings_changed ();
                    return;
                }
            }
        }
        
        public GenericArray<KeyServiceMapping> get_mappings_for_key (string key_fingerprint) {
            var result = new GenericArray<KeyServiceMapping> ();
            for (int i = 0; i < mappings.length; i++) {
                if (mappings[i].key_fingerprint == key_fingerprint && mappings[i].is_active) {
                    result.add (mappings[i]);
                }
            }
            return result;
        }
        
        public GenericArray<KeyServiceMapping> get_all_mappings () {
            return mappings;
        }
        
        public GenericArray<string> get_orphaned_keys (GenericArray<SSHKey> available_keys) {
            var orphaned = new GenericArray<string> ();
            
            for (int i = 0; i < available_keys.length; i++) {
                var key = available_keys[i];
                var key_mappings = get_mappings_for_key (key.fingerprint);
                
                // Check if key has any recent usage
                bool has_recent_usage = false;
                for (int j = 0; j < key_mappings.length; j++) {
                    if (key_mappings[j].is_recently_used (90)) { // 90 days
                        has_recent_usage = true;
                        break;
                    }
                }
                
                if (!has_recent_usage) {
                    orphaned.add (key.fingerprint);
                }
            }
            
            return orphaned;
        }
        
        public void record_key_usage (string key_fingerprint, string? service_hint = null) {
            // Update usage for all mappings of this key
            bool updated = false;
            for (int i = 0; i < mappings.length; i++) {
                var mapping = mappings[i];
                if (mapping.key_fingerprint == key_fingerprint) {
                    mapping.update_usage ();
                    updated = true;
                }
            }
            
            if (updated) {
                save_mappings ();
            }
            
            // If no mappings exist and we have a service hint, create a generic mapping
            if (!updated && service_hint != null) {
                var mapping = new KeyServiceMapping (key_fingerprint, service_hint, ServiceType.OTHER);
                mapping.update_usage ();
                add_mapping (mapping);
            }
        }
        
        public GenericArray<KeyServiceMapping> get_mappings_by_type (ServiceType type) {
            var result = new GenericArray<KeyServiceMapping> ();
            for (int i = 0; i < mappings.length; i++) {
                if (mappings[i].service_type == type && mappings[i].is_active) {
                    result.add (mappings[i]);
                }
            }
            return result;
        }
        
        public KeyServiceMapping? suggest_mapping_for_hostname (string hostname) {
            // Check for known service patterns
            if ("github.com" in hostname.down ()) {
                return new KeyServiceMapping ("", "GitHub", ServiceType.GITHUB) {
                    hostname = hostname
                };
            } else if ("gitlab.com" in hostname.down () || "gitlab" in hostname.down ()) {
                return new KeyServiceMapping ("", "GitLab", ServiceType.GITLAB) {
                    hostname = hostname
                };
            } else if ("bitbucket.org" in hostname.down ()) {
                return new KeyServiceMapping ("", "Bitbucket", ServiceType.BITBUCKET) {
                    hostname = hostname
                };
            } else {
                return new KeyServiceMapping ("", hostname, ServiceType.SERVER) {
                    hostname = hostname
                };
            }
        }
        
        private void load_mappings () {
            try {
                var variant = settings.get_value (settings_key);
                if (variant.get_type_string () == "aa{sv}") {
                    var array = variant.get_child_value (0);
                    var n_children = (int) array.n_children ();
                    
                    for (int i = 0; i < n_children; i++) {
                        var dict = array.get_child_value (i);
                        var mapping = mapping_from_variant (dict);
                        if (mapping != null) {
                            mappings.add (mapping);
                        }
                    }
                }
            } catch (Error e) {
                warning ("Failed to load key-service mappings: %s", e.message);
            }
        }
        
        private void save_mappings () {
            try {
                var builder = new VariantBuilder (new VariantType ("aa{sv}"));
                
                for (int i = 0; i < mappings.length; i++) {
                    var dict_builder = new VariantBuilder (new VariantType ("a{sv}"));
                    var mapping = mappings[i];
                    
                    dict_builder.add ("{sv}", "key_fingerprint", new Variant.string (mapping.key_fingerprint));
                    dict_builder.add ("{sv}", "service_name", new Variant.string (mapping.service_name));
                    dict_builder.add ("{sv}", "service_type", new Variant.string (mapping.service_type.to_string ()));
                    dict_builder.add ("{sv}", "hostname", new Variant.string (mapping.hostname ?? ""));
                    dict_builder.add ("{sv}", "username", new Variant.string (mapping.username ?? ""));
                    dict_builder.add ("{sv}", "description", new Variant.string (mapping.description ?? ""));
                    dict_builder.add ("{sv}", "created_at", new Variant.int64 (mapping.created_at.to_unix ()));
                    dict_builder.add ("{sv}", "last_used", new Variant.int64 (mapping.last_used.to_unix ()));
                    dict_builder.add ("{sv}", "usage_count", new Variant.int32 (mapping.usage_count));
                    dict_builder.add ("{sv}", "is_active", new Variant.boolean (mapping.is_active));
                    
                    builder.add ("a{sv}", dict_builder);
                }
                
                var variant = new Variant ("aa{sv}", builder);
                settings.set_value (settings_key, variant);
                
            } catch (Error e) {
                warning ("Failed to save key-service mappings: %s", e.message);
            }
        }
        
        private KeyServiceMapping? mapping_from_variant (Variant dict) {
            try {
                string? key_fingerprint = null;
                string? service_name = null;
                string? service_type_str = null;
                string? hostname = null;
                string? username = null;
                string? description = null;
                int64 created_at = 0;
                int64 last_used = 0;
                int usage_count = 0;
                bool is_active = true;
                
                var iter = dict.iterator ();
                string key;
                Variant value;
                while (iter.next ("{sv}", out key, out value)) {
                    switch (key) {
                        case "key_fingerprint":
                            key_fingerprint = value.get_string ();
                            break;
                        case "service_name":
                            service_name = value.get_string ();
                            break;
                        case "service_type":
                            service_type_str = value.get_string ();
                            break;
                        case "hostname":
                            hostname = value.get_string ();
                            if (hostname == "") hostname = null;
                            break;
                        case "username":
                            username = value.get_string ();
                            if (username == "") username = null;
                            break;
                        case "description":
                            description = value.get_string ();
                            if (description == "") description = null;
                            break;
                        case "created_at":
                            created_at = value.get_int64 ();
                            break;
                        case "last_used":
                            last_used = value.get_int64 ();
                            break;
                        case "usage_count":
                            usage_count = value.get_int32 ();
                            break;
                        case "is_active":
                            is_active = value.get_boolean ();
                            break;
                    }
                }
                
                if (key_fingerprint != null && service_name != null && service_type_str != null) {
                    var mapping = new KeyServiceMapping (
                        key_fingerprint,
                        service_name,
                        ServiceType.from_string (service_type_str)
                    );
                    mapping.hostname = hostname;
                    mapping.username = username;
                    mapping.description = description;
                    mapping.created_at = new DateTime.from_unix_local (created_at);
                    mapping.last_used = new DateTime.from_unix_local (last_used);
                    mapping.usage_count = usage_count;
                    mapping.is_active = is_active;
                    return mapping;
                }
                
            } catch (Error e) {
                warning ("Failed to parse mapping from variant: %s", e.message);
            }
            
            return null;
        }
    }
}