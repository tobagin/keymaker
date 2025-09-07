/*
 * Key Maker - SSH Key Metadata Parsing
 * 
 * SSH key metadata extraction including fingerprints, types, and bit sizes.
 */

namespace KeyMaker {
    
    public class SSHMetadata {
        
        /**
         * Get fingerprint of SSH key (async)
         */
        public static async string get_fingerprint (File key_path) throws KeyMakerError {
            return yield get_fingerprint_with_cancellable (key_path, null);
        }
        
        /**
         * Get fingerprint of SSH key (sync)
         */
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
                var result = new KeyMaker.Command.Result(0, "", "");
                // Note: For sync version, we'd need a sync version of Command.run_capture
                // For now, using async pattern but this should be refactored
                throw new KeyMakerError.OPERATION_FAILED("Sync fingerprint temporarily disabled - use async version");
                
            } catch (KeyMakerError e) {
                throw e;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to get fingerprint: %s", e.message);
            }
        }
        
        /**
         * Get fingerprint of SSH key with cancellation support
         */
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
                var result = yield KeyMaker.Command.run_capture(cmd, cancellable);
                
                if (result.status != 0) {
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to get fingerprint: %s", result.stderr);
                }
                
                // Parse fingerprint from output
                if (result.stdout != null && result.stdout.length > 0) {
                    // Format: "2048 SHA256:... user@host (RSA)"
                    var lines = result.stdout.split("\n");
                    if (lines.length > 0) {
                        var parts = lines[0].split (" ");
                        if (parts.length >= 2) {
                            return parts[1]; // SHA256:... part
                        }
                    }
                }
                
                throw new KeyMakerError.OPERATION_FAILED ("Unable to parse fingerprint from output: %s", result.stdout);
                
            } catch (KeyMakerError e) {
                throw e;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to get fingerprint: %s", e.message);
            }
        }
        
        /**
         * Get key type (async)
         */
        public static async SSHKeyType get_key_type (File key_path) throws KeyMakerError {
            return yield get_key_type_with_cancellable (key_path, null);
        }
        
        /**
         * Get key type (sync)
         */
        public static SSHKeyType get_key_type_sync (File key_path) throws KeyMakerError {
            // For now, disable sync version - should be refactored later
            throw new KeyMakerError.OPERATION_FAILED("Sync key type temporarily disabled - use async version");
        }
        
        /**
         * Get key type with cancellation support
         */
        public static async SSHKeyType get_key_type_with_cancellable (File key_path, Cancellable? cancellable) throws KeyMakerError {
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
                var result = yield KeyMaker.Command.run_capture(cmd, cancellable);
                
                if (result.status != 0) {
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to get key type: %s", result.stderr);
                }
                
                // Parse key type from output  
                if (result.stdout != null && result.stdout.length > 0) {
                    var lines = result.stdout.split("\n");
                    if (lines.length > 0) {
                        var line = lines[0].strip();
                        
                        // Check most specific patterns first, then broader ones
                        if (line.contains("(ED25519)") || line.contains(" ED25519 ") || line.contains("ssh-ed25519")) {
                            return SSHKeyType.ED25519;
                        } else if (line.contains("(ECDSA)") || line.contains(" ECDSA ") || line.contains("ecdsa-sha2")) {
                            return SSHKeyType.ECDSA;
                        } else if (line.contains("(RSA)") || line.contains(" RSA ") || line.contains("ssh-rsa")) {
                            return SSHKeyType.RSA;
                        }
                    }
                }
                
                // Default fallback
                return SSHKeyType.RSA; // Default assumption
                
            } catch (KeyMakerError e) {
                throw e;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to get key type: %s", e.message);
            }
        }
        
        /**
         * Extract bit size (async)
         */
        public static async int? extract_bit_size (File key_path) throws KeyMakerError {
            return yield extract_bit_size_with_cancellable (key_path, null);
        }
        
        /**
         * Extract bit size (sync)
         */
        public static int? extract_bit_size_sync (File key_path) throws KeyMakerError {
            // For now, disable sync version - should be refactored later
            throw new KeyMakerError.OPERATION_FAILED("Sync bit size extraction temporarily disabled - use async version");
        }
        
        /**
         * Extract bit size with cancellation support
         */
        public static async int? extract_bit_size_with_cancellable (File key_path, Cancellable? cancellable) throws KeyMakerError {
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
                var result = yield KeyMaker.Command.run_capture(cmd, cancellable);
                
                if (result.status != 0) {
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to get bit size: %s", result.stderr);
                }
                
                // Parse bit size from output  
                if (result.stdout != null && result.stdout.length > 0) {
                    var lines = result.stdout.split("\n");
                    if (lines.length > 0) {
                        var parts = lines[0].split (" ");
                        if (parts.length >= 1) {
                            return int.parse(parts[0]);
                        }
                    }
                }
                
                return null;
                
            } catch (KeyMakerError e) {
                throw e;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to extract bit size: %s", e.message);
            }
        }
        
        /**
         * Check if SSH key has a passphrase
         */
        public static async bool has_passphrase (SSHKey ssh_key) throws KeyMakerError {
            try {
                string[] cmd = {"ssh-keygen", "-y", "-f", ssh_key.private_path.get_path()};
                
                var subprocess = new Subprocess.newv (
                    cmd,
                    SubprocessFlags.STDIN_PIPE | SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE
                );
                
                // Send empty passphrase
                var stdin_stream = subprocess.get_stdin_pipe ();
                var stdin_writer = new DataOutputStream (stdin_stream);
                yield stdin_writer.write_async ("\n".data);
                yield stdin_writer.close_async ();
                
                yield subprocess.wait_async ();
                
                // If exit status is 0, key has no passphrase
                // If exit status != 0, key likely has a passphrase
                return subprocess.get_exit_status () != 0;
                
            } catch (Error e) {
                // If there's an error running ssh-keygen, assume key has passphrase for safety
                return true;
            }
        }
        
        /**
         * Get public key content as string
         */
        public static string get_public_key_content (SSHKey ssh_key) throws KeyMakerError {
            try {
                uint8[] content;
                ssh_key.public_path.load_contents (null, out content, null);
                return (string) content;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to read public key content: %s", e.message);
            }
        }
        
        /**
         * Parse SSH key info from ssh-keygen output line
         * Returns a structured info object with fingerprint, type, and bit size
         */
        public static SSHKeyInfo? parse_keygen_output_line(string output_line) {
            var parts = output_line.strip().split(" ");
            if (parts.length < 2) return null;
            
            var info = new SSHKeyInfo();
            
            // First part is bit size
            info.bit_size = int.parse(parts[0]);
            
            // Second part is fingerprint  
            info.fingerprint = parts[1];
            
            // Look for key type in the line - check most specific patterns first
            var line = output_line.strip();
            if (line.contains("(ED25519)") || line.contains(" ED25519 ") || line.contains("ssh-ed25519")) {
                info.key_type = SSHKeyType.ED25519;
            } else if (line.contains("(ECDSA)") || line.contains(" ECDSA ") || line.contains("ecdsa-sha2")) {
                info.key_type = SSHKeyType.ECDSA;
            } else if (line.contains("(RSA)") || line.contains(" RSA ") || line.contains("ssh-rsa")) {
                info.key_type = SSHKeyType.RSA;
            } else {
                info.key_type = SSHKeyType.RSA; // Default
            }
            
            return info;
        }
    }
    
    /**
     * Structured SSH key information
     */
    public class SSHKeyInfo : GLib.Object {
        public string fingerprint { get; set; default = ""; }
        public SSHKeyType key_type { get; set; default = SSHKeyType.RSA; }
        public int bit_size { get; set; default = -1; }
    }
}