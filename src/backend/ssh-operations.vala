/*
 * Key Maker - SSH Operations Backend
 * 
 * SSH key operations using subprocess for secure command execution.
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {
    
    public class SSHOperations {
        
        /**
         * Generate SSH key using ssh-keygen
         */
        public static async SSHKey generate_key (KeyGenerationRequest request) throws KeyMakerError {
            // Validate request
            request.validate ();
            
            // Build key path
            var key_path = request.get_key_path ();
            
            // Ensure .ssh directory exists with proper permissions
            var ssh_dir = key_path.get_parent ();
            try {
                ssh_dir.make_directory_with_parents ();
                // Set permissions to 0700 (owner read/write/execute only)
                Posix.chmod (ssh_dir.get_path (), 0x1C0); // 0700 octal = 448 decimal = 0x1C0 hex
            } catch (Error e) {
                if (!(e is IOError.EXISTS)) {
                    throw new KeyMakerError.OPERATION_FAILED ("Failed to create SSH directory: %s", e.message);
                }
            }
            
            // Check if key already exists
            var public_path = File.new_for_path (key_path.get_path () + ".pub");
            if (key_path.query_exists () || public_path.query_exists ()) {
                throw new KeyMakerError.OPERATION_FAILED ("Key %s already exists", request.filename);
            }
            
            // Build command args safely
            var cmd_list = new GenericArray<string> ();
            cmd_list.add ("ssh-keygen");
            cmd_list.add ("-t");
            cmd_list.add (request.key_type.to_string ());
            
            // Add algorithm-specific options
            switch (request.key_type) {
                case SSHKeyType.ED25519:
                    // Ed25519 has fixed size, no bits option
                    break;
                case SSHKeyType.RSA:
                    cmd_list.add ("-b");
                    cmd_list.add (request.rsa_bits.to_string ());
                    break;
                case SSHKeyType.ECDSA:
                    // ECDSA with 256-bit curve (default)
                    cmd_list.add ("-b");
                    cmd_list.add ("256");
                    break;
            }
            
            // Add common options
            cmd_list.add ("-f");
            cmd_list.add (key_path.get_path ());
            
            if (request.comment != null && request.comment.strip () != "") {
                cmd_list.add ("-C");
                cmd_list.add (request.comment.strip ());
            }
            
            // Handle passphrase (-N for new keys)
            cmd_list.add ("-N");
            cmd_list.add (request.passphrase ?? "");
            
            // Convert to string array for subprocess
            string[] cmd = new string[cmd_list.length + 1];
            for (int i = 0; i < cmd_list.length; i++) {
                cmd[i] = cmd_list[i];
            }
            cmd[cmd_list.length] = null;
            
            // Debug output
            var cmd_str = string.joinv (" ", cmd);
            debug ("Executing: %s", cmd_str);
            
            try {
                // Execute ssh-keygen command
                // CRITICAL: Never use shell for security
                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                var subprocess = launcher.spawnv (cmd);
                
                yield subprocess.wait_async ();
                
                if (subprocess.get_exit_status () != 0) {
                    var stderr_stream = subprocess.get_stderr_pipe ();
                    var stderr_reader = new DataInputStream (stderr_stream);
                    var error_message = yield stderr_reader.read_line_async ();
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Key generation failed: %s", error_message ?? "Unknown error");
                }
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to execute ssh-keygen: %s", e.message);
            }
            
            // Verify permissions (ssh-keygen should set 0600 automatically)
            if (key_path.query_exists ()) {
                Posix.chmod (key_path.get_path (), 0x180); // 0600 octal = 384 decimal = 0x180 hex
            }
            
            // Get fingerprint for the new key
            var fingerprint = yield get_fingerprint (key_path);
            
            // Get current time
            var now = new DateTime.now_local ();
            
            return new SSHKey (
                key_path,
                public_path,
                request.key_type,
                fingerprint,
                request.comment,
                now,
                request.key_type == SSHKeyType.RSA ? request.rsa_bits : -1
            );
        }
        
        /**
         * Get SSH key fingerprint using ssh-keygen
         */
        public static async string get_fingerprint (File key_path) throws KeyMakerError {
            return yield get_fingerprint_with_cancellable (key_path, null);
        }
        
        public static string get_fingerprint_sync (File key_path) throws KeyMakerError {
            // Use public key if available, otherwise private key
            File target_path;
            var public_path = File.new_for_path (key_path.get_path () + ".pub");
            
            if (public_path.query_exists ()) {
                target_path = public_path;
            } else {
                target_path = key_path;
            }
            
            if (!target_path.query_exists ()) {
                throw new KeyMakerError.KEY_NOT_FOUND ("Key file not found: %s", target_path.get_path ());
            }
            
            string[] cmd = {"ssh-keygen", "-lf", target_path.get_path ()};
            
            try {
                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                launcher.set_flags (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                var subprocess = launcher.spawnv (cmd);
                
                if (subprocess == null) {
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to spawn ssh-keygen process");
                }
                
                try {
                    subprocess.wait ();
                } catch (Error wait_error) {
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to wait for subprocess: %s", wait_error.message);
                }
                
                if (subprocess.get_exit_status () != 0) {
                    var stderr_stream = subprocess.get_stderr_pipe ();
                    var stderr_reader = new DataInputStream (stderr_stream);
                    string? error_message = null;
                    try {
                        error_message = stderr_reader.read_line ();
                    } catch (Error read_error) {
                        debug ("Failed to read stderr: %s", read_error.message);
                    }
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to get fingerprint: %s", error_message ?? "Unknown error");
                }
                
                // Parse fingerprint from output
                var stdout_stream = subprocess.get_stdout_pipe ();
                if (stdout_stream == null) {
                    throw new KeyMakerError.OPERATION_FAILED ("Failed to get stdout stream from subprocess");
                }
                var stdout_reader = new DataInputStream (stdout_stream);
                string? fingerprint_line = null;
                try {
                    fingerprint_line = stdout_reader.read_line ();
                } catch (Error read_error) {
                    throw new KeyMakerError.OPERATION_FAILED ("Failed to read subprocess output: %s", read_error.message);
                }
                
                if (fingerprint_line != null) {
                    // Format: "2048 SHA256:... user@host (RSA)"
                    var parts = fingerprint_line.split (" ");
                    if (parts.length >= 2) {
                        return parts[1]; // SHA256:... part
                    }
                }
                
                throw new KeyMakerError.OPERATION_FAILED ("Unable to parse fingerprint");
                
            } catch (KeyMakerError e) {
                throw e;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to get fingerprint: %s", e.message);
            }
        }
        
        public static async string get_fingerprint_with_cancellable (File key_path, Cancellable? cancellable) throws KeyMakerError {
            // Use public key if available, otherwise private key
            File target_path;
            var public_path = File.new_for_path (key_path.get_path () + ".pub");
            
            if (public_path.query_exists ()) {
                target_path = public_path;
            } else {
                target_path = key_path;
            }
            
            if (!target_path.query_exists ()) {
                throw new KeyMakerError.KEY_NOT_FOUND ("Key file not found: %s", target_path.get_path ());
            }
            
            string[] cmd = {"ssh-keygen", "-lf", target_path.get_path ()};
            
            try {
                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                launcher.set_flags (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                var subprocess = launcher.spawnv (cmd);
                
                bool result = yield subprocess.wait_async (cancellable);
                if (!result) {
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Subprocess wait failed");
                }
                
                if (subprocess.get_exit_status () != 0) {
                    var stderr_stream = subprocess.get_stderr_pipe ();
                    var stderr_reader = new DataInputStream (stderr_stream);
                    string? error_message = null;
                    try {
                        error_message = yield stderr_reader.read_line_async ();
                    } catch (Error read_error) {
                        debug ("Failed to read stderr: %s", read_error.message);
                    }
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to get fingerprint: %s", error_message ?? "Unknown error");
                }
                
                // Parse fingerprint from output
                var stdout_stream = subprocess.get_stdout_pipe ();
                var stdout_reader = new DataInputStream (stdout_stream);
                string? fingerprint_line = null;
                try {
                    fingerprint_line = yield stdout_reader.read_line_async ();
                } catch (Error read_error) {
                    throw new KeyMakerError.OPERATION_FAILED ("Failed to read subprocess output: %s", read_error.message);
                }
                
                if (fingerprint_line != null) {
                    // Format: "2048 SHA256:... user@host (RSA)"
                    var parts = fingerprint_line.split (" ");
                    if (parts.length >= 2) {
                        return parts[1]; // SHA256:... part
                    }
                }
                
                throw new KeyMakerError.OPERATION_FAILED ("Unable to parse fingerprint");
                
            } catch (KeyMakerError e) {
                throw e;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to get fingerprint: %s", e.message);
            }
        }
        
        /**
         * Determine SSH key type from key file
         */
        public static async SSHKeyType get_key_type (File key_path) throws KeyMakerError {
            return yield get_key_type_with_cancellable (key_path, null);
        }
        
        public static SSHKeyType get_key_type_sync (File key_path) throws KeyMakerError {
            // Use public key if available
            File target_path;
            var public_path = File.new_for_path (key_path.get_path () + ".pub");
            
            if (public_path.query_exists ()) {
                target_path = public_path;
            } else {
                target_path = key_path;
            }
            
            if (!target_path.query_exists ()) {
                throw new KeyMakerError.KEY_NOT_FOUND ("Key file not found: %s", target_path.get_path ());
            }
            
            string[] cmd = {"ssh-keygen", "-lf", target_path.get_path ()};
            
            try {
                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                launcher.set_flags (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                var subprocess = launcher.spawnv (cmd);
                
                if (subprocess == null) {
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to spawn ssh-keygen process");
                }
                
                try {
                    subprocess.wait ();
                } catch (Error wait_error) {
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to wait for subprocess: %s", wait_error.message);
                }
                
                if (subprocess.get_exit_status () != 0) {
                    var stderr_stream = subprocess.get_stderr_pipe ();
                    var stderr_reader = new DataInputStream (stderr_stream);
                    string? error_message = null;
                    try {
                        error_message = stderr_reader.read_line ();
                    } catch (Error read_error) {
                        debug ("Failed to read stderr: %s", read_error.message);
                    }
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to determine key type: %s", error_message ?? "Unknown error");
                }
                
                // Parse key type from output
                var stdout_stream = subprocess.get_stdout_pipe ();
                var stdout_reader = new DataInputStream (stdout_stream);
                string? output_line = null;
                try {
                    output_line = stdout_reader.read_line ();
                } catch (Error read_error) {
                    throw new KeyMakerError.OPERATION_FAILED ("Failed to read subprocess output: %s", read_error.message);
                }
                
                if (output_line != null) {
                    // Format: "2048 SHA256:... user@host (RSA)"
                    if ("(RSA)" in output_line) {
                        return SSHKeyType.RSA;
                    } else if ("(ED25519)" in output_line) {
                        return SSHKeyType.ED25519;
                    } else if ("(ECDSA)" in output_line) {
                        return SSHKeyType.ECDSA;
                    }
                }
                
                throw new KeyMakerError.INVALID_KEY_TYPE ("Unknown key type");
                
            } catch (KeyMakerError e) {
                throw e;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to determine key type: %s", e.message);
            }
        }
        
        public static async SSHKeyType get_key_type_with_cancellable (File key_path, Cancellable? cancellable) throws KeyMakerError {
            // Use public key if available
            File target_path;
            var public_path = File.new_for_path (key_path.get_path () + ".pub");
            
            if (public_path.query_exists ()) {
                target_path = public_path;
            } else {
                target_path = key_path;
            }
            
            if (!target_path.query_exists ()) {
                throw new KeyMakerError.KEY_NOT_FOUND ("Key file not found: %s", target_path.get_path ());
            }
            
            string[] cmd = {"ssh-keygen", "-lf", target_path.get_path ()};
            
            try {
                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                launcher.set_flags (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                var subprocess = launcher.spawnv (cmd);
                
                bool result = yield subprocess.wait_async (cancellable);
                if (!result) {
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Subprocess wait failed");
                }
                
                if (subprocess.get_exit_status () != 0) {
                    var stderr_stream = subprocess.get_stderr_pipe ();
                    var stderr_reader = new DataInputStream (stderr_stream);
                    string? error_message = null;
                    try {
                        error_message = yield stderr_reader.read_line_async ();
                    } catch (Error read_error) {
                        debug ("Failed to read stderr: %s", read_error.message);
                    }
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to determine key type: %s", error_message ?? "Unknown error");
                }
                
                // Parse key type from output
                var stdout_stream = subprocess.get_stdout_pipe ();
                var stdout_reader = new DataInputStream (stdout_stream);
                string? output_line = null;
                try {
                    output_line = yield stdout_reader.read_line_async ();
                } catch (Error read_error) {
                    throw new KeyMakerError.OPERATION_FAILED ("Failed to read subprocess output: %s", read_error.message);
                }
                
                if (output_line != null) {
                    // Format: "2048 SHA256:... user@host (RSA)"
                    if ("(RSA)" in output_line) {
                        return SSHKeyType.RSA;
                    } else if ("(ED25519)" in output_line) {
                        return SSHKeyType.ED25519;
                    } else if ("(ECDSA)" in output_line) {
                        return SSHKeyType.ECDSA;
                    }
                }
                
                throw new KeyMakerError.INVALID_KEY_TYPE ("Unknown key type");
                
            } catch (KeyMakerError e) {
                throw e;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to determine key type: %s", e.message);
            }
        }
        
        /**
         * Change SSH key passphrase using ssh-keygen
         */
        public static async void change_passphrase (PassphraseChangeRequest request) throws KeyMakerError {
            var key_path = request.ssh_key.private_path;
            
            if (!key_path.query_exists ()) {
                throw new KeyMakerError.KEY_NOT_FOUND ("Private key not found: %s", key_path.get_path ());
            }
            
            string[] cmd = {"ssh-keygen", "-p", "-f", key_path.get_path ()};
            
            try {
                // Create process with stdin pipe for passphrase input
                var launcher = new SubprocessLauncher (
                    SubprocessFlags.STDIN_PIPE | SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE
                );
                var subprocess = launcher.spawnv (cmd);
                
                // Prepare input: old passphrase, new passphrase, confirm new passphrase
                var input_data = new StringBuilder ();
                
                if (request.current_passphrase != null) {
                    input_data.append (request.current_passphrase);
                }
                input_data.append ("\n");
                
                if (request.new_passphrase != null) {
                    input_data.append (request.new_passphrase);
                    input_data.append ("\n");
                    input_data.append (request.new_passphrase); // Confirm
                }
                input_data.append ("\n\n");
                
                var stdin_stream = subprocess.get_stdin_pipe ();
                yield stdin_stream.write_async (input_data.str.data);
                yield stdin_stream.close_async ();
                
                yield subprocess.wait_async ();
                
                if (subprocess.get_exit_status () != 0) {
                    var stderr_stream = subprocess.get_stderr_pipe ();
                    var stderr_reader = new DataInputStream (stderr_stream);
                    var error_message = yield stderr_reader.read_line_async ();
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Passphrase change failed: %s", error_message ?? "Unknown error");
                }
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to change passphrase: %s", e.message);
            }
        }
        
        /**
         * Delete SSH key pair (both private and public keys)
         */
        public static async void delete_key_pair (SSHKey ssh_key) throws KeyMakerError {
            var errors = new GenericArray<string> ();
            
            // Delete private key
            if (ssh_key.private_path.query_exists ()) {
                try {
                    yield ssh_key.private_path.delete_async ();
                } catch (Error e) {
                    errors.add ("Failed to delete private key: %s".printf (e.message));
                }
            }
            
            // Delete public key
            if (ssh_key.public_path.query_exists ()) {
                try {
                    yield ssh_key.public_path.delete_async ();
                } catch (Error e) {
                    errors.add ("Failed to delete public key: %s".printf (e.message));
                }
            }
            
            if (errors.length > 0) {
                var error_message = new StringBuilder ();
                for (int i = 0; i < errors.length; i++) {
                    if (i > 0) error_message.append ("; ");
                    error_message.append (errors[i]);
                }
                throw new KeyMakerError.OPERATION_FAILED (error_message.str);
            }
        }
        
        /**
         * Get public key content for clipboard copying
         */
        public static string get_public_key_content (SSHKey ssh_key) throws KeyMakerError {
            if (!ssh_key.public_path.query_exists ()) {
                throw new KeyMakerError.KEY_NOT_FOUND ("Public key not found: %s", ssh_key.public_path.get_path ());
            }
            
            try {
                uint8[] contents;
                ssh_key.public_path.load_contents (null, out contents, null);
                return ((string) contents).strip ();
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to read public key: %s", e.message);
            }
        }
        
        /**
         * Extract bit size from key output
         */
        public static async int? extract_bit_size (File key_path) throws KeyMakerError {
            return yield extract_bit_size_with_cancellable (key_path, null);
        }
        
        public static int? extract_bit_size_sync (File key_path) throws KeyMakerError {
            string[] cmd = {"ssh-keygen", "-lf", key_path.get_path ()};
            
            try {
                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                launcher.set_flags (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                var subprocess = launcher.spawnv (cmd);
                
                if (subprocess == null) {
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to spawn ssh-keygen process");
                }
                
                try {
                    subprocess.wait ();
                } catch (Error wait_error) {
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to wait for subprocess: %s", wait_error.message);
                }
                
                if (subprocess.get_exit_status () != 0) {
                    return null;
                }
                
                // Parse bit size from output
                var stdout_stream = subprocess.get_stdout_pipe ();
                var stdout_reader = new DataInputStream (stdout_stream);
                string? output_line = null;
                try {
                    output_line = stdout_reader.read_line ();
                } catch (Error read_error) {
                    debug ("Failed to read subprocess output: %s", read_error.message);
                    return null;
                }
                
                if (output_line != null) {
                    // Format: "2048 SHA256:... user@host (RSA)"
                    var parts = output_line.split (" ");
                    if (parts.length >= 1) {
                        return int.parse (parts[0]);
                    }
                }
                
                return null;
                
            } catch (Error e) {
                debug ("extract_bit_size_sync error: %s", e.message);
                return null;
            }
        }
        
        public static async int? extract_bit_size_with_cancellable (File key_path, Cancellable? cancellable) throws KeyMakerError {
            string[] cmd = {"ssh-keygen", "-lf", key_path.get_path ()};
            
            try {
                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                launcher.set_flags (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                var subprocess = launcher.spawnv (cmd);
                
                bool result = yield subprocess.wait_async (cancellable);
                if (!result) {
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Subprocess wait failed");
                }
                
                if (subprocess.get_exit_status () != 0) {
                    return null;
                }
                
                // Parse bit size from output
                var stdout_stream = subprocess.get_stdout_pipe ();
                var stdout_reader = new DataInputStream (stdout_stream);
                string? output_line = null;
                try {
                    output_line = yield stdout_reader.read_line_async ();
                } catch (Error read_error) {
                    debug ("Failed to read subprocess output: %s", read_error.message);
                    return null;
                }
                
                if (output_line != null) {
                    // Format: "2048 SHA256:... user@host (RSA)"
                    var parts = output_line.split (" ");
                    if (parts.length >= 1) {
                        return int.parse (parts[0]);
                    }
                }
                
                return null;
                
            } catch (Error e) {
                debug ("extract_bit_size error: %s", e.message);
                return null;
            }
        }
    }
}