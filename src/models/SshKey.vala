/*
 * SSHer - SSH Key Data Models
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {
    
    /**
     * Model representing an SSH key pair
     * 
     * This model represents both private and public keys as a pair,
     * with validation to ensure secure permissions and proper structure.
     */
    public class SSHKey : Object {
        public File private_path { get; construct; }
        public File public_path { get; construct; }
        public SSHKeyType key_type { get; construct; }
        public string fingerprint { get; construct; }
        public string? comment { get; construct; }
        public DateTime last_modified { get; construct; }
        public int bit_size { get; construct; } // Only for RSA keys, -1 for non-RSA
        
        public SSHKey (File private_path, File public_path, SSHKeyType key_type,
                      string fingerprint, string? comment, DateTime last_modified, int bit_size = -1) {
            Object (
                private_path: private_path,
                public_path: public_path,
                key_type: key_type,
                fingerprint: fingerprint,
                comment: comment,
                last_modified: last_modified,
                bit_size: bit_size
            );
        }
        
        construct {
            debug ("SSHKey: construct start for %s", private_path.get_path ());
            validate_permissions ();
            debug ("SSHKey: construct done for %s", private_path.get_path ());
        }
        
        /**
         * Validate that private key has secure permissions
         */
        private void validate_permissions () {
            debug ("SSHKey: validating permissions for %s", private_path.get_path ());
            try {
                var file_info = private_path.query_info (FileAttribute.UNIX_MODE, FileQueryInfoFlags.NONE);
                var mode = file_info.get_attribute_uint32 (FileAttribute.UNIX_MODE);
                var permissions = mode & 0x1FF; // Last 9 bits (permissions)
                
                // Check if permissions are not 0600 (owner read/write only)
                if (permissions != KeyMaker.Filesystem.PERM_FILE_PRIVATE) {
                    warning ("Private key %s does not have secure permissions (should be 0600)", 
                            private_path.get_path ());
                }
            } catch (Error e) {
                warning ("Failed to check permissions for %s: %s", private_path.get_path (), e.message);
            }
        }
        
        /**
         * Get the display name for this key (filename without path)
         */
        public string get_display_name () {
            return private_path.get_basename ();
        }
        
        /**
         * Get a human-readable description of the key type and size
         */
        public string get_type_description () {
            var type_str = key_type.to_string ().up ();
            if (bit_size > 0) {
                switch (key_type) {
                    case SSHKeyType.RSA:
                        return "%s %d".printf (type_str, bit_size);
                    case SSHKeyType.ECDSA:
                        return "%s P-%d".printf (type_str, bit_size);
                    default:
                        break;
                }
            }
            return type_str;
        }
        
        /**
         * Check if both key files still exist
         */
        public bool exists () {
            return private_path.query_exists () && public_path.query_exists ();
        }
    }
    
    /**
     * Request model for generating new SSH keys
     * 
     * This model validates all parameters needed for key generation,
     * including type-specific constraints and security requirements.
     */
    public class KeyGenerationRequest : Object {
        public SSHKeyType key_type { get; set; default = SSHKeyType.ED25519; }
        public string filename { get; set; }
        public string? passphrase { get; set; default = null; }
        public string? comment { get; set; default = null; }
        public int rsa_bits { get; set; default = 4096; }
        public int ecdsa_curve { get; set; default = 256; } // 256, 384, or 521
        
        // Computed property that returns the appropriate size for the key type
        public int key_size { 
            get {
                switch (key_type) {
                    case SSHKeyType.RSA:
                        return rsa_bits;
                    case SSHKeyType.ECDSA:
                        return ecdsa_curve;
                    case SSHKeyType.ED25519:
                        return 256; // Ed25519 is always 256-bit equivalent
                    default:
                        return rsa_bits;
                }
            }
        }
        
        public KeyGenerationRequest (string filename) {
            Object (filename: filename);
        }
        
        /**
         * Validate the request parameters
         */
        public void validate () throws KeyMakerError {
            // Validate filename
            if (filename == null || filename.strip () == "") {
                throw new KeyMakerError.VALIDATION_FAILED ("Filename cannot be empty");
            }
            
            // Check for safe filename characters
            if (!is_safe_filename (filename)) {
                throw new KeyMakerError.VALIDATION_FAILED (
                    "Filename contains invalid characters. Use only letters, numbers, dots, hyphens, and underscores"
                );
            }
            
            // Filename cannot start with . or -
            if (filename.has_prefix (".") || filename.has_prefix ("-")) {
                throw new KeyMakerError.VALIDATION_FAILED ("Filename cannot start with '.' or '-'");
            }
            
            // Check filename length
            if (filename.length > 255) {
                throw new KeyMakerError.VALIDATION_FAILED ("Filename too long (maximum 255 characters)");
            }
            
            // Validate RSA bits if RSA key
            if (key_type == SSHKeyType.RSA) {
                if (rsa_bits < 2048 || rsa_bits > 8192) {
                    throw new KeyMakerError.VALIDATION_FAILED ("RSA key size must be between 2048 and 8192 bits");
                }
            }
            
            // Validate ECDSA curve if ECDSA key
            if (key_type == SSHKeyType.ECDSA) {
                if (ecdsa_curve != 256 && ecdsa_curve != 384 && ecdsa_curve != 521) {
                    throw new KeyMakerError.VALIDATION_FAILED ("ECDSA curve must be 256, 384, or 521 bits");
                }
            }
        }
        
        private bool is_safe_filename (string name) {
            // Allow only alphanumeric, dots, hyphens, and underscores
            for (int i = 0; i < name.length; i++) {
                unichar c = name.get_char (i);
                if (!c.isalnum () && c != '.' && c != '-' && c != '_') {
                    return false;
                }
            }
            return true;
        }
        
        /**
         * Get the full path where the key will be created
         */
        public File get_key_path () {
            return KeyMaker.Filesystem.ssh_dir ().get_child (filename);
        }
    }
    
    /**
     * Request model for deleting SSH key pairs
     */
    public class KeyDeletionRequest : Object {
        public SSHKey ssh_key { get; construct; }
        public bool confirm { get; set; default = false; }
        
        public KeyDeletionRequest (SSHKey ssh_key) {
            Object (ssh_key: ssh_key);
        }
        
        public void validate () throws KeyMakerError {
            if (!confirm) {
                throw new KeyMakerError.VALIDATION_FAILED ("Deletion must be confirmed");
            }
        }
    }
    
    /**
     * Request model for changing SSH key passphrases
     */
    public class PassphraseChangeRequest : Object {
        public SSHKey ssh_key { get; construct; }
        public string? current_passphrase { get; set; default = null; }
        public string? new_passphrase { get; set; default = null; }
        // Compatibility aliases
        public string key_path { owned get { return ssh_key.private_path.get_path(); } }
        public string? old_passphrase { get { return current_passphrase; } set { current_passphrase = value; } }
        public string? passphrase { get { return new_passphrase; } set { new_passphrase = value; } }
        
        public PassphraseChangeRequest (SSHKey ssh_key) {
            Object (ssh_key: ssh_key);
        }
    }
    
    /**
     * Request model for generating ssh-copy-id commands
     */
    public class SSHCopyIDRequest : Object {
        public SSHKey ssh_key { get; construct; }
        public string hostname { get; set; }
        public string username { get; set; }
        public int port { get; set; default = 22; }
        
        public SSHCopyIDRequest (SSHKey ssh_key, string hostname, string username) {
            Object (
                ssh_key: ssh_key,
                hostname: hostname,
                username: username
            );
        }
        
        public void validate () throws KeyMakerError {
            if (hostname == null || hostname.strip () == "") {
                throw new KeyMakerError.VALIDATION_FAILED ("Hostname cannot be empty");
            }
            
            if (username == null || username.strip () == "") {
                throw new KeyMakerError.VALIDATION_FAILED ("Username cannot be empty");
            }
            
            if (port < 1 || port > 65535) {
                throw new KeyMakerError.VALIDATION_FAILED ("Port must be between 1 and 65535");
            }
        }
        
        /**
         * Generate the ssh-copy-id command string
         */
        public string get_command () {
            var cmd = new StringBuilder ();
            cmd.append ("ssh-copy-id -i ");
            cmd.append (Shell.quote (ssh_key.public_path.get_path ()));
            
            if (port != 22) {
                cmd.append_printf (" -p %d", port);
            }
            
            cmd.append_printf (" %s@%s", Shell.quote (username), Shell.quote (hostname));
            
            return cmd.str;
        }
    }
}
