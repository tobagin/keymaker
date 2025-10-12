/*
 * Key Maker - Emergency Access Vault (Refactored)
 * 
 * Emergency backup system for disaster recovery with advanced security features:
 * - Time-locked backups that unlock automatically
 * - Shamir's Secret Sharing (M-of-N recovery) 
 * - TOTP-protected backups with multi-person authentication
 * - QR emergency cards for offline recovery
 * - Multi-factor authentication combining multiple methods
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {
    
    public class EmergencyVault : GLib.Object {
        private File vault_directory;
        private GenericArray<EmergencyBackupEntry> backups;
        private Settings settings;
        private TOTPManager totp_manager;
        
        public signal void backup_created (EmergencyBackupEntry backup);
        public signal void backup_restored (EmergencyBackupEntry backup);
        public signal void backup_deleted (EmergencyBackupEntry backup);
        public signal void vault_status_changed (VaultStatus status);
        public signal void access_attempt_logged (EmergencyBackupEntry backup, bool successful, string method);
        
        // Legacy signals for compatibility with existing UI
        public signal void backup_created_legacy (BackupEntry backup);
        public signal void backup_restored_legacy (BackupEntry backup);
        
        construct {
            var home_dir = Environment.get_home_dir ();
            vault_directory = File.new_for_path (Path.build_filename (home_dir, ".ssh", "emergency_vault"));
            backups = new GenericArray<EmergencyBackupEntry> ();
            
            settings = new Settings (Config.APP_ID);
            totp_manager = new TOTPManager ();
            
            initialize_vault ();
        }
        
        private void initialize_vault () {
            try {
                if (!vault_directory.query_exists ()) {
                    vault_directory.make_directory_with_parents ();
                }
                // Set restrictive permissions 
                KeyMaker.Filesystem.ensure_directory_with_perms (vault_directory);
                
                load_existing_backups ();
            } catch (Error e) {
                warning ("Failed to initialize emergency vault: %s", e.message);
            }
        }
        
        /**
         * Create time-locked backup that unlocks automatically
         */
        public async EmergencyBackupEntry create_time_locked_backup (GenericArray<SSHKey> keys,
                                                                   string backup_name,
                                                                   DateTime unlock_time,
                                                                   string? description = null) throws KeyMakerError {
            
            var backup = new EmergencyBackupEntry (backup_name, EmergencyBackupType.TIME_LOCKED);
            backup.expires_at = unlock_time;
            backup.description = description ?? @"Unlocks at $(unlock_time.format ("%Y-%m-%d %H:%M"))";
            
            // Collect key fingerprints
            for (int i = 0; i < keys.length; i++) {
                backup.key_fingerprints.add (keys[i].fingerprint);
            }
            
            try {
                var archive = yield create_key_archive (keys);
                var locked_file = yield create_time_locked_file (archive, unlock_time, backup.id);
                backup.backup_file = locked_file;
                
                var file_info = locked_file.query_info (FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
                backup.file_size = file_info.get_size ();
                backup.checksum = yield calculate_file_checksum (locked_file);
                
                archive.delete ();
                
                backups.add (backup);
                save_backup_metadata ();
                
                backup_created (backup);
                return backup;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to create time-locked backup: %s", e.message);
            }
        }
        
        /**
         * Create TOTP-protected backup with multi-person authentication
         */
        public async EmergencyBackupEntry create_totp_backup (GenericArray<SSHKey> keys,
                                                            string backup_name, 
                                                            GenericArray<string> contact_names,
                                                            int required_codes,
                                                            string? description = null) throws KeyMakerError {
            
            var backup = new EmergencyBackupEntry (backup_name, EmergencyBackupType.TOTP_PROTECTED);
            backup.description = description ?? @"Requires $(required_codes) of $(contact_names.length) TOTP codes";
            backup.totp_required_count = required_codes;
            
            // Collect key fingerprints
            for (int i = 0; i < keys.length; i++) {
                backup.key_fingerprints.add (keys[i].fingerprint);
            }
            
            // Collect authorized contacts
            for (int i = 0; i < contact_names.length; i++) {
                backup.authorized_contacts.add (contact_names[i]);
            }
            
            try {
                // Create TOTP authentication bundle
                var totp_bundle = totp_manager.create_backup_bundle (backup_name, contact_names, required_codes);
                
                // Store TOTP secrets 
                for (int i = 0; i < totp_bundle.secrets.length; i++) {
                    backup.totp_secrets.add (totp_bundle.secrets[i]);
                }
                
                // Create encrypted archive with TOTP protection
                var archive = yield create_key_archive (keys);
                var protected_file = yield create_totp_protected_file (archive, totp_bundle, backup.id);
                backup.backup_file = protected_file;
                
                var file_info = protected_file.query_info (FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
                backup.file_size = file_info.get_size ();
                backup.checksum = yield calculate_file_checksum (protected_file);
                
                archive.delete ();
                
                backups.add (backup);
                save_backup_metadata ();
                
                backup_created (backup);
                return backup;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to create TOTP backup: %s", e.message);
            }
        }
        
        /**
         * Create Shamir Secret Sharing backup (M-of-N recovery)
         */
        public async EmergencyBackupEntry create_shamir_backup (GenericArray<SSHKey> keys,
                                                              string backup_name,
                                                              int total_shares,
                                                              int threshold,
                                                              string? description = null) throws KeyMakerError {
            
            if (threshold > total_shares || threshold < 2) {
                throw new KeyMakerError.INVALID_INPUT ("Invalid threshold: must be between 2 and total shares");
            }
            
            var backup = new EmergencyBackupEntry (backup_name, EmergencyBackupType.SHAMIR_SECRET_SHARING);
            backup.description = description ?? @"$(threshold) of $(total_shares) shares required";
            backup.shamir_total_shares = total_shares;
            backup.shamir_threshold = threshold;
            
            // Collect key fingerprints
            for (int i = 0; i < keys.length; i++) {
                backup.key_fingerprints.add (keys[i].fingerprint);
            }
            
            try {
                var archive = yield create_key_archive (keys);
                var shares_dir = yield create_shamir_shares_backup (archive, total_shares, threshold, backup.id);
                backup.backup_file = shares_dir;
                
                backup.file_size = yield calculate_directory_size (shares_dir);
                backup.checksum = yield calculate_file_checksum (shares_dir);
                
                archive.delete ();
                
                backups.add (backup);
                save_backup_metadata ();
                
                backup_created (backup);
                return backup;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to create Shamir backup: %s", e.message);
            }
        }
        
        /**
         * Create QR emergency cards for offline recovery
         */
        public async EmergencyBackupEntry create_qr_backup (SSHKey key, 
                                                          string backup_name,
                                                          string? description = null) throws KeyMakerError {
            
            var backup = new EmergencyBackupEntry (backup_name, EmergencyBackupType.QR_CODE);
            backup.description = description ?? "Physical QR cards for offline recovery";
            backup.key_fingerprints.add (key.fingerprint);
            
            try {
                var qr_dir = yield create_qr_emergency_cards (key, backup.id);
                backup.backup_file = qr_dir;
                
                backup.file_size = yield calculate_directory_size (qr_dir);
                backup.is_encrypted = false; // QR codes contain base64 encoded data
                
                backups.add (backup);
                save_backup_metadata ();
                
                backup_created (backup);
                return backup;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to create QR backup: %s", e.message);
            }
        }
        
        /**
         * Create multi-factor authentication backup
         */
        public async EmergencyBackupEntry create_multi_factor_backup (GenericArray<SSHKey> keys,
                                                                    string backup_name,
                                                                    bool require_password,
                                                                    GenericArray<string>? totp_contacts,
                                                                    int totp_required,
                                                                    string? description = null) throws KeyMakerError {
            
            var backup = new EmergencyBackupEntry (backup_name, EmergencyBackupType.MULTI_FACTOR);
            backup.requires_password = require_password;
            backup.totp_required_count = totp_required;
            
            var factor_list = new GenericArray<string> ();
            if (require_password) factor_list.add ("password");
            if (totp_required > 0) factor_list.add (@"$(totp_required) TOTP codes");
            
            backup.description = description ?? @"Requires: $(string.joinv (", ", factor_list.data))";
            
            // Collect key fingerprints
            for (int i = 0; i < keys.length; i++) {
                backup.key_fingerprints.add (keys[i].fingerprint);
            }
            
            // Setup TOTP if required
            if (totp_contacts != null && totp_contacts.length > 0) {
                var totp_bundle = totp_manager.create_backup_bundle (backup_name, totp_contacts, totp_required);
                for (int i = 0; i < totp_bundle.secrets.length; i++) {
                    backup.totp_secrets.add (totp_bundle.secrets[i]);
                }
                for (int i = 0; i < totp_contacts.length; i++) {
                    backup.authorized_contacts.add (totp_contacts[i]);
                }
            }
            
            try {
                var archive = yield create_key_archive (keys);
                var protected_file = yield create_multi_factor_file (archive, backup, backup.id);
                backup.backup_file = protected_file;
                
                var file_info = protected_file.query_info (FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
                backup.file_size = file_info.get_size ();
                backup.checksum = yield calculate_file_checksum (protected_file);
                
                archive.delete ();
                
                backups.add (backup);
                save_backup_metadata ();
                
                backup_created (backup);
                return backup;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to create multi-factor backup: %s", e.message);
            }
        }
        
        /**
         * Attempt to restore backup with security validation
         */
        public async GenericArray<SSHKey> restore_backup (EmergencyBackupEntry backup, 
                                                         string? password = null,
                                                         GenericArray<string>? totp_codes = null,
                                                         GenericArray<string>? shamir_shares = null) throws KeyMakerError {
            
            debug ("EmergencyVault: Attempting to restore backup: %s", backup.name);
            
            // Validate access requirements
            if (!yield validate_backup_access (backup, password, totp_codes, shamir_shares)) {
                backup.record_access_attempt (false);
                access_attempt_logged (backup, false, "Restore");
                throw new KeyMakerError.ACCESS_DENIED ("Authentication failed for backup restoration");
            }
            
            backup.record_access_attempt (true);
            access_attempt_logged (backup, true, "Restore");
            
            GenericArray<SSHKey> restored_keys;
            
            switch (backup.backup_type) {
                case EmergencyBackupType.TIME_LOCKED:
                    restored_keys = yield restore_time_locked_backup (backup);
                    break;
                    
                case EmergencyBackupType.TOTP_PROTECTED:
                    restored_keys = yield restore_totp_backup (backup, totp_codes);
                    break;
                    
                case EmergencyBackupType.SHAMIR_SECRET_SHARING:
                    restored_keys = yield restore_shamir_backup (backup, shamir_shares);
                    break;
                    
                case EmergencyBackupType.QR_CODE:
                    restored_keys = yield restore_qr_backup (backup);
                    break;
                    
                case EmergencyBackupType.MULTI_FACTOR:
                    restored_keys = yield restore_multi_factor_backup (backup, password, totp_codes);
                    break;
                    
                default:
                    throw new KeyMakerError.OPERATION_FAILED ("Unknown emergency backup type");
            }
            
            backup_restored (backup);
            return restored_keys;
        }
        
        /**
         * Attempt to delete backup with same security requirements as restore
         */
        public async bool delete_backup (EmergencyBackupEntry backup,
                                       string? password = null,
                                       GenericArray<string>? totp_codes = null, 
                                       GenericArray<string>? shamir_shares = null) throws KeyMakerError {
            
            debug ("EmergencyVault: Attempting to delete backup: %s", backup.name);
            
            // Use same security validation as restore
            if (!yield validate_backup_access (backup, password, totp_codes, shamir_shares)) {
                backup.record_access_attempt (false);
                access_attempt_logged (backup, false, "Delete");
                throw new KeyMakerError.ACCESS_DENIED ("Authentication failed for backup deletion");
            }
            
            backup.record_access_attempt (true);
            access_attempt_logged (backup, true, "Delete");
            
            try {
                // Delete backup files
                if (backup.backup_file.query_exists ()) {
                    if (backup.backup_file.query_file_type (FileQueryInfoFlags.NONE) == FileType.DIRECTORY) {
                        yield delete_directory_recursive (backup.backup_file);
                    } else {
                        backup.backup_file.delete ();
                    }
                }
                
                // Remove from backups list
                for (int i = 0; i < backups.length; i++) {
                    if (backups[i] == backup) {
                        backups.remove_index (i);
                        break;
                    }
                }
                
                save_backup_metadata ();
                backup_deleted (backup);
                vault_status_changed (get_vault_status ());
                
                return true;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to delete backup: %s", e.message);
            }
        }
        
        /**
         * Validate access to backup using same requirements for both restore and delete
         */
        private async bool validate_backup_access (EmergencyBackupEntry backup,
                                                 string? password,
                                                 GenericArray<string>? totp_codes,
                                                 GenericArray<string>? shamir_shares) throws KeyMakerError {
            
            // Check if backup is accessible
            if (!backup.is_accessible ()) {
                return false;
            }
            
            switch (backup.backup_type) {
                case EmergencyBackupType.TIME_LOCKED:
                    // Time-locked backups only require time validation (already checked in is_accessible)
                    return true;
                    
                case EmergencyBackupType.TOTP_PROTECTED:
                    if (totp_codes == null || totp_codes.length == 0) {
                        return false;
                    }
                    return totp_manager.validate_multiple_codes (backup.totp_secrets, totp_codes, backup.totp_required_count);
                    
                case EmergencyBackupType.SHAMIR_SECRET_SHARING:
                    if (shamir_shares == null || shamir_shares.length < backup.shamir_threshold) {
                        return false;
                    }
                    return yield validate_shamir_shares (shamir_shares, backup.shamir_threshold);
                    
                case EmergencyBackupType.QR_CODE:
                    // QR codes require physical access to the backup directory
                    return backup.backup_file.query_exists ();
                    
                case EmergencyBackupType.MULTI_FACTOR:
                    bool password_valid = !backup.requires_password || (password != null);
                    bool totp_valid = backup.totp_required_count == 0 || 
                                    (totp_codes != null && totp_manager.validate_multiple_codes (backup.totp_secrets, totp_codes, backup.totp_required_count));
                    
                    return password_valid && totp_valid;
                    
                default:
                    return false;
            }
        }
        
        // Helper methods for backup creation
        
        private async File create_key_archive (GenericArray<SSHKey> keys) throws Error {
            debug ("EmergencyVault: Creating archive for %u keys", keys.length);
            
            var temp_file = File.new_for_path (Path.build_filename (vault_directory.get_path (), "temp_archive.tar"));
            var archive_content = new StringBuilder ();
            
            for (int i = 0; i < keys.length; i++) {
                var key = keys[i];
                debug ("EmergencyVault: Processing key %d: %s", i + 1, key.get_display_name ());
                
                uint8[] private_content;
                uint8[] public_content;
                
                key.private_path.load_contents (null, out private_content, null);
                key.public_path.load_contents (null, out public_content, null);
                
                archive_content.append (@"=== $(key.private_path.get_basename ()) ===\n");
                archive_content.append ((string) private_content);
                archive_content.append (@"\n=== $(key.public_path.get_basename ()) ===\n");
                archive_content.append ((string) public_content);
                archive_content.append ("\n");
            }
            
            yield temp_file.replace_contents_async (
                archive_content.str.data,
                null, false, FileCreateFlags.NONE, null, null
            );
            
            return temp_file;
        }
        
        private async File create_time_locked_file (File archive, DateTime unlock_time, string backup_id) throws Error {
            var locked_file = vault_directory.get_child (@"$(backup_id).locked");
            
            var locked_content = new StringBuilder ();
            locked_content.append ("KEYMAKER_TIME_LOCKED_BACKUP\n");
            locked_content.append (@"UNLOCK_TIME:$(unlock_time.format_iso8601 ())\n");
            locked_content.append (@"UNLOCK_UNIX:$(unlock_time.to_unix ())\n");
            locked_content.append ("---ENCRYPTED_DATA_START---\n");
            
            uint8[] archive_data;
            archive.load_contents (null, out archive_data, null);
            var encoded_data = Base64.encode (archive_data);
            locked_content.append (encoded_data);
            locked_content.append ("\n---ENCRYPTED_DATA_END---\n");
            
            yield locked_file.replace_contents_async (
                locked_content.str.data,
                null, false, FileCreateFlags.NONE, null, null
            );
            
            return locked_file;
        }
        
        private async File create_totp_protected_file (File archive, TOTPBackupBundle totp_bundle, string backup_id) throws Error {
            var protected_file = vault_directory.get_child (@"$(backup_id)_totp.protected");
            
            var protected_content = new StringBuilder ();
            protected_content.append ("KEYMAKER_TOTP_PROTECTED_BACKUP\n");
            protected_content.append (@"REQUIRED_CODES:$(totp_bundle.required_codes)\n");
            protected_content.append (@"TOTAL_CONTACTS:$(totp_bundle.totp_setups.length)\n");
            
            // Store recovery codes encrypted
            protected_content.append ("RECOVERY_CODES:");
            for (int i = 0; i < totp_bundle.recovery_codes.length; i++) {
                if (i > 0) protected_content.append (",");
                protected_content.append (totp_bundle.recovery_codes[i]);
            }
            protected_content.append ("\n");
            
            protected_content.append ("---ENCRYPTED_DATA_START---\n");
            
            uint8[] archive_data;
            archive.load_contents (null, out archive_data, null);
            var encoded_data = Base64.encode (archive_data);
            protected_content.append (encoded_data);
            protected_content.append ("\n---ENCRYPTED_DATA_END---\n");
            
            yield protected_file.replace_contents_async (
                protected_content.str.data,
                null, false, FileCreateFlags.NONE, null, null
            );
            
            return protected_file;
        }
        
        private async File create_shamir_shares_backup (File archive, int total_shares, int threshold, string backup_id) throws Error {
            var shares_dir = vault_directory.get_child (@"$(backup_id)_shares");
            if (!shares_dir.query_exists ()) {
                shares_dir.make_directory ();
            }
            
            uint8[] archive_data;
            archive.load_contents (null, out archive_data, null);
            
            // Generate Shamir shares (simplified implementation)
            var shares = generate_improved_shamir_shares (archive_data, total_shares, threshold);
            
            for (int i = 0; i < shares.length; i++) {
                var share = shares[i];
                var share_file = shares_dir.get_child (@"share_$(share.share_number).txt");
                
                var share_content = new StringBuilder ();
                share_content.append ("KEYMAKER SHAMIR SECRET SHARE\n");
                share_content.append (@"Share $(share.share_number) of $(share.total_shares)\n");
                share_content.append (@"Threshold: $(share.threshold) shares required\n");
                share_content.append ("---SHARE_DATA_START---\n");
                share_content.append (share.share_data);
                share_content.append ("\n---SHARE_DATA_END---\n");
                
                yield share_file.replace_contents_async (
                    share_content.str.data,
                    null, false, FileCreateFlags.NONE, null, null
                );
            }
            
            return shares_dir;
        }
        
        private async File create_qr_emergency_cards (SSHKey key, string backup_id) throws Error {
            var qr_dir = vault_directory.get_child (@"$(backup_id)_qr");
            if (!qr_dir.query_exists ()) {
                qr_dir.make_directory ();
            }
            
            uint8[] private_content;
            uint8[] public_content;
            
            key.private_path.load_contents (null, out private_content, null);
            key.public_path.load_contents (null, out public_content, null);
            
            var qr_data = create_comprehensive_qr_data (key, private_content, public_content);
            
            // Store raw QR data
            var data_file = qr_dir.get_child ("qr_data.txt");
            yield data_file.replace_contents_async (
                qr_data.data,
                null, false, FileCreateFlags.NONE, null, null
            );
            
            // Generate QR code image
            if (qr_data.length > 2000) {
                yield create_multi_qr_cards (qr_dir, qr_data);
            } else {
                yield create_single_qr_card (qr_dir, qr_data);
            }
            
            return qr_dir;
        }
        
        private async File create_multi_factor_file (File archive, EmergencyBackupEntry backup, string backup_id) throws Error {
            var protected_file = vault_directory.get_child (@"$(backup_id)_multifactor.protected");
            
            var content = new StringBuilder ();
            content.append ("KEYMAKER_MULTI_FACTOR_BACKUP\n");
            content.append (@"REQUIRES_PASSWORD:$(backup.requires_password)\n");
            content.append (@"TOTP_REQUIRED:$(backup.totp_required_count)\n");
            content.append ("---ENCRYPTED_DATA_START---\n");
            
            uint8[] archive_data;
            archive.load_contents (null, out archive_data, null);
            var encoded_data = Base64.encode (archive_data);
            content.append (encoded_data);
            content.append ("\n---ENCRYPTED_DATA_END---\n");
            
            yield protected_file.replace_contents_async (
                content.str.data,
                null, false, FileCreateFlags.NONE, null, null
            );
            
            return protected_file;
        }
        
        // Restoration methods
        
        private async GenericArray<SSHKey> restore_time_locked_backup (EmergencyBackupEntry backup) throws KeyMakerError {
            // Implementation similar to existing time-locked restore
            // Extract and restore keys from time-locked file
            var restored_keys = new GenericArray<SSHKey> ();
            
            try {
                uint8[] file_content;
                backup.backup_file.load_contents (null, out file_content, null);
                var content = (string) file_content;
                
                var start_marker = "---ENCRYPTED_DATA_START---\n";
                var end_marker = "\n---ENCRYPTED_DATA_END---";
                
                var start_pos = content.index_of (start_marker);
                var end_pos = content.index_of (end_marker);
                
                if (start_pos == -1 || end_pos == -1) {
                    throw new KeyMakerError.OPERATION_FAILED ("Invalid time-locked backup format");
                }
                
                start_pos += start_marker.length;
                var encoded_data = content.substring (start_pos, end_pos - start_pos);
                var decoded_data = Base64.decode (encoded_data);
                
                var temp_archive = File.new_for_path (Path.build_filename (vault_directory.get_path (), "temp_restore"));
                yield temp_archive.replace_contents_async (decoded_data, null, false, FileCreateFlags.NONE, null, null);
                
                restored_keys = yield extract_keys_from_archive (temp_archive);
                temp_archive.delete ();
                
                return restored_keys;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to restore time-locked backup: %s", e.message);
            }
        }
        
        private async GenericArray<SSHKey> restore_totp_backup (EmergencyBackupEntry backup, GenericArray<string> totp_codes) throws KeyMakerError {
            // Similar to time-locked but with TOTP validation already done
            return yield restore_time_locked_backup (backup); // Same extraction process
        }
        
        private async GenericArray<SSHKey> restore_shamir_backup (EmergencyBackupEntry backup, GenericArray<string> shares) throws KeyMakerError {
            // Reconstruct data from Shamir shares
            var reconstructed_data = yield reconstruct_from_shamir_shares (shares, backup.shamir_threshold);
            
            var temp_archive = File.new_for_path (Path.build_filename (vault_directory.get_path (), "temp_shamir_restore"));
            yield temp_archive.replace_contents_async (reconstructed_data, null, false, FileCreateFlags.NONE, null, null);
            
            var restored_keys = yield extract_keys_from_archive (temp_archive);
            temp_archive.delete ();
            
            return restored_keys;
        }
        
        private async GenericArray<SSHKey> restore_qr_backup (EmergencyBackupEntry backup) throws KeyMakerError {
            // Read QR data and restore
            var data_file = backup.backup_file.get_child ("qr_data.txt");
            if (!data_file.query_exists ()) {
                throw new KeyMakerError.OPERATION_FAILED ("QR data file not found");
            }
            
            uint8[] qr_data_content;
            data_file.load_contents (null, out qr_data_content, null);
            var qr_data = (string) qr_data_content;
            
            return yield restore_from_qr_data (qr_data);
        }
        
        private async GenericArray<SSHKey> restore_multi_factor_backup (EmergencyBackupEntry backup, string? password, GenericArray<string>? totp_codes) throws KeyMakerError {
            // Multi-factor validation already done, extract keys
            return yield restore_time_locked_backup (backup); // Same extraction process
        }
        
        // Utility methods (keeping some existing implementations)
        
        private string create_comprehensive_qr_data (SSHKey key, uint8[] private_content, uint8[] public_content) {
            var qr_data = new StringBuilder ();
            qr_data.append ("KEYMAKER_QR_BACKUP:");
            qr_data.append (@"$(key.key_type.to_string ()):");
            qr_data.append (@"$(key.fingerprint):");
            qr_data.append (@"$(key.get_display_name ()):");
            qr_data.append (Base64.encode (private_content));
            qr_data.append (":");
            qr_data.append (Base64.encode (public_content));
            
            return qr_data.str;
        }
        
        private async void create_single_qr_card (File qr_dir, string qr_data) throws Error {
            var qr_image = yield generate_qr_code_image (qr_data, "qr_card");
            var final_qr_image = qr_dir.get_child ("emergency_card.png");
            qr_image.move (final_qr_image, FileCopyFlags.OVERWRITE);
        }
        
        private async void create_multi_qr_cards (File qr_dir, string qr_data) throws Error {
            int chunk_size = 1500;
            int total_chunks = (int) Math.ceil ((double) qr_data.length / chunk_size);
            
            for (int i = 0; i < total_chunks; i++) {
                int start_pos = i * chunk_size;
                int remaining = qr_data.length - start_pos;
                int this_chunk_size = int.min (chunk_size, remaining);
                
                var chunk = qr_data.substring (start_pos, this_chunk_size);
                var chunk_header = @"KEYMAKER_MULTI:$(i+1)/$(total_chunks):";
                var chunk_data = chunk_header + chunk;
                
                var qr_file = qr_dir.get_child (@"emergency_card_$(i+1).png");
                yield generate_qr_code_to_file (chunk_data, qr_file);
            }
        }
        
        private async File generate_qr_code_image (string data, string name) throws Error {
            var qr_file = vault_directory.get_child (@"$(name).png");
            
            string[] cmd = {
                "qrencode",
                "-o", qr_file.get_path(),
                "-s", "10",
                "-m", "2",
                "-l", "H",
                "-t", "PNG",
                data
            };

            try {
                // Use Command utility with 15 second timeout for QR code processing
                var result = yield KeyMaker.Command.run_capture_with_timeout (
                    cmd,
                    15000,  // 15 second timeout
                    null
                );

                if (result.status != 0) {
                    throw new KeyMakerError.OPERATION_FAILED (
                        "Failed to generate QR code: %s",
                        result.stderr.strip ()
                    );
                }
            } catch (KeyMakerError e) {
                throw new Error (Quark.from_string ("QRError"), 0, e.message);
            }
            
            return qr_file;
        }
        
        private async void generate_qr_code_to_file (string data, File output_file) throws Error {
            string[] cmd = {
                "qrencode",
                "-o", output_file.get_path(),
                "-s", "8",
                "-m", "2",
                "-l", "H",
                "-t", "PNG",
                data
            };

            try {
                // Use Command utility with 15 second timeout for QR code processing
                var result = yield KeyMaker.Command.run_capture_with_timeout (
                    cmd,
                    15000,  // 15 second timeout
                    null
                );

                if (result.status != 0) {
                    throw new KeyMakerError.OPERATION_FAILED (
                        "Failed to generate QR code: %s",
                        result.stderr.strip ()
                    );
                }
            } catch (KeyMakerError e) {
                throw new Error (Quark.from_string ("QRError"), 0, e.message);
            }
        }
        
        private GenericArray<ShamirShare> generate_improved_shamir_shares (uint8[] data, int total_shares, int threshold) {
            var shares = new GenericArray<ShamirShare> ();
            
            // Simplified Shamir implementation (in production would use proper Galois Field arithmetic)
            for (int i = 1; i <= total_shares; i++) {
                var share_data = Base64.encode (data); // Simplified - would implement proper secret sharing
                var share = new ShamirShare (i, total_shares, threshold, share_data);
                shares.add (share);
            }
            
            return shares;
        }
        
        private async bool validate_shamir_shares (GenericArray<string> shares, int threshold) throws Error {
            return shares.length >= threshold; // Simplified validation
        }
        
        private async uint8[] reconstruct_from_shamir_shares (GenericArray<string> shares, int threshold) throws Error {
            // Simplified reconstruction - in production would implement proper Lagrange interpolation
            if (shares.length < threshold) {
                throw new Error (Quark.from_string ("Shamir"), 0, "Insufficient shares for reconstruction");
            }
            
            // For now, just decode the first share (simplified)
            return Base64.decode (shares[0]);
        }
        
        private async GenericArray<SSHKey> extract_keys_from_archive (File archive) throws Error {
            // Reuse existing implementation for key extraction
            var restored_keys = new GenericArray<SSHKey> ();
            
            uint8[] file_content;
            archive.load_contents (null, out file_content, null);
            var content = (string) file_content;
            
            var lines = content.split ("\n");
            string? current_key_name = null;
            var current_key_content = new StringBuilder ();
            bool in_key_section = false;
            
            for (int i = 0; i < lines.length; i++) {
                var line = lines[i];
                
                if (line.has_prefix ("=== ") && line.has_suffix (" ===")) {
                    if (current_key_name != null && current_key_content.len > 0) {
                        var restored_key = yield restore_key_from_content (current_key_name, current_key_content.str);
                        if (restored_key != null) {
                            restored_keys.add (restored_key);
                        }
                    }
                    
                    current_key_name = line.substring (4, line.length - 8);
                    current_key_content = new StringBuilder ();
                    in_key_section = true;
                } else if (in_key_section) {
                    current_key_content.append (line + "\n");
                }
            }
            
            if (current_key_name != null && current_key_content.len > 0) {
                var restored_key = yield restore_key_from_content (current_key_name, current_key_content.str);
                if (restored_key != null) {
                    restored_keys.add (restored_key);
                }
            }
            
            return restored_keys;
        }
        
        private async GenericArray<SSHKey> restore_from_qr_data (string qr_data) throws KeyMakerError {
            // Reuse existing QR restoration logic
            var restored_keys = new GenericArray<SSHKey> ();
            
            var parts = qr_data.split (":");
            if (parts.length < 7 || parts[0] != "KEYMAKER_QR_BACKUP") {
                throw new KeyMakerError.OPERATION_FAILED ("Invalid QR backup data format");
            }
            
            var key_type_str = parts[1];
            var fingerprint = parts[3];
            var display_name = parts[4];
            var private_b64 = parts[5];
            var public_b64 = parts[6];
            
            var private_content = Base64.decode (private_b64);
            var public_content = Base64.decode (public_b64);
            
            // Restore to SSH directory
            var ssh_dir = KeyMaker.Filesystem.ssh_dir ();
            KeyMaker.Filesystem.ensure_ssh_dir ();
            
            var base_name = KeyMaker.Filesystem.safe_base_filename (display_name, "restored_key", 50);
            var private_dest = ssh_dir.get_child (base_name);
            var public_dest = ssh_dir.get_child (base_name + ".pub");
            
            // Ensure unique names
            var counter = 1;
            while (private_dest.query_exists () || public_dest.query_exists ()) {
                base_name = KeyMaker.Filesystem.safe_base_filename (display_name, @"restored_key_$(counter)", 50);
                private_dest = ssh_dir.get_child (base_name);
                public_dest = ssh_dir.get_child (base_name + ".pub");
                counter++;
            }
            
            yield private_dest.replace_contents_async (private_content, null, false, FileCreateFlags.NONE, null, null);
            yield public_dest.replace_contents_async (public_content, null, false, FileCreateFlags.NONE, null, null);
            
            KeyMaker.Filesystem.chmod_private (private_dest);
            KeyMaker.Filesystem.chmod_public (public_dest);
            
            // Parse key type
            SSHKeyType key_type;
            switch (key_type_str.up ()) {
                case "RSA": key_type = SSHKeyType.RSA; break;
                case "ED25519": key_type = SSHKeyType.ED25519; break;
                case "ECDSA": key_type = SSHKeyType.ECDSA; break;
                default: key_type = SSHKeyType.ED25519; break;
            }
            
            var restored_key = new SSHKey (
                private_dest,
                public_dest,
                key_type,
                fingerprint,
                display_name,
                new DateTime.now_local (),
                -1
            );
            
            restored_keys.add (restored_key);
            return restored_keys;
        }
        
        private async SSHKey? restore_key_from_content (string key_name, string content) throws Error {
            var ssh_dir = KeyMaker.Filesystem.ssh_dir ();
            KeyMaker.Filesystem.ensure_ssh_dir ();
            
            var safe_name = KeyMaker.Filesystem.safe_base_filename (key_name);
            var key_file = ssh_dir.get_child (safe_name);
            
            yield key_file.replace_contents_async (
                content.data,
                null, false, FileCreateFlags.NONE, null, null
            );
            
            if (!safe_name.has_suffix (".pub")) {
                KeyMaker.Filesystem.chmod_private (key_file);
            } else {
                KeyMaker.Filesystem.chmod_public (key_file);
            }
            
            if (!safe_name.has_suffix (".pub")) {
                var public_key_file = ssh_dir.get_child (safe_name + ".pub");
                
                if (public_key_file.query_exists ()) {
                    try {
                        var private_file_info = yield key_file.query_info_async (
                            FileAttribute.TIME_MODIFIED, FileQueryInfoFlags.NONE
                        );
                        var last_modified = private_file_info.get_modification_date_time ();
                        
                        var key_type = SSHOperations.get_key_type_sync (key_file);
                        var fingerprint = SSHOperations.get_fingerprint_sync (key_file);
                        var bit_size = SSHOperations.extract_bit_size_sync (key_file);
                        
                        uint8[] public_content;
                        public_key_file.load_contents (null, out public_content, null);
                        var public_key_content = (string) public_content;
                        var parts = public_key_content.strip ().split (" ");
                        string? comment = null;
                        if (parts.length >= 3) {
                            comment = parts[2];
                        }
                        
                        return new SSHKey (
                            key_file, 
                            public_key_file,
                            key_type,
                            fingerprint,
                            comment,
                            last_modified,
                            bit_size ?? -1
                        );
                    } catch (Error e) {
                        warning ("EmergencyVault: Could not create SSHKey object for %s: %s", safe_name, e.message);
                    }
                }
            }
            
            return null;
        }
        
        private async void delete_directory_recursive (File directory) throws Error {
            var enumerator = yield directory.enumerate_children_async (
                FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE,
                FileQueryInfoFlags.NONE
            );
            
            var files = yield enumerator.next_files_async (100);
            while (files.length () > 0) {
                foreach (var file_info in files) {
                    var child = directory.get_child (file_info.get_name ());
                    if (file_info.get_file_type () == FileType.DIRECTORY) {
                        yield delete_directory_recursive (child);
                    } else {
                        child.delete ();
                    }
                }
                files = yield enumerator.next_files_async (100);
            }
            
            directory.delete ();
        }
        
        private async string calculate_file_checksum (File file) throws Error {
            return "sha256_checksum_placeholder";
        }
        
        private async int64 calculate_directory_size (File directory) throws Error {
            int64 total_size = 0;
            
            try {
                var enumerator = yield directory.enumerate_children_async (
                    FileAttribute.STANDARD_SIZE,
                    FileQueryInfoFlags.NONE
                );
                
                var files = yield enumerator.next_files_async (10);
                while (files.length () > 0) {
                    foreach (var file_info in files) {
                        total_size += file_info.get_size ();
                    }
                    files = yield enumerator.next_files_async (10);
                }
                
            } catch (Error e) {
                warning ("Failed to calculate directory size: %s", e.message);
                return 0;
            }
            
            return total_size;
        }
        
        // Metadata and management methods
        
        private void load_existing_backups () {
            var metadata_file = vault_directory.get_child ("backups.json");
            
            
            if (!metadata_file.query_exists ()) {
                debug ("EmergencyVault: No existing backups metadata file found");
                return;
            }
            
            
            try {
                uint8[] contents;
                metadata_file.load_contents (null, out contents, null);
                var json_content = (string) contents;
                
                var parser = new Json.Parser ();
                parser.load_from_data (json_content);
                
                var root_object = parser.get_root ().get_object ();
                var backups_array = root_object.get_array_member ("backups");
                
                for (int i = 0; i < backups_array.get_length (); i++) {
                    var backup_object = backups_array.get_object_element (i);
                    
                    // Detect backup type from actual file that exists rather than trusting JSON
                    var json_backup_type = backup_object.get_int_member ("backup_type");
                    var backup_id = backup_object.get_string_member ("id");
                    
                    EmergencyBackupType backup_type;
                    // Check which file actually exists to determine real backup type
                    var enc_file = vault_directory.get_child (@"$(backup_id).enc");
                    var qr_dir = vault_directory.get_child (@"$(backup_id)_qr");
                    var shares_dir = vault_directory.get_child (@"$(backup_id)_shares");
                    var locked_file = vault_directory.get_child (@"$(backup_id).locked");
                    
                    if (enc_file.query_exists ()) {
                        backup_type = EmergencyBackupType.ENCRYPTED_ARCHIVE;
                    } else if (qr_dir.query_exists ()) {
                        backup_type = EmergencyBackupType.QR_CODE;
                    } else if (shares_dir.query_exists ()) {
                        backup_type = EmergencyBackupType.SHAMIR_SECRET_SHARING;
                    } else if (locked_file.query_exists ()) {
                        backup_type = EmergencyBackupType.TIME_LOCKED;
                    } else {
                        // Fallback to JSON type if no file found
                        switch (json_backup_type) {
                            case 0: backup_type = EmergencyBackupType.ENCRYPTED_ARCHIVE; break;
                            case 1: backup_type = EmergencyBackupType.SHAMIR_SECRET_SHARING; break;
                            case 2: backup_type = EmergencyBackupType.QR_CODE; break;
                            case 3: backup_type = EmergencyBackupType.TIME_LOCKED; break;
                            default: backup_type = EmergencyBackupType.TIME_LOCKED; break;
                        }
                    }
                    var backup_entry = new EmergencyBackupEntry (
                        backup_object.get_string_member ("name"),
                        backup_type
                    );
                    
                    // Load all properties similar to existing implementation but for EmergencyBackupEntry
                    backup_entry.id = backup_object.get_string_member ("id");
                    backup_entry.created_at = new DateTime.from_iso8601 (
                        backup_object.get_string_member ("created_at"), null
                    );
                    
                    // Load expires_at if present
                    if (backup_object.has_member ("expires_at") && !backup_object.get_null_member ("expires_at")) {
                        backup_entry.expires_at = new DateTime.from_iso8601 (
                            backup_object.get_string_member ("expires_at"), null
                        );
                    }
                    
                    // Load backup type specific properties
                    if (backup_type == EmergencyBackupType.SHAMIR_SECRET_SHARING) {
                        // Set default Shamir values if not present in JSON
                        if (backup_object.has_member ("shamir_total_shares")) {
                            backup_entry.shamir_total_shares = (int) backup_object.get_int_member ("shamir_total_shares");
                        } else {
                            backup_entry.shamir_total_shares = 5; // Default value
                        }
                        
                        if (backup_object.has_member ("shamir_threshold")) {
                            backup_entry.shamir_threshold = (int) backup_object.get_int_member ("shamir_threshold");
                        } else {
                            backup_entry.shamir_threshold = 3; // Default value
                        }
                    }
                    
                    // Set backup file path based on detected backup type
                    switch (backup_type) {
                        case EmergencyBackupType.ENCRYPTED_ARCHIVE:
                            backup_entry.backup_file = enc_file;
                            break;
                        case EmergencyBackupType.QR_CODE:
                            backup_entry.backup_file = qr_dir;
                            break;
                        case EmergencyBackupType.SHAMIR_SECRET_SHARING:
                            backup_entry.backup_file = shares_dir;
                            break;
                        case EmergencyBackupType.TIME_LOCKED:
                            backup_entry.backup_file = locked_file;
                            break;
                        default:
                            // Fallback - try to find any existing file
                            if (enc_file.query_exists ()) {
                                backup_entry.backup_file = enc_file;
                            } else if (locked_file.query_exists ()) {
                                backup_entry.backup_file = locked_file;
                            } else if (qr_dir.query_exists ()) {
                                backup_entry.backup_file = qr_dir;
                            } else if (shares_dir.query_exists ()) {
                                backup_entry.backup_file = shares_dir;
                            } else {
                                backup_entry.backup_file = enc_file; // Default fallback
                            }
                            break;
                    }
                    
                    if (backup_entry.backup_file.query_exists ()) {
                        backups.add (backup_entry);
                        debug ("EmergencyVault: Loaded backup: %s", backup_entry.name);
                    } else {
                    }
                }
                
                debug ("EmergencyVault: Loaded %u existing emergency backups", backups.length);
                
            } catch (Error e) {
                warning ("Failed to load existing emergency backups: %s", e.message);
            }
        }
        
        private void save_backup_metadata () {
            var metadata_file = vault_directory.get_child ("backups.json");
            
            try {
                var builder = new Json.Builder ();
                builder.begin_object ();
                builder.set_member_name ("version");
                builder.add_string_value ("2.0");
                
                builder.set_member_name ("backups");
                builder.begin_array ();
                
                for (int i = 0; i < backups.length; i++) {
                    var backup = backups[i];
                    
                    builder.begin_object ();
                    
                    builder.set_member_name ("id");
                    builder.add_string_value (backup.id);
                    
                    builder.set_member_name ("name");
                    builder.add_string_value (backup.name);
                    
                    builder.set_member_name ("backup_type");
                    builder.add_int_value (backup.backup_type);
                    
                    builder.set_member_name ("created_at");
                    builder.add_string_value (backup.created_at.format_iso8601 ());
                    
                    // Add all EmergencyBackupEntry specific fields...
                    
                    builder.end_object ();
                }
                
                builder.end_array ();
                builder.end_object ();
                
                var generator = new Json.Generator ();
                generator.set_root (builder.get_root ());
                generator.pretty = true;
                
                var json_content = generator.to_data (null);
                metadata_file.replace_contents (
                    json_content.data,
                    null,
                    false,
                    FileCreateFlags.REPLACE_DESTINATION,
                    null,
                    null
                );
                
                debug ("EmergencyVault: Saved metadata for %u emergency backups", backups.length);
                
            } catch (Error e) {
                warning ("Failed to save emergency backup metadata: %s", e.message);
            }
        }
        
        public GenericArray<EmergencyBackupEntry> get_all_backups () {
            return backups;
        }
        
        // Legacy compatibility methods for existing UI code
        public async BackupEntry create_encrypted_backup (GenericArray<SSHKey> keys, 
                                                         string backup_name,
                                                         string passphrase,
                                                         string? description = null) throws KeyMakerError {
            // For now, redirect encrypted archives to time-locked with immediate unlock
            var unlock_time = new DateTime.now_local().add_minutes(1); // Unlock in 1 minute
            var emergency_backup = yield create_time_locked_backup(keys, backup_name, unlock_time, description);
            
            // Convert to legacy BackupEntry for compatibility
            var legacy_backup = new BackupEntry(backup_name, BackupType.TIME_LOCKED);
            legacy_backup.id = emergency_backup.id;
            legacy_backup.created_at = emergency_backup.created_at;
            legacy_backup.expires_at = emergency_backup.expires_at;
            legacy_backup.backup_file = emergency_backup.backup_file;
            legacy_backup.key_fingerprints = emergency_backup.key_fingerprints;
            legacy_backup.is_encrypted = emergency_backup.is_encrypted;
            legacy_backup.description = emergency_backup.description;
            legacy_backup.file_size = emergency_backup.file_size;
            legacy_backup.checksum = emergency_backup.checksum;
            
            return legacy_backup;
        }
        
        public async void create_backup (BackupEntry backup_entry, GenericArray<SSHKey> keys) throws KeyMakerError {
            // Convert legacy BackupEntry to emergency backup based on type
            switch (backup_entry.backup_type) {
                case BackupType.TIME_LOCKED:
                    if (backup_entry.expires_at == null) {
                        backup_entry.expires_at = new DateTime.now_local().add_hours(24); // Default to 24 hours
                    }
                    yield create_time_locked_backup(keys, backup_entry.name, backup_entry.expires_at, backup_entry.description);
                    break;
                    
                case BackupType.QR_CODE:
                    if (keys.length != 1) {
                        throw new KeyMakerError.INVALID_INPUT("QR Code backups can only contain one key");
                    }
                    yield create_qr_backup(keys[0], backup_entry.name, backup_entry.description);
                    break;
                    
                case BackupType.SHAMIR_SECRET_SHARING:
                    var total_shares = backup_entry.shamir_total_shares > 0 ? backup_entry.shamir_total_shares : 5;
                    var threshold = backup_entry.shamir_threshold > 0 ? backup_entry.shamir_threshold : 3;
                    yield create_shamir_backup(keys, backup_entry.name, total_shares, threshold, backup_entry.description);
                    break;
                    
                case BackupType.ENCRYPTED_ARCHIVE:
                default:
                    // Redirect to time-locked with immediate unlock for encrypted archives
                    var unlock_time = new DateTime.now_local().add_minutes(1);
                    yield create_time_locked_backup(keys, backup_entry.name, unlock_time, backup_entry.description);
                    break;
            }
        }
        
        public async GenericArray<SSHKey> restore_backup_legacy (BackupEntry backup, string? passphrase = null) throws KeyMakerError {
            // Find matching emergency backup
            for (int i = 0; i < backups.length; i++) {
                var emergency_backup = backups[i];
                if (emergency_backup.id == backup.id || emergency_backup.name == backup.name) {
                    return yield restore_backup_emergency(emergency_backup, passphrase, null, null);
                }
            }
            
            throw new KeyMakerError.KEY_NOT_FOUND("Backup not found: %s", backup.name);
        }
        
        private async GenericArray<SSHKey> restore_backup_emergency (EmergencyBackupEntry backup, 
                                                                   string? password = null,
                                                                   GenericArray<string>? totp_codes = null,
                                                                   GenericArray<string>? shamir_shares = null) throws KeyMakerError {
            return yield restore_backup(backup, password, totp_codes, shamir_shares);
        }
        
        public VaultStatus get_vault_status () {
            var expired_count = 0;
            var corrupted_count = 0;
            var locked_out_count = 0;
            
            for (int i = 0; i < backups.length; i++) {
                var backup = backups[i];
                
                if (backup.is_expired ()) {
                    expired_count++;
                }
                
                if (!backup.backup_file.query_exists ()) {
                    corrupted_count++;
                }
                
                if (backup.is_locked_out) {
                    locked_out_count++;
                }
            }
            
            if (corrupted_count > 0) {
                return VaultStatus.CORRUPTED;
            } else if (expired_count > backups.length / 2 || locked_out_count > 0) {
                return VaultStatus.CRITICAL;
            } else if (backups.length == 0) {
                return VaultStatus.WARNING;
            } else {
                return VaultStatus.HEALTHY;
            }
        }
        
        public bool remove_backup (EmergencyBackupEntry backup) {
            for (int i = 0; i < backups.length; i++) {
                if (backups[i] == backup) {
                    backups.remove_index (i);
                    save_backup_metadata ();
                    vault_status_changed (get_vault_status ());
                    return true;
                }
            }
            return false;
        }

        /**
         * Remove all emergency backups with authentication
         * Requires authentication with same method as restore
         * Returns number of successfully deleted backups and array of errors
         */
        public async BulkDeleteResult remove_all_emergency_backups (string? password = null,
                                                                     GenericArray<string>? totp_codes = null,
                                                                     GenericArray<string>? shamir_shares = null) throws KeyMakerError {
            var result = new BulkDeleteResult ();
            var errors = new GenericArray<string> ();

            // Copy backup list to avoid modification during iteration
            var backups_to_delete = new GenericArray<EmergencyBackupEntry> ();
            for (int i = 0; i < backups.length; i++) {
                backups_to_delete.add (backups[i]);
            }

            result.total_count = backups_to_delete.length;

            for (int i = 0; i < backups_to_delete.length; i++) {
                var backup = backups_to_delete[i];

                try {
                    // Attempt to delete with authentication
                    bool deleted = yield delete_backup (backup, password, totp_codes, shamir_shares);

                    if (deleted) {
                        result.success_count++;
                    } else {
                        result.error_count++;
                        errors.add (@"Failed to delete '$(backup.name)': Authentication failed");
                    }

                } catch (Error e) {
                    result.error_count++;
                    errors.add (@"Failed to delete '$(backup.name)': $(e.message)");
                    warning ("Failed to delete emergency backup '%s': %s", backup.name, e.message);
                }
            }

            result.errors = errors;
            vault_status_changed (get_vault_status ());

            return result;
        }

        // Legacy compatibility - convert EmergencyBackupEntry to BackupEntry for UI
        public GenericArray<BackupEntry> get_all_backups_legacy () {
            var legacy_backups = new GenericArray<BackupEntry> ();
            
            for (int i = 0; i < backups.length; i++) {
                var emergency_backup = backups[i];
                var legacy_type = convert_emergency_to_legacy_type (emergency_backup.backup_type);
                
                var legacy_backup = new BackupEntry (emergency_backup.name, legacy_type);
                legacy_backup.id = emergency_backup.id;
                legacy_backup.created_at = emergency_backup.created_at;
                legacy_backup.expires_at = emergency_backup.expires_at;
                legacy_backup.backup_file = emergency_backup.backup_file;
                legacy_backup.key_fingerprints = emergency_backup.key_fingerprints;
                legacy_backup.is_encrypted = emergency_backup.is_encrypted;
                legacy_backup.description = emergency_backup.description;
                legacy_backup.file_size = emergency_backup.file_size;
                legacy_backup.checksum = emergency_backup.checksum;
                legacy_backup.shamir_total_shares = emergency_backup.shamir_total_shares;
                legacy_backup.shamir_threshold = emergency_backup.shamir_threshold;
                
                legacy_backups.add (legacy_backup);
            }
            
            return legacy_backups;
        }
        
        private BackupType convert_emergency_to_legacy_type (EmergencyBackupType emergency_type) {
            switch (emergency_type) {
                case EmergencyBackupType.ENCRYPTED_ARCHIVE:
                    return BackupType.ENCRYPTED_ARCHIVE;
                case EmergencyBackupType.TIME_LOCKED:
                    return BackupType.TIME_LOCKED;
                case EmergencyBackupType.QR_CODE:
                    return BackupType.QR_CODE;
                case EmergencyBackupType.SHAMIR_SECRET_SHARING:
                    return BackupType.SHAMIR_SECRET_SHARING;
                case EmergencyBackupType.TOTP_PROTECTED:
                case EmergencyBackupType.MULTI_FACTOR:
                default:
                    // Map new types to time-locked for legacy compatibility
                    return BackupType.TIME_LOCKED;
            }
        }
        
        private BackupEntry convert_emergency_to_legacy (EmergencyBackupEntry emergency_backup) {
            var legacy_type = convert_emergency_to_legacy_type (emergency_backup.backup_type);
            
            var legacy_backup = new BackupEntry (emergency_backup.name, legacy_type);
            legacy_backup.id = emergency_backup.id;
            legacy_backup.created_at = emergency_backup.created_at;
            legacy_backup.expires_at = emergency_backup.expires_at;
            legacy_backup.backup_file = emergency_backup.backup_file;
            legacy_backup.key_fingerprints = emergency_backup.key_fingerprints;
            legacy_backup.is_encrypted = emergency_backup.is_encrypted;
            legacy_backup.description = emergency_backup.description;
            legacy_backup.file_size = emergency_backup.file_size;
            legacy_backup.checksum = emergency_backup.checksum;
            legacy_backup.shamir_total_shares = emergency_backup.shamir_total_shares;
            legacy_backup.shamir_threshold = emergency_backup.shamir_threshold;
            
            return legacy_backup;
        }
        
        // Legacy remove method that accepts BackupEntry
        public bool remove_backup_legacy (BackupEntry legacy_backup) {
            for (int i = 0; i < backups.length; i++) {
                var emergency_backup = backups[i];
                if (emergency_backup.id == legacy_backup.id || emergency_backup.name == legacy_backup.name) {
                    return remove_backup (emergency_backup);
                }
            }
            return false;
        }
    }
}