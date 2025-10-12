/*
 * Key Maker - TOTP (Time-based One-Time Password) Manager
 * 
 * Handles TOTP generation, validation, and multi-person authentication
 * for emergency backup systems.
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

using Gee;

namespace KeyMaker {
    
    public class TOTPManager : GLib.Object {
        private const int DEFAULT_PERIOD = 30; // 30 seconds
        private const int DEFAULT_DIGITS = 6;  // 6 digit codes
        private const int WINDOW_SIZE = 1;      // Allow 1 step before/after current time
        
        private Settings settings;
        
        construct {
            settings = new Settings (Config.APP_ID);
        }
        
        /**
         * Generate a new TOTP secret for a backup
         */
        public string generate_secret () {
            // Generate a random 160-bit (20-byte) secret
            var secret_bytes = new uint8[20];
            for (int i = 0; i < 20; i++) {
                secret_bytes[i] = (uint8) Random.int_range (0, 256);
            }
            
            // Encode as Base32 (RFC 4648)
            return base32_encode (secret_bytes);
        }
        
        /**
         * Generate TOTP code for given secret at current time
         */
        public string generate_totp_code (string secret) throws KeyMakerError {
            return generate_totp_code_at_time (secret, new DateTime.now_utc ());
        }
        
        /**
         * Generate TOTP code for given secret at specific time
         */
        public string generate_totp_code_at_time (string secret, DateTime time) throws KeyMakerError {
            try {
                var secret_bytes = base32_decode (secret);
                var time_step = time.to_unix () / DEFAULT_PERIOD;
                
                return generate_hotp_code (secret_bytes, time_step);
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to generate TOTP code: %s", e.message);
            }
        }
        
        /**
         * Validate TOTP code against secret
         */
        public bool validate_totp_code (string secret, string code) {
            return validate_totp_code_at_time (secret, code, new DateTime.now_utc ());
        }
        
        /**
         * Validate TOTP code against secret at specific time
         */
        public bool validate_totp_code_at_time (string secret, string code, DateTime time) {
            try {
                var secret_bytes = base32_decode (secret);
                var time_step = time.to_unix () / DEFAULT_PERIOD;
                
                // Check current time step and nearby steps (to handle clock skew)
                for (int i = -WINDOW_SIZE; i <= WINDOW_SIZE; i++) {
                    var test_step = time_step + i;
                    var expected_code = generate_hotp_code (secret_bytes, test_step);
                    
                    if (secure_string_compare (code, expected_code)) {
                        return true;
                    }
                }
                
                return false;
                
            } catch (Error e) {
                warning ("TOTP validation failed: %s", e.message);
                return false;
            }
        }
        
        /**
         * Generate QR code data for TOTP setup
         */
        public string generate_qr_code_data (string secret, string account_name, string issuer = "KeyMaker") {
            var encoded_account = Uri.escape_string (account_name, "", true);
            var encoded_issuer = Uri.escape_string (issuer, "", true);
            
            return @"otpauth://totp/$(encoded_issuer):$(encoded_account)?secret=$(secret)&issuer=$(encoded_issuer)&digits=$(DEFAULT_DIGITS)&period=$(DEFAULT_PERIOD)";
        }
        
        /**
         * Create TOTP setup information for multiple users
         */
        public GenericArray<TOTPSetup> create_multi_user_setup (GenericArray<string> contact_names, string backup_name) throws KeyMakerError {
            var setups = new GenericArray<TOTPSetup> ();
            
            for (int i = 0; i < contact_names.length; i++) {
                var contact = contact_names[i];
                var secret = generate_secret ();
                var account_name = @"$(backup_name) - $(contact)";
                
                var setup = new TOTPSetup ();
                setup.contact_name = contact;
                setup.secret = secret;
                setup.account_name = account_name;
                setup.qr_code_data = generate_qr_code_data (secret, account_name);
                setup.manual_entry_key = format_secret_for_manual_entry (secret);
                
                setups.add (setup);
            }
            
            return setups;
        }
        
        /**
         * Validate multiple TOTP codes (M-of-N authentication)
         */
        public bool validate_multiple_codes (GenericArray<string> secrets, GenericArray<string> provided_codes, int required_count) {
            if (provided_codes.length < required_count) {
                return false;
            }
            
            var valid_count = 0;
            var used_secrets = new GenericSet<string> (str_hash, str_equal);
            
            // Check each provided code against all unused secrets
            for (int i = 0; i < provided_codes.length; i++) {
                var code = provided_codes[i];
                
                for (int j = 0; j < secrets.length; j++) {
                    var secret = secrets[j];
                    
                    // Skip if this secret was already used successfully
                    if (used_secrets.contains (secret)) {
                        continue;
                    }
                    
                    if (validate_totp_code (secret, code)) {
                        used_secrets.add (secret);
                        valid_count++;
                        break; // Move to next code
                    }
                }
            }
            
            return valid_count >= required_count;
        }
        
        /**
         * Generate recovery codes (one-time use codes for emergency access)
         */
        public GenericArray<string> generate_recovery_codes (int count = 10) {
            var codes = new GenericArray<string> ();
            
            for (int i = 0; i < count; i++) {
                // Generate 8-character alphanumeric recovery code
                var code = new StringBuilder ();
                for (int j = 0; j < 8; j++) {
                    var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
                    var random_index = Random.int_range (0, chars.length);
                    code.append_c (chars[random_index]);
                }
                codes.add (code.str);
            }
            
            return codes;
        }
        
        /**
         * Validate recovery code and mark as used
         */
        public bool validate_and_use_recovery_code (string code, ref GenericArray<string> unused_codes) {
            for (int i = 0; i < unused_codes.length; i++) {
                if (secure_string_compare (code.up (), unused_codes[i])) {
                    unused_codes.remove_index (i);
                    return true;
                }
            }
            return false;
        }
        
        /**
         * Create backup authentication bundle
         */
        public TOTPBackupBundle create_backup_bundle (string backup_name, GenericArray<string> contact_names, int required_codes) throws KeyMakerError {
            var bundle = new TOTPBackupBundle ();
            bundle.backup_name = backup_name;
            bundle.required_codes = required_codes;
            bundle.created_at = new DateTime.now_local ();
            
            // Generate TOTP setups for each contact
            bundle.totp_setups = create_multi_user_setup (contact_names, backup_name);
            
            // Extract secrets for validation
            bundle.secrets = new GenericArray<string> ();
            for (int i = 0; i < bundle.totp_setups.length; i++) {
                bundle.secrets.add (bundle.totp_setups[i].secret);
            }
            
            // Generate recovery codes
            bundle.recovery_codes = generate_recovery_codes ();
            
            return bundle;
        }
        
        /**
         * Validate access attempt using TOTP bundle
         */
        public TOTPValidationResult validate_backup_access (TOTPBackupBundle bundle, GenericArray<string> provided_codes) {
            var result = new TOTPValidationResult ();
            result.success = false;
            result.used_recovery_code = false;
            
            // First check if any codes are recovery codes
            var temp_recovery_codes = new GenericArray<string> ();
            for (int i = 0; i < bundle.recovery_codes.length; i++) {
                temp_recovery_codes.add (bundle.recovery_codes[i]);
            }
            
            for (int i = 0; i < provided_codes.length; i++) {
                if (validate_and_use_recovery_code (provided_codes[i], ref temp_recovery_codes)) {
                    result.success = true;
                    result.used_recovery_code = true;
                    result.method_used = "Recovery Code";
                    
                    // Update bundle's recovery codes
                    bundle.recovery_codes = temp_recovery_codes;
                    return result;
                }
            }
            
            // If no recovery codes, validate TOTP codes
            if (validate_multiple_codes (bundle.secrets, provided_codes, bundle.required_codes)) {
                result.success = true;
                result.used_recovery_code = false;
                result.method_used = @"TOTP ($(provided_codes.length) of $(bundle.secrets.length) codes)";
                
                // Update last access time
                bundle.last_access = new DateTime.now_local ();
            }
            
            return result;
        }
        
        // Private helper methods
        
        private string generate_hotp_code (uint8[] secret, int64 counter) throws Error {
            // HOTP algorithm implementation (RFC 4226)
            var counter_bytes = new uint8[8];
            for (int i = 7; i >= 0; i--) {
                counter_bytes[i] = (uint8) (counter & 0xff);
                counter = counter >> 8;
            }
            
            // HMAC-SHA1
            var hmac = new Hmac (ChecksumType.SHA1, secret);
            hmac.update (counter_bytes);
            
            var hash = new uint8[20]; // SHA1 produces 20 bytes
            size_t hash_length = 20;
            hmac.get_digest (hash, ref hash_length);
            
            // Dynamic truncation
            var offset = hash[19] & 0x0f;
            var code = ((hash[offset] & 0x7f) << 24) |
                      ((hash[offset + 1] & 0xff) << 16) |
                      ((hash[offset + 2] & 0xff) << 8) |
                      (hash[offset + 3] & 0xff);
            
            // Generate requested number of digits
            var divisor = 1;
            for (int i = 0; i < DEFAULT_DIGITS; i++) {
                divisor *= 10;
            }
            
            code = code % divisor;
            
            return @"$(code)".printf (@"%0$(DEFAULT_DIGITS)d");
        }
        
        private string base32_encode (uint8[] data) {
            const string BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
            var result = new StringBuilder ();
            
            int buffer = 0;
            int buffer_size = 0;
            
            for (int i = 0; i < data.length; i++) {
                buffer = (buffer << 8) | data[i];
                buffer_size += 8;
                
                while (buffer_size >= 5) {
                    var index = (buffer >> (buffer_size - 5)) & 0x1F;
                    result.append_c (BASE32_ALPHABET[index]);
                    buffer_size -= 5;
                }
            }
            
            if (buffer_size > 0) {
                var index = (buffer << (5 - buffer_size)) & 0x1F;
                result.append_c (BASE32_ALPHABET[index]);
            }
            
            // Add padding
            while (result.len % 8 != 0) {
                result.append_c ('=');
            }
            
            return result.str;
        }
        
        private uint8[] base32_decode (string data) throws Error {
            const string BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
            var clean_data = data.replace ("=", "").up ();
            var result = new ByteArray ();
            
            int buffer = 0;
            int buffer_size = 0;
            
            for (int i = 0; i < clean_data.length; i++) {
                var c = clean_data[i];
                var index = BASE32_ALPHABET.index_of_char (c);
                
                if (index == -1) {
                    throw new Error (Quark.from_string ("TOTP"), 0, "Invalid Base32 character: %c", c);
                }
                
                buffer = (buffer << 5) | index;
                buffer_size += 5;
                
                if (buffer_size >= 8) {
                    result.append (new uint8[] { (uint8) (buffer >> (buffer_size - 8)) });
                    buffer_size -= 8;
                }
            }
            
            return result.data;
        }
        
        private string format_secret_for_manual_entry (string secret) {
            // Format as groups of 4 characters for easier manual entry
            var result = new StringBuilder ();
            for (int i = 0; i < secret.length; i += 4) {
                if (i > 0) result.append (" ");
                var end = int.min (i + 4, secret.length);
                result.append (secret.substring (i, end - i));
            }
            return result.str;
        }
        
        private bool secure_string_compare (string a, string b) {
            // Constant-time string comparison to prevent timing attacks
            if (a.length != b.length) {
                return false;
            }
            
            int result = 0;
            for (int i = 0; i < a.length; i++) {
                result |= a[i] ^ b[i];
            }
            
            return result == 0;
        }
    }
    
    /**
     * TOTP setup information for individual users
     */
    public class TOTPSetup : GLib.Object {
        public string contact_name { get; set; }
        public string secret { get; set; }
        public string account_name { get; set; }
        public string qr_code_data { get; set; }
        public string manual_entry_key { get; set; }
    }
    
    /**
     * Complete TOTP authentication bundle for a backup
     */
    public class TOTPBackupBundle : GLib.Object {
        public string backup_name { get; set; }
        public int required_codes { get; set; }
        public DateTime created_at { get; set; }
        public DateTime? last_access { get; set; }
        
        public GenericArray<TOTPSetup> totp_setups { get; set; }
        public GenericArray<string> secrets { get; set; }
        public GenericArray<string> recovery_codes { get; set; }
        
        construct {
            totp_setups = new GenericArray<TOTPSetup> ();
            secrets = new GenericArray<string> ();
            recovery_codes = new GenericArray<string> ();
        }
        
        public string get_setup_summary () {
            return @"$(totp_setups.length) contacts, $(required_codes) codes required";
        }
        
        public int get_remaining_recovery_codes () {
            return (int) recovery_codes.length;
        }
    }
    
    /**
     * Result of TOTP validation attempt
     */
    public class TOTPValidationResult : GLib.Object {
        public bool success { get; set; }
        public bool used_recovery_code { get; set; }
        public string method_used { get; set; }
        public string? error_message { get; set; }
    }
}