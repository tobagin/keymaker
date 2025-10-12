/*
 * Key Maker - Diagnostic History Management
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

public struct DiagnosticHistoryEntry {
    public string name;
    public string hostname;
    public string username;
    public int port;
    public string auth_method;
    public string? key_file;
    public DateTime timestamp;
    public bool test_basic;
    public bool test_dns;
    public bool test_protocol;
    public bool test_performance;
    public bool test_tunnels;
    public bool test_permissions;
    public string overall_status;
    public int total_tests;
    public int passed_tests;
    public int failed_tests;
    public int execution_time_ms;
    public string? test_results_json;
}

public class KeyMaker.DiagnosticHistory : Object {
    private const string HISTORY_FILE = "diagnostic_history.json";
    private const int MAX_HISTORY_ENTRIES = 50;
    
    private GenericArray<DiagnosticHistoryEntry?> entries;
    private File history_file;
    
    public signal void history_changed ();
    
    construct {
        entries = new GenericArray<DiagnosticHistoryEntry?> ();
        
        // Get user config directory
        var config_dir = File.new_for_path (Environment.get_user_config_dir ())
                            .get_child ("keymaker");
        
        try {
            // Ensure config directory exists
            if (!config_dir.query_exists ()) {
                config_dir.make_directory_with_parents ();
            }
        } catch (Error e) {
            warning ("Failed to create config directory: %s", e.message);
        }
        
        history_file = config_dir.get_child (HISTORY_FILE);
        load_history.begin ();
    }
    
    public void add_entry (DiagnosticTarget target, DiagnosticOptions options, 
                          GenericArray<DiagnosticResult> results, DateTime? test_start_time = null) {
        var entry = DiagnosticHistoryEntry () {
            hostname = target.hostname,
            username = target.username,
            port = target.port,
            auth_method = target.key_file != null ? "SSH Key" : "Password",
            key_file = target.key_file,
            timestamp = test_start_time != null ? test_start_time : new DateTime.now_local (),
            test_basic = options.test_basic_connection,
            test_dns = options.test_dns_resolution,
            test_protocol = options.test_protocol_detection,
            test_performance = options.test_performance,
            test_tunnels = options.test_tunnel_capabilities,
            test_permissions = options.test_permissions,
            total_tests = (int) results.length,
            passed_tests = 0,
            failed_tests = 0,
            execution_time_ms = 0
        };
        
        // Calculate statistics from results
        for (uint i = 0; i < results.length; i++) {
            var result = results[i];
            switch (result.status) {
                case TestStatus.PASSED:
                    entry.passed_tests++;
                    break;
                case TestStatus.FAILED:
                    entry.failed_tests++;
                    break;
            }
            entry.execution_time_ms += result.execution_time_ms;
        }
        
        // Serialize test results for later retrieval
        entry.test_results_json = serialize_test_results(results);
        
        // Determine overall status
        if (entry.failed_tests == 0) {
            entry.overall_status = "PASSED";
        } else if (entry.passed_tests > entry.failed_tests) {
            entry.overall_status = "PARTIAL";
        } else {
            entry.overall_status = "FAILED";
        }
        
        // Add to beginning of list (most recent first)
        entries.insert (0, entry);
        
        // Trim to maximum entries
        while (entries.length > MAX_HISTORY_ENTRIES) {
            entries.remove_index (entries.length - 1);
        }
        
        save_history ();
        history_changed ();
    }
    
    public void add_entry_with_auth_method (DiagnosticTarget target, DiagnosticOptions options, 
                          GenericArray<DiagnosticResult> results, DateTime? test_start_time = null, string auth_method = "Unknown", string? custom_name = null) {
        var entry = DiagnosticHistoryEntry () {
            name = custom_name ?? @"$(target.username)@$(target.hostname)",
            hostname = target.hostname,
            username = target.username,
            port = target.port,
            auth_method = auth_method, // Use provided auth method
            key_file = target.key_file,
            timestamp = test_start_time != null ? test_start_time : new DateTime.now_local (),
            test_basic = options.test_basic_connection,
            test_dns = options.test_dns_resolution,
            test_protocol = options.test_protocol_detection,
            test_performance = options.test_performance,
            test_tunnels = options.test_tunnel_capabilities,
            test_permissions = options.test_permissions,
            total_tests = (int) results.length,
            passed_tests = 0,
            failed_tests = 0,
            execution_time_ms = 0
        };
        
        // Calculate statistics from results
        for (uint i = 0; i < results.length; i++) {
            var result = results[i];
            switch (result.status) {
                case TestStatus.PASSED:
                    entry.passed_tests++;
                    break;
                case TestStatus.FAILED:
                    entry.failed_tests++;
                    break;
            }
            entry.execution_time_ms += result.execution_time_ms;
        }
        
        // Serialize test results for later retrieval
        entry.test_results_json = serialize_test_results(results);
        
        // Determine overall status
        if (entry.failed_tests == 0) {
            entry.overall_status = "PASSED";
        } else if (entry.passed_tests > entry.failed_tests) {
            entry.overall_status = "PARTIAL";
        } else {
            entry.overall_status = "FAILED";
        }
        
        // Add to beginning of list (most recent first)
        entries.insert (0, entry);
        
        // Trim to maximum entries
        while (entries.length > MAX_HISTORY_ENTRIES) {
            entries.remove_index (entries.length - 1);
        }
        
        save_history ();
        history_changed ();
    }
    
    public GenericArray<DiagnosticHistoryEntry?> get_entries () {
        return entries;
    }
    
    public void clear_history () {
        entries.remove_range (0, entries.length);
        save_history ();
        history_changed ();
    }
    
    public DiagnosticHistoryEntry? get_entry (uint index) {
        if (index < entries.length) {
            return entries[index];
        }
        return null;
    }
    
    public void remove_entry (uint index) {
        if (index < entries.length) {
            entries.remove_index (index);
            save_history ();
            history_changed ();
        }
    }
    
    
    private async void load_history () {
        if (!history_file.query_exists ()) {
            return;
        }
        
        try {
            uint8[] contents;
            yield history_file.load_contents_async (null, out contents, null);
            
            var parser = new Json.Parser ();
            parser.load_from_data ((string) contents);
            
            var root_object = parser.get_root ().get_object ();
            var history_array = root_object.get_array_member ("history");
            
            entries.remove_range (0, entries.length);
            
            history_array.foreach_element ((array, index, element) => {
                var entry_object = element.get_object ();
                var entry = DiagnosticHistoryEntry () {
                    name = entry_object.has_member ("name") ? entry_object.get_string_member ("name") : "",
                    hostname = entry_object.get_string_member ("hostname"),
                    username = entry_object.get_string_member ("username"),
                    port = (int) entry_object.get_int_member ("port"),
                    auth_method = entry_object.get_string_member ("auth_method"),
                    key_file = entry_object.has_member ("key_file") ? entry_object.get_string_member ("key_file") : null,
                    timestamp = parse_timestamp_safely(entry_object.get_string_member ("timestamp")),
                    test_basic = entry_object.get_boolean_member ("test_basic"),
                    test_dns = entry_object.get_boolean_member ("test_dns"),
                    test_protocol = entry_object.get_boolean_member ("test_protocol"),
                    test_performance = entry_object.get_boolean_member ("test_performance"),
                    test_tunnels = entry_object.get_boolean_member ("test_tunnels"),
                    test_permissions = entry_object.get_boolean_member ("test_permissions"),
                    overall_status = entry_object.get_string_member ("overall_status"),
                    total_tests = (int) entry_object.get_int_member ("total_tests"),
                    passed_tests = (int) entry_object.get_int_member ("passed_tests"),
                    failed_tests = (int) entry_object.get_int_member ("failed_tests"),
                    execution_time_ms = (int) entry_object.get_int_member ("execution_time_ms"),
                    test_results_json = entry_object.has_member ("test_results_json") ? entry_object.get_string_member ("test_results_json") : null
                };
                
                entries.add (entry);
            });
            
            // Emit signal to notify UI of loaded history
            history_changed ();
            
        } catch (Error e) {
            warning ("Failed to load diagnostic history: %s", e.message);
        }
    }
    
    private void save_history () {
        try {
            var root_object = new Json.Object ();
            var history_array = new Json.Array ();
            
            for (uint i = 0; i < entries.length; i++) {
                var entry = entries[i];
                var entry_object = new Json.Object ();
                
                entry_object.set_string_member ("name", entry.name);
                entry_object.set_string_member ("hostname", entry.hostname);
                entry_object.set_string_member ("username", entry.username);
                entry_object.set_int_member ("port", entry.port);
                entry_object.set_string_member ("auth_method", entry.auth_method);
                if (entry.key_file != null) {
                    entry_object.set_string_member ("key_file", entry.key_file);
                }
                entry_object.set_string_member ("timestamp", entry.timestamp != null ? entry.timestamp.to_string () : new DateTime.now_local().to_string());
                entry_object.set_boolean_member ("test_basic", entry.test_basic);
                entry_object.set_boolean_member ("test_dns", entry.test_dns);
                entry_object.set_boolean_member ("test_protocol", entry.test_protocol);
                entry_object.set_boolean_member ("test_performance", entry.test_performance);
                entry_object.set_boolean_member ("test_tunnels", entry.test_tunnels);
                entry_object.set_boolean_member ("test_permissions", entry.test_permissions);
                entry_object.set_string_member ("overall_status", entry.overall_status);
                entry_object.set_int_member ("total_tests", entry.total_tests);
                entry_object.set_int_member ("passed_tests", entry.passed_tests);
                entry_object.set_int_member ("failed_tests", entry.failed_tests);
                entry_object.set_int_member ("execution_time_ms", entry.execution_time_ms);
                
                if (entry.test_results_json != null) {
                    entry_object.set_string_member ("test_results_json", entry.test_results_json);
                }
                
                history_array.add_object_element (entry_object);
            }
            
            root_object.set_array_member ("history", history_array);
            
            var generator = new Json.Generator ();
            generator.set_root (new Json.Node (Json.NodeType.OBJECT));
            generator.root.set_object (root_object);
            generator.pretty = true;
            
            var json_string = generator.to_data (null);
            history_file.replace_contents (json_string.data, null, false, FileCreateFlags.REPLACE_DESTINATION, null);
            
        } catch (Error e) {
            warning ("Failed to save diagnostic history: %s", e.message);
        }
    }
    
    private DateTime? parse_timestamp_safely(string? timestamp_str) {
        if (timestamp_str == null) {
            return new DateTime.now_local();
        }
        
        try {
            // Try ISO8601 format first
            var dt = new DateTime.from_iso8601(timestamp_str, null);
            if (dt != null) {
                return dt;
            }
        } catch (Error e) {
            debug ("Failed to parse ISO8601 timestamp: %s", e.message);
        }
        
        // Fallback to current time if parsing fails
        warning ("Could not parse timestamp: %s, using current time", timestamp_str);
        return new DateTime.now_local();
    }
    
    public string serialize_test_results(GenericArray<DiagnosticResult> results) {
        try {
            var results_array = new Json.Array();
            
            for (uint i = 0; i < results.length; i++) {
                var result = results[i];
                var result_object = new Json.Object();
                
                result_object.set_string_member("test_name", result.test_name ?? "Unknown Test");
                result_object.set_string_member("status", result.status.to_string());
                result_object.set_string_member("details", result.details ?? "");
                result_object.set_int_member("execution_time_ms", result.execution_time_ms);
                
                results_array.add_object_element(result_object);
            }
            
            var generator = new Json.Generator();
            generator.set_root(new Json.Node(Json.NodeType.ARRAY));
            generator.root.set_array(results_array);
            
            return generator.to_data(null);
            
        } catch (Error e) {
            warning("Failed to serialize test results: %s", e.message);
            return "[]";
        }
    }
    
    public GenericArray<DiagnosticResult>? deserialize_test_results(string? json_data) {
        if (json_data == null || json_data.length == 0) {
            return null;
        }
        
        try {
            var parser = new Json.Parser();
            parser.load_from_data(json_data);
            
            var results = new GenericArray<DiagnosticResult>();
            var results_array = parser.get_root().get_array();
            
            results_array.foreach_element((array, index, element) => {
                var result_object = element.get_object();
                var result = new DiagnosticResult(
                    result_object.get_string_member("test_name"),
                    TestStatus.PASSED, // We'll parse this properly
                    result_object.get_string_member("details")
                );
                result.execution_time_ms = (int) result_object.get_int_member("execution_time_ms");
                
                // Parse status string back to enum
                var status_str = result_object.get_string_member("status");
                switch (status_str) {
                    case "KEY_MAKER_TEST_STATUS_PASSED":
                        result.status = TestStatus.PASSED;
                        break;
                    case "KEY_MAKER_TEST_STATUS_FAILED":
                        result.status = TestStatus.FAILED;
                        break;
                    case "KEY_MAKER_TEST_STATUS_WARNING":
                        result.status = TestStatus.WARNING;
                        break;
                    case "KEY_MAKER_TEST_STATUS_SKIPPED":
                        result.status = TestStatus.SKIPPED;
                        break;
                    default:
                        result.status = TestStatus.FAILED;
                        break;
                }
                
                results.add(result);
            });
            
            return results;
            
        } catch (Error e) {
            warning("Failed to deserialize test results: %s", e.message);
            return null;
        }
    }
}