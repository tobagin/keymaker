/*
 * Key Maker - Backup Entry Data Models
 *
 * Data structures for backup entries and Shamir shares.
 */

namespace KeyMaker {
    
    public enum RegularBackupType {
        ENCRYPTED_ARCHIVE,
        EXPORT_BUNDLE,
        CLOUD_SYNC;
        
        public string to_string () {
            switch (this) {
                case ENCRYPTED_ARCHIVE: return "Encrypted Archive";
                case EXPORT_BUNDLE: return "Export Bundle";
                case CLOUD_SYNC: return "Cloud Sync";
                default: return "Unknown";
            }
        }
        
        public string get_description () {
            switch (this) {
                case ENCRYPTED_ARCHIVE: return "Password-protected backup for secure storage";
                case EXPORT_BUNDLE: return "Plain export for migration and sharing";
                case CLOUD_SYNC: return "Encrypted backup synced to cloud storage";
                default: return "";
            }
        }
        
        public string get_icon_name () {
            switch (this) {
                case ENCRYPTED_ARCHIVE: return "package-x-generic-symbolic";
                case EXPORT_BUNDLE: return "folder-download-symbolic";
                case CLOUD_SYNC: return "cloud-symbolic";
                default: return "folder-symbolic";
            }
        }
    }
    
    public enum EmergencyBackupType {
        ENCRYPTED_ARCHIVE,
        TIME_LOCKED,
        SHAMIR_SECRET_SHARING,
        QR_CODE,
        TOTP_PROTECTED,
        MULTI_FACTOR;
        
        public string to_string () {
            switch (this) {
                case ENCRYPTED_ARCHIVE: return "Encrypted Archive";
                case TIME_LOCKED: return "Time-Locked";
                case SHAMIR_SECRET_SHARING: return "Secret Sharing";
                case QR_CODE: return "QR Emergency Cards";
                case TOTP_PROTECTED: return "TOTP Protected";
                case MULTI_FACTOR: return "Multi-Factor Recovery";
                default: return "Unknown";
            }
        }
        
        public string get_description () {
            switch (this) {
                case ENCRYPTED_ARCHIVE: return "Password-protected emergency backup";
                case TIME_LOCKED: return "Unlocks automatically at specified future date";
                case SHAMIR_SECRET_SHARING: return "Requires multiple shares to reconstruct keys";
                case QR_CODE: return "Physical QR cards for offline recovery";
                case TOTP_PROTECTED: return "Protected by time-based one-time passwords";
                case MULTI_FACTOR: return "Combines multiple authentication methods";
                default: return "";
            }
        }
        
        public string get_icon_name () {
            switch (this) {
                case ENCRYPTED_ARCHIVE: return "package-x-generic-symbolic";
                case TIME_LOCKED: return "io.github.tobagin.keysmith-time-locked-symbolic";
                case SHAMIR_SECRET_SHARING: return "view-app-grid-symbolic";
                case QR_CODE: return "io.github.tobagin.keysmith-qr-code-symbolic";
                case TOTP_PROTECTED: return "io.github.tobagin.keysmith-otp-symbolic";
                case MULTI_FACTOR: return "security-high-symbolic";
                default: return "help-about-symbolic";
            }
        }
    }
    
    // Legacy enum for backward compatibility during migration
    public enum BackupType {
        ENCRYPTED_ARCHIVE,
        QR_CODE,
        SHAMIR_SECRET_SHARING,
        TIME_LOCKED;
        
        public string to_string () {
            switch (this) {
                case ENCRYPTED_ARCHIVE: return "Encrypted Archive";
                case QR_CODE: return "QR Code";
                case SHAMIR_SECRET_SHARING: return "Secret Sharing";
                case TIME_LOCKED: return "Time-Locked";
                default: return "Unknown";
            }
        }
        
        // Convert legacy backup type to appropriate new type
        public RegularBackupType? to_regular_backup_type () {
            switch (this) {
                case ENCRYPTED_ARCHIVE: return RegularBackupType.ENCRYPTED_ARCHIVE;
                default: return null; // Other types go to emergency vault
            }
        }
        
        public EmergencyBackupType? to_emergency_backup_type () {
            switch (this) {
                case QR_CODE: return EmergencyBackupType.QR_CODE;
                case SHAMIR_SECRET_SHARING: return EmergencyBackupType.SHAMIR_SECRET_SHARING;
                case TIME_LOCKED: return EmergencyBackupType.TIME_LOCKED;
                default: return null; // ENCRYPTED_ARCHIVE goes to regular backups
            }
        }
    }
    
    public enum VaultStatus {
        HEALTHY,
        WARNING,
        CRITICAL,
        CORRUPTED;
        
        public string to_string () {
            switch (this) {
                case HEALTHY: return "Healthy";
                case WARNING: return "Warning";
                case CRITICAL: return "Critical";
                case CORRUPTED: return "Corrupted";
                default: return "Unknown";
            }
        }
        
        public string get_icon_name () {
            switch (this) {
                case HEALTHY: return "emblem-ok-symbolic";
                case WARNING: return "dialog-warning-symbolic";
                case CRITICAL: return "dialog-error-symbolic";
                case CORRUPTED: return "emblem-unreadable-symbolic";
                default: return "help-about-symbolic";
            }
        }
    }
    
    public class BackupEntry : GLib.Object {
        public string id { get; set; }
        public string name { get; set; }
        public BackupType backup_type { get; set; }
        public DateTime created_at { get; set; }
        public DateTime? expires_at { get; set; }
        public File backup_file { get; set; }
        public GenericArray<string> key_fingerprints { get; set; }
        public bool is_encrypted { get; set; default = true; }
        public string? description { get; set; }
        public int64 file_size { get; set; }
        public string checksum { get; set; default = ""; }
        
        // Shamir's Secret Sharing fields
        public int shamir_total_shares { get; set; default = 0; }
        public int shamir_threshold { get; set; default = 0; }
        
        construct {
            key_fingerprints = new GenericArray<string> ();
            created_at = new DateTime.now_local ();
        }
        
        public BackupEntry (string backup_name, BackupType type) {
            id = generate_backup_id ();
            name = backup_name;
            backup_type = type;
        }
        
        private string generate_backup_id () {
            var timestamp = new DateTime.now_local ().format ("%Y%m%d_%H%M%S");
            var random = Random.int_range (1000, 9999);
            return @"backup_$(timestamp)_$(random)";
        }
        
        public bool is_expired () {
            if (expires_at == null) return false;
            return new DateTime.now_local ().compare (expires_at) > 0;
        }
        
        public string get_display_size () {
            if (file_size < 1024) {
                return @"$(file_size) B";
            } else if (file_size < 1024 * 1024) {
                return @"$(file_size / 1024) KB";
            } else {
                return @"$(file_size / (1024 * 1024)) MB";
            }
        }
    }
    
    /**
     * Regular backup entry for day-to-day operations
     */
    public class RegularBackupEntry : GLib.Object {
        public string id { get; set; }
        public string name { get; set; }
        public RegularBackupType backup_type { get; set; }
        public DateTime created_at { get; set; }
        public DateTime? expires_at { get; set; }
        public File backup_file { get; set; }
        public GenericArray<string> key_fingerprints { get; set; }
        public bool is_encrypted { get; set; default = true; }
        public string? description { get; set; }
        public int64 file_size { get; set; }
        public string checksum { get; set; default = ""; }
        
        // Cloud sync specific fields
        public string? cloud_provider { get; set; }
        public string? cloud_backup_id { get; set; }
        public DateTime? last_synced { get; set; }
        
        construct {
            key_fingerprints = new GenericArray<string> ();
            created_at = new DateTime.now_local ();
        }
        
        public RegularBackupEntry (string backup_name, RegularBackupType type) {
            id = generate_backup_id ("regular");
            name = backup_name;
            backup_type = type;
        }
        
        private string generate_backup_id (string prefix) {
            var timestamp = new DateTime.now_local ().format ("%Y%m%d_%H%M%S");
            var random = Random.int_range (1000, 9999);
            return @"$(prefix)_$(timestamp)_$(random)";
        }
        
        public bool is_expired () {
            if (expires_at == null) return false;
            return new DateTime.now_local ().compare (expires_at) > 0;
        }
        
        public string get_display_size () {
            if (file_size < 1024) {
                return @"$(file_size) B";
            } else if (file_size < 1024 * 1024) {
                return @"$(file_size / 1024) KB";
            } else {
                return @"$(file_size / (1024 * 1024)) MB";
            }
        }
        
        public string get_type_description () {
            return backup_type.get_description ();
        }
        
        public string get_type_icon () {
            return backup_type.get_icon_name ();
        }
    }
    
    /**
     * Emergency backup entry for disaster recovery and business continuity
     */
    public class EmergencyBackupEntry : GLib.Object {
        public string id { get; set; }
        public string name { get; set; }
        public EmergencyBackupType backup_type { get; set; }
        public DateTime created_at { get; set; }
        public DateTime? expires_at { get; set; }
        public File backup_file { get; set; }
        public GenericArray<string> key_fingerprints { get; set; }
        public bool is_encrypted { get; set; default = true; }
        public string? description { get; set; }
        public int64 file_size { get; set; }
        public string checksum { get; set; default = ""; }
        
        // Shamir's Secret Sharing fields
        public int shamir_total_shares { get; set; default = 0; }
        public int shamir_threshold { get; set; default = 0; }
        
        // TOTP fields
        public GenericArray<string> totp_secrets { get; set; default = new GenericArray<string> (); }
        public int totp_required_count { get; set; default = 1; } // How many TOTP codes needed
        public GenericArray<string> authorized_contacts { get; set; default = new GenericArray<string> (); }
        
        // Multi-factor fields
        public bool requires_password { get; set; default = false; }
        public bool requires_biometric { get; set; default = false; }
        public bool requires_hardware_key { get; set; default = false; }
        
        // Access control
        public DateTime? last_access_attempt { get; set; }
        public int failed_access_attempts { get; set; default = 0; }
        public bool is_locked_out { get; set; default = false; }
        public DateTime? lockout_expires { get; set; }
        
        construct {
            key_fingerprints = new GenericArray<string> ();
            totp_secrets = new GenericArray<string> ();
            authorized_contacts = new GenericArray<string> ();
            created_at = new DateTime.now_local ();
        }
        
        public EmergencyBackupEntry (string backup_name, EmergencyBackupType type) {
            id = generate_backup_id ("emergency");
            name = backup_name;
            backup_type = type;
        }
        
        private string generate_backup_id (string prefix) {
            var timestamp = new DateTime.now_local ().format ("%Y%m%d_%H%M%S");
            var random = Random.int_range (1000, 9999);
            return @"$(prefix)_$(timestamp)_$(random)";
        }
        
        public bool is_expired () {
            if (expires_at == null) return false;
            return new DateTime.now_local ().compare (expires_at) > 0;
        }
        
        public bool is_time_locked () {
            return backup_type == EmergencyBackupType.TIME_LOCKED && !is_expired ();
        }
        
        public bool is_accessible () {
            if (is_locked_out && lockout_expires != null) {
                var now = new DateTime.now_local ();
                if (now.compare (lockout_expires) < 0) {
                    return false; // Still locked out
                } else {
                    // Lockout expired, reset
                    is_locked_out = false;
                    failed_access_attempts = 0;
                    lockout_expires = null;
                }
            }
            
            return !is_time_locked () && !is_locked_out;
        }
        
        public void record_access_attempt (bool successful) {
            last_access_attempt = new DateTime.now_local ();
            
            if (successful) {
                failed_access_attempts = 0;
                is_locked_out = false;
                lockout_expires = null;
            } else {
                failed_access_attempts++;
                
                // Lock out after 3 failed attempts for 1 hour
                if (failed_access_attempts >= 3) {
                    is_locked_out = true;
                    lockout_expires = new DateTime.now_local ().add_hours (1);
                }
            }
        }
        
        public string get_display_size () {
            if (file_size < 1024) {
                return @"$(file_size) B";
            } else if (file_size < 1024 * 1024) {
                return @"$(file_size / 1024) KB";
            } else {
                return @"$(file_size / (1024 * 1024)) MB";
            }
        }
        
        public string get_type_description () {
            return backup_type.get_description ();
        }
        
        public string get_type_icon () {
            return backup_type.get_icon_name ();
        }
        
        public string get_access_status () {
            if (is_time_locked ()) {
                return @"Time-locked until $(expires_at.format ("%Y-%m-%d %H:%M"))";
            }
            
            if (is_locked_out && lockout_expires != null) {
                return @"Locked out until $(lockout_expires.format ("%Y-%m-%d %H:%M"))";
            }
            
            if (!is_accessible ()) {
                return "Access restricted";
            }
            
            return "Available";
        }
        
        public string get_security_level () {
            switch (backup_type) {
                case EmergencyBackupType.QR_CODE:
                    return "Medium - Physical access required";
                case EmergencyBackupType.TIME_LOCKED:
                    return "High - Time-based access control";
                case EmergencyBackupType.SHAMIR_SECRET_SHARING:
                    return @"Very High - Requires $(shamir_threshold) of $(shamir_total_shares) shares";
                case EmergencyBackupType.TOTP_PROTECTED:
                    return @"High - Requires $(totp_required_count) TOTP code(s)";
                case EmergencyBackupType.MULTI_FACTOR:
                    var factors = new GenericArray<string> ();
                    if (requires_password) factors.add ("password");
                    if (requires_biometric) factors.add ("biometric");
                    if (requires_hardware_key) factors.add ("hardware key");
                    if (totp_required_count > 0) factors.add (@"$(totp_required_count) TOTP");
                    
                    if (factors.length == 0) {
                        return "Medium - Multi-factor (unconfigured)";
                    }
                    
                    var factor_list = new StringBuilder ();
                    for (int i = 0; i < factors.length; i++) {
                        if (i > 0) factor_list.append (", ");
                        factor_list.append (factors[i]);
                    }
                    
                    return @"Very High - Requires: $(factor_list.str)";
                default:
                    return "Unknown";
            }
        }
    }
    
    public class ShamirShare : GLib.Object {
        public int share_number { get; set; }
        public int total_shares { get; set; }
        public int threshold { get; set; }
        public string share_data { get; set; }
        public string qr_code_data { get; set; }
        
        public ShamirShare (int number, int total, int min_shares, string data) {
            share_number = number;
            total_shares = total;
            threshold = min_shares;
            share_data = data;
            qr_code_data = encode_for_qr ();
        }
        
        private string encode_for_qr () {
            // Encode share data for QR code (base64 with metadata)
            var metadata = @"KMVAULT:$(share_number):$(total_shares):$(threshold)";
            var encoded_data = Base64.encode (share_data.data);
            return @"$(metadata):$(encoded_data)";
        }
    }
}