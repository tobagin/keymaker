/*
 * Key Maker - Backup Entry Data Models
 *
 * Data structures for backup entries and Shamir shares.
 */

namespace KeyMaker {
    
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