/*
 * Key Maker - SSH Key Directory Scanner
 * 
 * SSH key directory scanning and metadata extraction.
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {
    
    public class KeyScanner {
        
        /**
         * Scan SSH directory for key pairs and return SSH key models
         */
        public static async GenericArray<SSHKey> scan_ssh_directory (File? ssh_dir = null) throws KeyMakerError {
            return yield scan_ssh_directory_with_cancellable (ssh_dir, null);
        }
        
        public static GenericArray<SSHKey> scan_ssh_directory_sync (File? ssh_dir = null) throws KeyMakerError {
            var target_dir = ssh_dir ?? File.new_for_path (Path.build_filename (Environment.get_home_dir (), ".ssh"));
            debug ("KeyScanner: Starting sync scan of directory: %s", target_dir.get_path ());
            
            if (!target_dir.query_exists ()) {
                debug ("KeyScanner: SSH directory does not exist");
                return new GenericArray<SSHKey> ();
            }
            
            try {
                var file_info = target_dir.query_info (FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE);
                if (file_info.get_file_type () != FileType.DIRECTORY) {
                    throw new KeyMakerError.OPERATION_FAILED ("SSH directory is not a directory: %s", target_dir.get_path ());
                }
            } catch (GLib.Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to access SSH directory: %s", e.message);
            }
            
            try {
                debug ("KeyScanner: Directory exists, enumerating files...");
                // Find all potential private key files
                var private_keys = new GenericArray<File> ();
                
                var enumerator = target_dir.enumerate_children (
                    FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE,
                    FileQueryInfoFlags.NONE
                );
                debug ("KeyScanner: Got enumerator, reading files...");
                
                FileInfo info;
                while ((info = enumerator.next_file (null)) != null) {
                    if (info.get_file_type () == FileType.REGULAR) {
                        var filename = info.get_name ();
                        
                        // Skip known non-key files
                        if (filename in new string[] {"config", "known_hosts", "authorized_keys"}) {
                            continue;
                        }
                        
                        // Skip .pub files (we look for private keys)
                        if (filename.has_suffix (".pub")) {
                            continue;
                        }
                        
                        var file_path = target_dir.get_child (filename);
                        
                        // Check if corresponding public key exists
                        var public_path = File.new_for_path (file_path.get_path () + ".pub");
                        if (public_path.query_exists ()) {
                            debug ("KeyScanner: Found key pair: %s", filename);
                            private_keys.add (file_path);
                        }
                    }
                }
                
                debug ("KeyScanner: Found %d private keys, building models...", private_keys.length);
                
                // Build SSH key models for each valid pair
                var ssh_keys = new GenericArray<SSHKey> ();
                
                for (int i = 0; i < private_keys.length; i++) {
                    debug ("KeyScanner: Processing key %d: %s", i, private_keys[i].get_path ());
                    try {
                        var ssh_key = build_ssh_key_model_sync (private_keys[i]);
                        if (ssh_key != null) {
                            debug ("KeyScanner: Successfully built model for key %d", i);
                            ssh_keys.add (ssh_key);
                        }
                    } catch (Error e) {
                        // Skip invalid keys but continue processing
                        debug ("Skipping invalid key %s: %s", private_keys[i].get_path (), e.message);
                        continue;
                    }
                }
                
                debug ("KeyScanner: Completed sync scan, returning %d keys", ssh_keys.length);
                return ssh_keys;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to scan SSH directory: %s", e.message);
            }
        }
        
        public static async GenericArray<SSHKey> scan_ssh_directory_with_cancellable (File? ssh_dir, Cancellable? cancellable) throws KeyMakerError {
            var target_dir = ssh_dir ?? File.new_for_path (Path.build_filename (Environment.get_home_dir (), ".ssh"));
            debug ("KeyScanner: Starting scan of directory: %s", target_dir.get_path ());
            
            if (cancellable != null && cancellable.is_cancelled ()) {
                throw new GLib.IOError.CANCELLED ("Operation was cancelled");
            }
            
            if (!target_dir.query_exists ()) {
                debug ("KeyScanner: SSH directory does not exist");
                return new GenericArray<SSHKey> ();
            }
            
            try {
                var file_info = target_dir.query_info (FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE);
                if (file_info.get_file_type () != FileType.DIRECTORY) {
                    throw new KeyMakerError.OPERATION_FAILED ("SSH directory is not a directory: %s", target_dir.get_path ());
                }
            } catch (GLib.Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to access SSH directory: %s", e.message);
            }
            
            try {
                debug ("KeyScanner: Directory exists, enumerating files...");
                // Find all potential private key files
                var private_keys = new GenericArray<File> ();

                // Use synchronous enumeration to avoid async enumerator pitfalls
                var enumerator = target_dir.enumerate_children (
                    FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE,
                    FileQueryInfoFlags.NONE
                );
                debug ("KeyScanner: Got enumerator, reading files...");

                FileInfo? info;
                while ((info = enumerator.next_file (null)) != null) {
                    if (info.get_file_type () == FileType.REGULAR) {
                        var filename = info.get_name ();
                        
                        // Skip known non-key files
                        if (filename in new string[] {"config", "known_hosts", "authorized_keys"}) {
                            continue;
                        }
                        
                        // Skip .pub files (we look for private keys)
                        if (filename.has_suffix (".pub")) {
                            continue;
                        }
                        
                        var file_path = target_dir.get_child (filename);
                        
                        // Check if corresponding public key exists
                        var public_path = File.new_for_path (file_path.get_path () + ".pub");
                        if (public_path.query_exists ()) {
                            debug ("KeyScanner: Found key pair: %s", filename);
                            private_keys.add (file_path);
                        }
                    }
                }
                
                debug ("KeyScanner: Found %d private keys, building models...", private_keys.length);
                
                // Build SSH key models for each valid pair
                var ssh_keys = new GenericArray<SSHKey> ();
                
                for (int i = 0; i < private_keys.length; i++) {
                    if (cancellable != null && cancellable.is_cancelled ()) {
                        throw new IOError.CANCELLED ("Operation was cancelled");
                    }
                    
                    debug ("KeyScanner: Processing key %d: %s", i, private_keys[i].get_path ());
                    try {
                        var ssh_key = yield build_ssh_key_model_with_cancellable (private_keys[i], cancellable);
                        if (ssh_key != null) {
                            debug ("KeyScanner: Successfully built model for key %d", i);
                            ssh_keys.add (ssh_key);
                        }
                    } catch (GLib.IOError.CANCELLED e) {
                        throw e;
                    } catch (Error e) {
                        // Skip invalid keys but continue processing
                        debug ("Skipping invalid key %s: %s", private_keys[i].get_path (), e.message);
                        continue;
                    }
                }
                
                debug ("KeyScanner: Completed scan, returning %d keys", ssh_keys.length);
                return ssh_keys;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to scan SSH directory: %s", e.message);
            }
        }
        
        /**
         * Build SSH key model from private key file
         */
        private static async SSHKey? build_ssh_key_model (File private_path) throws KeyMakerError {
            return yield build_ssh_key_model_with_cancellable (private_path, null);
        }
        
        private static SSHKey? build_ssh_key_model_sync (File private_path) throws KeyMakerError {
            debug ("KeyScanner: Building sync model for: %s", private_path.get_path ());
            try {
                var public_path = File.new_for_path (private_path.get_path () + ".pub");
                
                // Verify files still exist
                if (!private_path.query_exists () || !public_path.query_exists ()) {
                    debug ("KeyScanner: Key files no longer exist");
                    return null;
                }
                
                debug ("KeyScanner: Getting key type...");
                // Get key type with synchronous operations
                SSHKeyType key_type;
                try {
                    key_type = SSHOperations.get_key_type_sync (private_path);
                    debug ("KeyScanner: Key type: %s", key_type.to_string ());
                } catch (Error e) {
                    debug ("KeyScanner: Failed to get key type: %s", e.message);
                    return null;
                }
                
                debug ("KeyScanner: Getting fingerprint...");
                // Get fingerprint with synchronous operations
                string fingerprint;
                try {
                    fingerprint = SSHOperations.get_fingerprint_sync (private_path);
                    debug ("KeyScanner: Got fingerprint");
                } catch (Error e) {
                    debug ("KeyScanner: Failed to get fingerprint: %s", e.message);
                    return null;
                }
                
                debug ("KeyScanner: Getting file info...");
                // Get last modified time
                FileInfo file_info;
                try {
                    file_info = private_path.query_info (FileAttribute.TIME_MODIFIED, FileQueryInfoFlags.NONE);
                } catch (Error e) {
                    debug ("KeyScanner: Failed to get file info: %s", e.message);
                    return null;
                }
                var timestamp = file_info.get_attribute_uint64 (FileAttribute.TIME_MODIFIED);
                var last_modified = new DateTime.from_unix_local ((int64) timestamp);
                
                debug ("KeyScanner: Extracting comment...");
                // Extract comment from public key
                var comment = extract_comment_from_public_key (public_path);
                
                debug ("KeyScanner: Getting bit size...");
                // Extract bit size for RSA keys
                int? bit_size = null;
                if (key_type == SSHKeyType.RSA) {
                    try {
                        bit_size = SSHOperations.extract_bit_size_sync (private_path);
                    } catch (Error e) {
                        debug ("KeyScanner: Failed to get bit size: %s", e.message);
                        // Continue without bit size
                    }
                }
                
                // Ensure non-null bit size for constructor (-1 for non-RSA or unknown)
                int bit_size_final = bit_size ?? -1;
                debug ("KeyScanner: Creating SSHKey object...");
                return new SSHKey (
                    private_path,
                    public_path,
                    key_type,
                    fingerprint,
                    comment,
                    last_modified,
                    bit_size_final
                );
                
            } catch (KeyMakerError e) {
                debug ("KeyScanner: KeyMakerError building model: %s", e.message);
                throw e;
            } catch (Error e) {
                // Return null for invalid keys
                debug ("KeyScanner: Error building SSH key model for %s: %s", private_path.get_path (), e.message);
                return null;
            }
        }
        
        private static async SSHKey? build_ssh_key_model_with_cancellable (File private_path, Cancellable? cancellable) throws KeyMakerError {
            debug ("KeyScanner: Building model for: %s", private_path.get_path ());
            try {
                var public_path = File.new_for_path (private_path.get_path () + ".pub");
                
                // Verify files still exist
                if (!private_path.query_exists () || !public_path.query_exists ()) {
                    debug ("KeyScanner: Key files no longer exist");
                    return null;
                }
                
                if (cancellable != null && cancellable.is_cancelled ()) {
                    throw new IOError.CANCELLED ("Operation was cancelled");
                }
                
                // Quick parse from public key to avoid subprocess on startup
                SSHKeyType key_type_quick = SSHKeyType.RSA;
                string? comment_quick = null;
                int bit_size_quick = -1;
                string fingerprint_quick = "";
                try {
                    uint8[] pub_contents;
                    public_path.load_contents (null, out pub_contents, null);
                    var line = ((string) pub_contents).strip ().split ("\n")[0];
                    var parts = line.split (" ");
                    if (parts.length >= 2) {
                        switch (parts[0]) {
                            case "ssh-rsa": key_type_quick = SSHKeyType.RSA; break;
                            case "ssh-ed25519": key_type_quick = SSHKeyType.ED25519; break;
                            case "ecdsa-sha2-nistp256": key_type_quick = SSHKeyType.ECDSA; break;
                            case "ecdsa-sha2-nistp384": key_type_quick = SSHKeyType.ECDSA; break;
                            case "ecdsa-sha2-nistp521": key_type_quick = SSHKeyType.ECDSA; break;
                            default: key_type_quick = SSHKeyType.RSA; break;
                        }
                        if (parts.length > 2) {
                            comment_quick = string.joinv (" ", parts[2:parts.length]);
                        }
                        if (key_type_quick == SSHKeyType.RSA) {
                            var key_data = parts[1];
                            if (key_data.length > 700) bit_size_quick = 4096;
                            else if (key_data.length > 350) bit_size_quick = 2048;
                            else bit_size_quick = 1024;
                        }
                        var quick_src = line;
                        var quick_hash = Checksum.compute_for_string (ChecksumType.SHA256, quick_src);
                        fingerprint_quick = quick_hash.substring (0, int.min (16, quick_hash.length));
                    }
                } catch (Error e) {
                    debug ("KeyScanner: quick parse failed: %s", e.message);
                }

                // Allow fast scan mode to avoid spawning subprocesses on startup
                bool fast_scan = false;
                var fast_env = Environment.get_variable ("KEYMAKER_FAST_SCAN");
                if (fast_env != null && (fast_env == "1" || fast_env.down () == "true")) {
                    fast_scan = true;
                    debug ("KeyScanner: Fast scan enabled; skipping subprocess refinement");
                }

                // Try to refine with ssh-keygen but do not fail the whole build if it errors
                SSHKeyType key_type = key_type_quick;
                string fingerprint = fingerprint_quick;
                if (!fast_scan) {
                    try {
                        if (cancellable != null && cancellable.is_cancelled ()) {
                            throw new IOError.CANCELLED ("Operation was cancelled");
                        }
                        key_type = yield SSHOperations.get_key_type_with_cancellable (private_path, cancellable);
                        debug ("KeyScanner: Key type: %s", key_type.to_string ());
                    } catch (IOError.CANCELLED e) {
                        throw e;
                    } catch (Error e) {
                        debug ("KeyScanner: Using quick key type fallback: %s", e.message);
                    }

                    if (cancellable != null && cancellable.is_cancelled ()) {
                        throw new IOError.CANCELLED ("Operation was cancelled");
                    }

                    try {
                        fingerprint = yield SSHOperations.get_fingerprint_with_cancellable (private_path, cancellable);
                    } catch (IOError.CANCELLED e) {
                        throw e;
                    } catch (Error e) {
                        debug ("KeyScanner: Using quick fingerprint fallback: %s", e.message);
                    }
                }
                
                debug ("KeyScanner: Getting file info...");
                // Get last modified time
                FileInfo file_info;
                try {
                    file_info = private_path.query_info (FileAttribute.TIME_MODIFIED, FileQueryInfoFlags.NONE);
                } catch (Error e) {
                    debug ("KeyScanner: Failed to get file info: %s", e.message);
                    return null;
                }
                var timestamp = file_info.get_attribute_uint64 (FileAttribute.TIME_MODIFIED);
                var last_modified = new DateTime.from_unix_local ((int64) timestamp);
                
                debug ("KeyScanner: Extracting comment...");
                // Extract comment from public key
                var comment = extract_comment_from_public_key (public_path);
                
                debug ("KeyScanner: Getting bit size...");
                // Extract bit size for RSA keys
                int? bit_size = null;
                if (key_type == SSHKeyType.RSA && bit_size_quick > 0) {
                    bit_size = bit_size_quick;
                }
                if (!fast_scan && bit_size == null && key_type == SSHKeyType.RSA) {
                    try {
                        bit_size = yield SSHOperations.extract_bit_size_with_cancellable (private_path, cancellable);
                    } catch (GLib.IOError.CANCELLED e) {
                        throw e;
                    } catch (Error e) {
                        debug ("KeyScanner: Failed to get bit size: %s", e.message);
                        // Continue without bit size
                    }
                }
                
                // Ensure non-null bit size for constructor (-1 for non-RSA or unknown)
                int bit_size_final = bit_size ?? -1;
                debug ("KeyScanner: Creating SSHKey object...");
                return new SSHKey (
                    private_path,
                    public_path,
                    key_type,
                    fingerprint,
                    comment ?? comment_quick,
                    last_modified,
                    bit_size_final
                );
                
            } catch (KeyMakerError e) {
                debug ("KeyScanner: KeyMakerError building model: %s", e.message);
                throw e;
            } catch (Error e) {
                // Return null for invalid keys
                debug ("KeyScanner: Error building SSH key model for %s: %s", private_path.get_path (), e.message);
                return null;
            }
        }
        
        /**
         * Extract comment from public key file
         */
        private static string? extract_comment_from_public_key (File public_path) {
            try {
                uint8[] contents;
                public_path.load_contents (null, out contents, null);
                var content = ((string) contents).strip ();
                
                // Public key format: "type key-data comment"
                var parts = content.split (" ");
                if (parts.length >= 3) {
                    // Everything after the key data is the comment
                    var comment_parts = new GenericArray<string> ();
                    for (int i = 2; i < parts.length; i++) {
                        comment_parts.add (parts[i]);
                    }
                    return string.joinv (" ", comment_parts.data);
                }
                
                return null;
                
            } catch (Error e) {
                debug ("Failed to extract comment from %s: %s", public_path.get_path (), e.message);
                return null;
            }
        }
        
        /**
         * Refresh metadata for an existing SSH key
         */
        public static async SSHKey refresh_ssh_key_metadata (SSHKey ssh_key) throws KeyMakerError {
            if (!ssh_key.private_path.query_exists ()) {
                throw new KeyMakerError.KEY_NOT_FOUND ("Private key no longer exists: %s", ssh_key.private_path.get_path ());
            }
            
            if (!ssh_key.public_path.query_exists ()) {
                throw new KeyMakerError.KEY_NOT_FOUND ("Public key no longer exists: %s", ssh_key.public_path.get_path ());
            }
            
            try {
                // Get updated metadata
                var fingerprint = yield SSHOperations.get_fingerprint (ssh_key.private_path);
                
                var file_info = ssh_key.private_path.query_info (FileAttribute.TIME_MODIFIED, FileQueryInfoFlags.NONE);
                var timestamp = file_info.get_attribute_uint64 (FileAttribute.TIME_MODIFIED);
                var last_modified = new DateTime.from_unix_local ((int64) timestamp);
                
                var comment = extract_comment_from_public_key (ssh_key.public_path);
                
                // Update bit size for RSA keys
                int? bit_size = ssh_key.bit_size;
                if (ssh_key.key_type == SSHKeyType.RSA) {
                    bit_size = yield SSHOperations.extract_bit_size (ssh_key.private_path);
                }
                
                return new SSHKey (
                    ssh_key.private_path,
                    ssh_key.public_path,
                    ssh_key.key_type,
                    fingerprint,
                    comment,
                    last_modified,
                    bit_size
                );
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to refresh key metadata: %s", e.message);
            }
        }
        
        /**
         * Check if a file is likely an SSH key file
         */
        public static bool is_ssh_key_file (File file_path) {
            try {
                var file_info = file_path.query_info (FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE);
                if (file_info == null || file_info.get_file_type () != FileType.REGULAR) {
                    return false;
                }
            } catch (GLib.Error e) {
                return false;
            }
            
            var filename = file_path.get_basename ();
            
            // Skip known non-key files
            if (filename in new string[] {"config", "known_hosts", "authorized_keys"}) {
                return false;
            }
            
            // Skip .pub files (we look for private keys)
            if (filename.has_suffix (".pub")) {
                return false;
            }
            
            // Check if corresponding public key exists
            var public_path = File.new_for_path (file_path.get_path () + ".pub");
            if (!public_path.query_exists ()) {
                return false;
            }
            
            // Basic content check for SSH private key
            try {
                uint8[] contents;
                file_path.load_contents (null, out contents, null);
                var content = (string) contents;
                if ("-----BEGIN" in content && "PRIVATE KEY-----" in content) {
                    return true;
                }
            } catch (Error e) {
                // Ignore errors and return false
            }
            
            return false;
        }
    }
}
