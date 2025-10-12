/*
 * Key Maker - Page Models
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {
    
    // Diagnostic models
    public enum DiagnosticTestType {
        QUICK,
        DETAILED
    }
    
    public enum DiagnosticStatus {
        SUCCESS,
        WARNING,
        ERROR
    }
    
    public enum DiagnosticState {
        PENDING,
        RUNNING,
        COMPLETED,
        CANCELLED,
        FAILED
    }
    
    public enum DiagnosticType {
        CONNECTION_TEST,
        PERFORMANCE_TEST,
        SECURITY_AUDIT,
        PROTOCOL_ANALYSIS,
        TUNNEL_TEST,
        PERMISSION_CHECK
    }
    
    public class DiagnosticConfiguration : GLib.Object {
        public string id { get; set; }
        public string name { get; set; }
        public string description { get; set; }
        public DiagnosticType diagnostic_type { get; set; }
        public DateTime created_at { get; set; }
        public DateTime? last_run { get; set; }
        
        // Connection parameters
        public string hostname { get; set; default = ""; }
        public string username { get; set; default = ""; }
        public int port { get; set; default = 22; }
        public string auth_method { get; set; default = "key"; }
        public string ssh_key_path { get; set; default = ""; }
        public string password { get; set; default = ""; }
        public int timeout { get; set; default = 10; }
        public string proxy_jump { get; set; default = ""; }
        
        // Test options
        public bool test_basic_connection { get; set; default = true; }
        public bool test_dns_resolution { get; set; default = true; }
        public bool test_protocol_detection { get; set; default = true; }
        public bool test_performance { get; set; default = false; }
        public bool test_tunnel_capabilities { get; set; default = false; }
        public bool test_permissions { get; set; default = false; }
        
        public DiagnosticConfiguration() {
            id = Uuid.string_random();
            created_at = new DateTime.now_local();
        }
        
        public DiagnosticConfiguration.with_type(DiagnosticType diagnostic_type) {
            this();
            this.diagnostic_type = diagnostic_type;
            setup_default_options_for_type(diagnostic_type);
        }
        
        private void setup_default_options_for_type(DiagnosticType diagnostic_type) {
            switch (diagnostic_type) {
                case CONNECTION_TEST:
                    name = _("Connection Test");
                    description = _("Test basic SSH connectivity");
                    test_basic_connection = true;
                    test_dns_resolution = true;
                    break;
                case PERFORMANCE_TEST:
                    name = _("Performance Test");
                    description = _("Measure connection performance and latency");
                    test_basic_connection = true;
                    test_performance = true;
                    break;
                case SECURITY_AUDIT:
                    name = _("Security Audit");
                    description = _("Comprehensive security and permissions check");
                    test_basic_connection = true;
                    test_permissions = true;
                    test_protocol_detection = true;
                    break;
                case PROTOCOL_ANALYSIS:
                    name = _("Protocol Analysis");
                    description = _("Analyze SSH protocol capabilities");
                    test_protocol_detection = true;
                    test_tunnel_capabilities = true;
                    break;
                case TUNNEL_TEST:
                    name = _("Tunnel Test");
                    description = _("Test port forwarding and tunneling capabilities");
                    test_basic_connection = true;
                    test_tunnel_capabilities = true;
                    break;
                case PERMISSION_CHECK:
                    name = _("Permission Check");
                    description = _("Verify user permissions and file access");
                    test_basic_connection = true;
                    test_permissions = true;
                    break;
            }
        }
        
        public Json.Object to_json() {
            var obj = new Json.Object();
            obj.set_string_member("id", id);
            obj.set_string_member("name", name);
            obj.set_string_member("description", description);
            obj.set_int_member("diagnostic_type", (int)diagnostic_type);
            obj.set_int_member("created_at", created_at.to_unix());
            if (last_run != null) {
                obj.set_int_member("last_run", last_run.to_unix());
            }
            
            // Connection parameters
            obj.set_string_member("hostname", hostname);
            obj.set_string_member("username", username);
            obj.set_int_member("port", port);
            obj.set_string_member("auth_method", auth_method);
            obj.set_string_member("ssh_key_path", ssh_key_path);
            obj.set_int_member("timeout", timeout);
            obj.set_string_member("proxy_jump", proxy_jump);
            
            // Test options
            obj.set_boolean_member("test_basic_connection", test_basic_connection);
            obj.set_boolean_member("test_dns_resolution", test_dns_resolution);
            obj.set_boolean_member("test_protocol_detection", test_protocol_detection);
            obj.set_boolean_member("test_performance", test_performance);
            obj.set_boolean_member("test_tunnel_capabilities", test_tunnel_capabilities);
            obj.set_boolean_member("test_permissions", test_permissions);
            
            return obj;
        }
        
        public static DiagnosticConfiguration? from_json(Json.Object obj) {
            try {
                var config = new DiagnosticConfiguration();
                config.id = obj.get_string_member("id");
                config.name = obj.get_string_member("name");
                config.description = obj.get_string_member("description");
                config.diagnostic_type = (DiagnosticType)obj.get_int_member("diagnostic_type");
                config.created_at = new DateTime.from_unix_local(obj.get_int_member("created_at"));
                if (obj.has_member("last_run")) {
                    config.last_run = new DateTime.from_unix_local(obj.get_int_member("last_run"));
                }
                
                config.hostname = obj.get_string_member("hostname");
                config.username = obj.get_string_member("username");
                config.port = (int)obj.get_int_member("port");
                config.auth_method = obj.get_string_member("auth_method");
                config.ssh_key_path = obj.get_string_member("ssh_key_path");
                config.timeout = (int)obj.get_int_member("timeout");
                config.proxy_jump = obj.get_string_member("proxy_jump");
                
                config.test_basic_connection = obj.get_boolean_member("test_basic_connection");
                config.test_dns_resolution = obj.get_boolean_member("test_dns_resolution");
                config.test_protocol_detection = obj.get_boolean_member("test_protocol_detection");
                config.test_performance = obj.get_boolean_member("test_performance");
                config.test_tunnel_capabilities = obj.get_boolean_member("test_tunnel_capabilities");
                config.test_permissions = obj.get_boolean_member("test_permissions");
                
                return config;
            } catch (Error e) {
                warning("Failed to parse DiagnosticConfiguration from JSON: %s", e.message);
                return null;
            }
        }
    }
    
    public class DiagnosticEntry : GLib.Object {
        public DiagnosticConfiguration config { get; set; }
        public DiagnosticState state { get; set; }
        public DateTime? started_at { get; set; }
        public DateTime? completed_at { get; set; }
        public int progress_percentage { get; set; default = 0; }
        public string current_operation { get; set; default = ""; }
        public GenericArray<DiagnosticResult>? results { get; set; }
        public string? error_message { get; set; }
        
        public DiagnosticEntry(DiagnosticConfiguration configuration) {
            config = configuration;
            state = DiagnosticState.PENDING;
            results = new GenericArray<DiagnosticResult>();
        }
        
        public void start() {
            state = DiagnosticState.RUNNING;
            started_at = new DateTime.now_local();
            progress_percentage = 0;
            current_operation = _("Starting diagnostic...");
        }
        
        public void complete(GenericArray<DiagnosticResult> test_results) {
            state = DiagnosticState.COMPLETED;
            completed_at = new DateTime.now_local();
            progress_percentage = 100;
            current_operation = _("Completed");
            results = test_results;
            config.last_run = completed_at;
        }
        
        public void cancel(string? reason = null) {
            state = DiagnosticState.CANCELLED;
            completed_at = new DateTime.now_local();
            current_operation = _("Cancelled");
            error_message = reason;
        }
        
        public void fail(string error) {
            state = DiagnosticState.FAILED;
            completed_at = new DateTime.now_local();
            current_operation = _("Failed");
            error_message = error;
        }
        
        public bool is_running() {
            return state == DiagnosticState.RUNNING;
        }
        
        public bool is_completed() {
            return state == DiagnosticState.COMPLETED;
        }
        
        public bool is_finished() {
            return state == DiagnosticState.COMPLETED || 
                   state == DiagnosticState.CANCELLED || 
                   state == DiagnosticState.FAILED;
        }
        
        public string get_display_name() {
            if (config.name != "") {
                return config.name;
            }
            return @"$(config.username)@$(config.hostname):$(config.port)";
        }
        
        public Json.Object to_json() {
            var obj = new Json.Object();
            obj.set_object_member("config", config.to_json());
            obj.set_int_member("state", (int)state);
            if (started_at != null) {
                obj.set_int_member("started_at", started_at.to_unix());
            }
            if (completed_at != null) {
                obj.set_int_member("completed_at", completed_at.to_unix());
            }
            obj.set_int_member("progress_percentage", progress_percentage);
            obj.set_string_member("current_operation", current_operation);
            if (error_message != null) {
                obj.set_string_member("error_message", error_message);
            }
            return obj;
        }
        
        public static DiagnosticEntry? from_json(Json.Object obj) {
            try {
                var config = DiagnosticConfiguration.from_json(obj.get_object_member("config"));
                if (config == null) {
                    return null;
                }
                
                var entry = new DiagnosticEntry(config);
                entry.state = (DiagnosticState)obj.get_int_member("state");
                if (obj.has_member("started_at")) {
                    entry.started_at = new DateTime.from_unix_local(obj.get_int_member("started_at"));
                }
                if (obj.has_member("completed_at")) {
                    entry.completed_at = new DateTime.from_unix_local(obj.get_int_member("completed_at"));
                }
                entry.progress_percentage = (int)obj.get_int_member("progress_percentage");
                entry.current_operation = obj.get_string_member("current_operation");
                if (obj.has_member("error_message")) {
                    entry.error_message = obj.get_string_member("error_message");
                }
                
                return entry;
            } catch (Error e) {
                warning("Failed to parse DiagnosticEntry from JSON: %s", e.message);
                return null;
            }
        }
    }
    
    public class DiagnosticTest : GLib.Object {
        public string name { get; set; }
        public string description { get; set; }
        public DiagnosticTestType test_type { get; set; }
    }
    
    // SSHTunnel and SSHTunnelConfig should be defined elsewhere
    // DiagnosticResult should be defined elsewhere
    // RotationPlan should be defined elsewhere
    
    public class RollbackEntry : GLib.Object {
        public string plan_name { get; set; }
        public DateTime executed_at { get; set; }
        public DateTime expiry_date { get; set; }
        public string backup_path { get; set; }
    }
}