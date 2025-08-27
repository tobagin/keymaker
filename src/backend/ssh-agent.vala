/*
 * Key Maker - SSH Agent Operations
 * 
 * SSH agent interaction for live monitoring and key management.
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {
    
    public class SSHAgent {
        
        public signal void agent_keys_changed ();
        
        private GenericArray<AgentKey> agent_keys;
        private bool agent_available;
        
        public struct AgentKey {
            public string fingerprint;
            public string comment;
            public string key_type;
            public int bit_size;
            public bool is_loaded;
        }
        
        construct {
            agent_keys = new GenericArray<AgentKey> ();
            agent_available = false;
        }
        
        /**
         * Check if SSH agent is available and running
         */
        public async bool check_agent_availability () throws KeyMakerError {
            string[] cmd = {"ssh-add", "-l"};
            
            try {
                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                var subprocess = launcher.spawnv (cmd);
                
                yield subprocess.wait_async ();
                
                var exit_status = subprocess.get_exit_status ();
                agent_available = (exit_status == 0 || exit_status == 1); // 0 = has keys, 1 = no keys but agent running
                
                return agent_available;
                
            } catch (Error e) {
                agent_available = false;
                throw new KeyMakerError.OPERATION_FAILED ("Failed to check SSH agent: %s", e.message);
            }
        }
        
        /**
         * Get list of keys currently loaded in SSH agent
         */
        public async GenericArray<AgentKey?> get_loaded_keys () throws KeyMakerError {
            if (!agent_available) {
                yield check_agent_availability ();
                if (!agent_available) {
                    throw new KeyMakerError.OPERATION_FAILED ("SSH agent is not available");
                }
            }
            
            agent_keys = new GenericArray<AgentKey> ();
            
            string[] cmd = {"ssh-add", "-l"};
            
            try {
                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                var subprocess = launcher.spawnv (cmd);
                
                yield subprocess.wait_async ();
                
                if (subprocess.get_exit_status () == 1) {
                    // No keys loaded
                    return agent_keys;
                }
                
                if (subprocess.get_exit_status () != 0) {
                    throw new KeyMakerError.SUBPROCESS_FAILED ("ssh-add failed");
                }
                
                var stdout_stream = subprocess.get_stdout_pipe ();
                var stdout_reader = new DataInputStream (stdout_stream);
                
                string? line;
                while ((line = yield stdout_reader.read_line_async ()) != null) {
                    var agent_key = parse_agent_key_line (line);
                    if (agent_key != null) {
                        agent_keys.add (agent_key);
                    }
                }
                
                agent_keys_changed ();
                return agent_keys;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to list agent keys: %s", e.message);
            }
        }
        
        /**
         * Add key to SSH agent
         */
        public async void add_key_to_agent (File private_key_path, int? timeout_seconds = null) throws KeyMakerError {
            if (!agent_available) {
                yield check_agent_availability ();
                if (!agent_available) {
                    throw new KeyMakerError.OPERATION_FAILED ("SSH agent is not available");
                }
            }
            
            var cmd_list = new GenericArray<string> ();
            cmd_list.add ("ssh-add");
            
            if (timeout_seconds != null && timeout_seconds > 0) {
                cmd_list.add ("-t");
                cmd_list.add (timeout_seconds.to_string ());
            }
            
            cmd_list.add (private_key_path.get_path ());
            
            string[] cmd = new string[cmd_list.length + 1];
            for (int i = 0; i < cmd_list.length; i++) {
                cmd[i] = cmd_list[i];
            }
            cmd[cmd_list.length] = null;
            
            try {
                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                var subprocess = launcher.spawnv (cmd);
                
                yield subprocess.wait_async ();
                
                if (subprocess.get_exit_status () != 0) {
                    var stderr_stream = subprocess.get_stderr_pipe ();
                    var stderr_reader = new DataInputStream (stderr_stream);
                    var error_message = yield stderr_reader.read_line_async ();
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to add key to agent: %s", error_message ?? "Unknown error");
                }
                
                // Refresh key list
                yield get_loaded_keys ();
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to add key to SSH agent: %s", e.message);
            }
        }
        
        /**
         * Remove key from SSH agent by fingerprint
         */
        public async void remove_key_from_agent (string fingerprint) throws KeyMakerError {
            if (!agent_available) {
                throw new KeyMakerError.OPERATION_FAILED ("SSH agent is not available");
            }
            
            // Find key file path by fingerprint
            var ssh_dir = File.new_for_path (Path.build_filename (Environment.get_home_dir (), ".ssh"));
            var keys = yield KeyScanner.scan_ssh_directory (ssh_dir);
            
            File? key_to_remove = null;
            for (int i = 0; i < keys.length; i++) {
                if (keys[i].fingerprint == fingerprint) {
                    key_to_remove = keys[i].private_path;
                    break;
                }
            }
            
            if (key_to_remove == null) {
                throw new KeyMakerError.KEY_NOT_FOUND ("Key with fingerprint %s not found", fingerprint);
            }
            
            string[] cmd = {"ssh-add", "-d", key_to_remove.get_path ()};
            
            try {
                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                var subprocess = launcher.spawnv (cmd);
                
                yield subprocess.wait_async ();
                
                if (subprocess.get_exit_status () != 0) {
                    var stderr_stream = subprocess.get_stderr_pipe ();
                    var stderr_reader = new DataInputStream (stderr_stream);
                    var error_message = yield stderr_reader.read_line_async ();
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to remove key from agent: %s", error_message ?? "Unknown error");
                }
                
                // Refresh key list
                yield get_loaded_keys ();
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to remove key from SSH agent: %s", e.message);
            }
        }
        
        /**
         * Remove all keys from SSH agent
         */
        public async void remove_all_keys () throws KeyMakerError {
            if (!agent_available) {
                throw new KeyMakerError.OPERATION_FAILED ("SSH agent is not available");
            }
            
            string[] cmd = {"ssh-add", "-D"};
            
            try {
                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                var subprocess = launcher.spawnv (cmd);
                
                yield subprocess.wait_async ();
                
                if (subprocess.get_exit_status () != 0) {
                    var stderr_stream = subprocess.get_stderr_pipe ();
                    var stderr_reader = new DataInputStream (stderr_stream);
                    var error_message = yield stderr_reader.read_line_async ();
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to remove all keys: %s", error_message ?? "Unknown error");
                }
                
                // Clear local key list
                agent_keys = new GenericArray<AgentKey> ();
                agent_keys_changed ();
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to remove all keys from SSH agent: %s", e.message);
            }
        }
        
        /**
         * Check if a key is loaded in the agent by fingerprint
         */
        public bool is_key_loaded (string fingerprint) {
            for (int i = 0; i < agent_keys.length; i++) {
                if (agent_keys[i].fingerprint == fingerprint) {
                    return true;
                }
            }
            return false;
        }
        
        /**
         * Parse ssh-add -l output line to AgentKey struct
         */
        private AgentKey? parse_agent_key_line (string line) {
            // Format: "2048 SHA256:... comment (RSA)"
            var parts = line.split (" ");
            if (parts.length < 3) {
                return null;
            }
            
            AgentKey key = AgentKey ();
            
            // Parse bit size
            key.bit_size = int.parse (parts[0]);
            
            // Parse fingerprint
            key.fingerprint = parts[1];
            
            // Parse key type from end of line
            if ("(RSA)" in line) {
                key.key_type = "RSA";
            } else if ("(ED25519)" in line) {
                key.key_type = "Ed25519";
            } else if ("(ECDSA)" in line) {
                key.key_type = "ECDSA";
            } else {
                key.key_type = "Unknown";
            }
            
            // Parse comment (everything between fingerprint and type)
            var comment_start = 2;
            var comment_parts = new GenericArray<string> ();
            for (int i = comment_start; i < parts.length; i++) {
                var part = parts[i];
                if (part.has_prefix ("(") && part.has_suffix (")")) {
                    break; // This is the key type
                }
                comment_parts.add (part);
            }
            key.comment = string.joinv (" ", comment_parts.data);
            key.is_loaded = true;
            
            return key;
        }
        
        /**
         * Get agent status information
         */
        public async AgentStatus get_agent_status () throws KeyMakerError {
            await check_agent_availability ();
            var keys = await get_loaded_keys ();
            
            return new AgentStatus () {
                is_available = agent_available,
                loaded_keys_count = (int) keys.length,
                agent_pid = get_agent_pid ()
            };
        }
        
        /**
         * Get SSH agent PID if available
         */
        private int get_agent_pid () {
            var ssh_agent_pid = Environment.get_variable ("SSH_AGENT_PID");
            if (ssh_agent_pid != null) {
                return int.parse (ssh_agent_pid);
            }
            return -1;
        }
    }
    
    public struct AgentStatus {
        public bool is_available;
        public int loaded_keys_count;
        public int agent_pid;
    }
}