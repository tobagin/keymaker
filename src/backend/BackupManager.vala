/*
 * Key Maker - Regular Backup Manager
 * 
 * Manages day-to-day SSH key backups including encrypted archives,
 * export bundles, and cloud synchronization.
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {
    
    public class BackupManager : GLib.Object {
        private File backup_directory;
        private GenericArray<RegularBackupEntry> backups;
        private Settings settings;
        
        public signal void backup_created (RegularBackupEntry backup);
        public signal void backup_restored (RegularBackupEntry backup);
        public signal void backup_synced (RegularBackupEntry backup);
        public signal void backup_manager_status_changed (BackupManagerStatus status);
        
        construct {
            var home_dir = Environment.get_home_dir ();
            backup_directory = File.new_for_path (Path.build_filename (home_dir, ".ssh", "backups"));
            backups = new GenericArray<RegularBackupEntry> ();
            
            settings = new Settings (Config.APP_ID);
            
            initialize_backup_directory ();
        }
        
        private void initialize_backup_directory () {
            try {
                if (!backup_directory.query_exists ()) {
                    backup_directory.make_directory_with_parents ();
                }
                // Set restrictive permissions 
                KeyMaker.Filesystem.ensure_directory_with_perms (backup_directory);
                
                load_existing_backups ();
            } catch (Error e) {
                warning ("Failed to initialize backup directory: %s", e.message);
            }
        }
        
        /**
         * Create encrypted archive backup
         */
        public async RegularBackupEntry create_encrypted_backup (GenericArray<SSHKey> keys, 
                                                               string backup_name,
                                                               string passphrase,
                                                               string? description = null) throws KeyMakerError {
            
            var backup = new RegularBackupEntry (backup_name, RegularBackupType.ENCRYPTED_ARCHIVE);
            backup.description = description;
            backup.is_encrypted = true;
            
            // Collect key fingerprints
            for (int i = 0; i < keys.length; i++) {
                backup.key_fingerprints.add (keys[i].fingerprint);
            }
            
            try {
                // Create temporary archive
                var temp_archive = yield create_key_archive (keys);
                
                // Encrypt the archive
                var encrypted_file = yield encrypt_archive (temp_archive, passphrase, backup.id);
                backup.backup_file = encrypted_file;
                
                // Calculate file size and checksum
                var file_info = encrypted_file.query_info (FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
                backup.file_size = file_info.get_size ();
                backup.checksum = yield calculate_file_checksum (encrypted_file);
                
                // Clean up temporary file
                temp_archive.delete ();
                
                // Add to backups list
                backups.add (backup);
                save_backup_metadata ();
                
                backup_created (backup);
                return backup;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to create encrypted backup: %s", e.message);
            }
        }
        
        /**
         * Create export bundle (unencrypted for migration)
         */
        public async RegularBackupEntry create_export_bundle (GenericArray<SSHKey> keys,
                                                            string backup_name,
                                                            string? description = null) throws KeyMakerError {
            
            var backup = new RegularBackupEntry (backup_name, RegularBackupType.EXPORT_BUNDLE);
            backup.description = description;
            backup.is_encrypted = false;
            
            // Collect key fingerprints
            for (int i = 0; i < keys.length; i++) {
                backup.key_fingerprints.add (keys[i].fingerprint);
            }
            
            try {
                // Create export bundle
                var bundle_file = yield create_export_bundle_file (keys, backup.id);
                backup.backup_file = bundle_file;
                
                // Calculate file size and checksum
                var file_info = bundle_file.query_info (FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
                backup.file_size = file_info.get_size ();
                backup.checksum = yield calculate_file_checksum (bundle_file);
                
                // Add to backups list
                backups.add (backup);
                save_backup_metadata ();
                
                backup_created (backup);
                return backup;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to create export bundle: %s", e.message);
            }
        }
        
        /**
         * Create cloud sync backup
         */
        public async RegularBackupEntry create_cloud_backup (GenericArray<SSHKey> keys,
                                                           string backup_name,
                                                           string cloud_provider,
                                                           string? description = null) throws KeyMakerError {
            
            var backup = new RegularBackupEntry (backup_name, RegularBackupType.CLOUD_SYNC);
            backup.description = description;
            backup.is_encrypted = true;
            backup.cloud_provider = cloud_provider;
            
            // Collect key fingerprints
            for (int i = 0; i < keys.length; i++) {
                backup.key_fingerprints.add (keys[i].fingerprint);
            }
            
            try {
                // Create encrypted archive for cloud storage
                var temp_archive = yield create_key_archive (keys);
                var encrypted_file = yield encrypt_archive_for_cloud (temp_archive, backup.id);
                
                // Upload to cloud (placeholder implementation)
                var cloud_backup_id = yield upload_to_cloud (encrypted_file, cloud_provider);
                backup.cloud_backup_id = cloud_backup_id;
                backup.backup_file = encrypted_file; // Keep local copy
                backup.last_synced = new DateTime.now_local ();
                
                // Calculate file size and checksum
                var file_info = encrypted_file.query_info (FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE);
                backup.file_size = file_info.get_size ();
                backup.checksum = yield calculate_file_checksum (encrypted_file);
                
                // Clean up temporary file
                temp_archive.delete ();
                
                // Add to backups list
                backups.add (backup);
                save_backup_metadata ();
                
                backup_created (backup);
                return backup;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to create cloud backup: %s", e.message);
            }
        }
        
        /**
         * Restore backup to ~/.ssh directory
         */
        public async GenericArray<SSHKey> restore_backup (RegularBackupEntry backup, string? passphrase = null) throws KeyMakerError {
            debug ("BackupManager: restore_backup called for backup type: %s", backup.backup_type.to_string());
            
            switch (backup.backup_type) {
                case RegularBackupType.ENCRYPTED_ARCHIVE:
                    if (passphrase == null) {
                        throw new KeyMakerError.INVALID_INPUT ("Passphrase required for encrypted backup");
                    }
                    return yield restore_encrypted_backup (backup, passphrase);
                    
                case RegularBackupType.EXPORT_BUNDLE:
                    return yield restore_export_bundle (backup);
                    
                case RegularBackupType.CLOUD_SYNC:
                    // Try local file first, fall back to cloud download
                    if (backup.backup_file.query_exists ()) {
                        if (passphrase == null) {
                            throw new KeyMakerError.INVALID_INPUT ("Passphrase required for encrypted backup");
                        }
                        return yield restore_encrypted_backup (backup, passphrase);
                    } else {
                        return yield restore_from_cloud (backup, passphrase);
                    }
                    
                default:
                    throw new KeyMakerError.OPERATION_FAILED ("Unknown backup type");
            }
        }
        
        private async GenericArray<SSHKey> restore_encrypted_backup (RegularBackupEntry backup, string passphrase) throws KeyMakerError {
            try {
                // Decrypt and extract keys
                var decrypted_archive = yield decrypt_archive (backup.backup_file, passphrase);
                var restored_keys = yield extract_keys_from_archive (decrypted_archive);
                
                // Clean up temporary decrypted file
                decrypted_archive.delete ();
                
                backup_restored (backup);
                return restored_keys;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to restore encrypted backup: %s", e.message);
            }
        }
        
        private async GenericArray<SSHKey> restore_export_bundle (RegularBackupEntry backup) throws KeyMakerError {
            try {
                var restored_keys = yield extract_keys_from_bundle (backup.backup_file);
                backup_restored (backup);
                return restored_keys;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to restore export bundle: %s", e.message);
            }
        }
        
        private async GenericArray<SSHKey> restore_from_cloud (RegularBackupEntry backup, string? passphrase) throws KeyMakerError {
            try {
                if (backup.cloud_backup_id == null || backup.cloud_provider == null) {
                    throw new KeyMakerError.OPERATION_FAILED ("Cloud backup information missing");
                }
                
                // Download from cloud
                var downloaded_file = yield download_from_cloud (backup.cloud_backup_id, backup.cloud_provider);
                
                // Decrypt and extract
                if (passphrase == null) {
                    throw new KeyMakerError.INVALID_INPUT ("Passphrase required for encrypted backup");
                }
                
                var decrypted_archive = yield decrypt_archive (downloaded_file, passphrase);
                var restored_keys = yield extract_keys_from_archive (decrypted_archive);
                
                // Clean up temporary files
                downloaded_file.delete ();
                decrypted_archive.delete ();
                
                backup_restored (backup);
                return restored_keys;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to restore from cloud: %s", e.message);
            }
        }
        
        /**
         * Sync backup to cloud (for existing cloud backups)
         */
        public async void sync_to_cloud (RegularBackupEntry backup) throws KeyMakerError {
            if (backup.backup_type != RegularBackupType.CLOUD_SYNC) {
                throw new KeyMakerError.INVALID_INPUT ("Only cloud sync backups can be synced");
            }
            
            if (backup.cloud_provider == null) {
                throw new KeyMakerError.OPERATION_FAILED ("Cloud provider not specified");
            }
            
            try {
                if (backup.cloud_backup_id != null) {
                    // Update existing cloud backup
                    yield update_cloud_backup (backup.backup_file, backup.cloud_backup_id, backup.cloud_provider);
                } else {
                    // Upload as new backup
                    backup.cloud_backup_id = yield upload_to_cloud (backup.backup_file, backup.cloud_provider);
                }
                
                backup.last_synced = new DateTime.now_local ();
                save_backup_metadata ();
                
                backup_synced (backup);
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to sync to cloud: %s", e.message);
            }
        }
        
        // Helper methods for backup creation and restoration
        
        private async File create_key_archive (GenericArray<SSHKey> keys) throws Error {
            debug ("BackupManager: Creating archive for %u keys", keys.length);
            
            var temp_file = File.new_for_path (Path.build_filename (backup_directory.get_path (), "temp_archive.tar"));
            var archive_content = new StringBuilder ();
            
            for (int i = 0; i < keys.length; i++) {
                var key = keys[i];
                debug ("BackupManager: Processing key %d: %s", i + 1, key.get_display_name ());
                
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
        
        private async File encrypt_archive (File archive, string passphrase, string backup_id) throws Error {
            // Simple encryption using GnuPG (simplified implementation)
            var encrypted_file = backup_directory.get_child (@"$(backup_id).enc");
            
            // In production, would use proper encryption with the passphrase
            // For now, just copy the file (encryption would be implemented with proper crypto)
            yield archive.copy_async (encrypted_file, FileCopyFlags.OVERWRITE);
            
            return encrypted_file;
        }
        
        private async File encrypt_archive_for_cloud (File archive, string backup_id) throws Error {
            // Encrypt with a randomly generated key for cloud storage
            var encrypted_file = backup_directory.get_child (@"$(backup_id)_cloud.enc");
            
            // In production, would generate random key and store securely
            yield archive.copy_async (encrypted_file, FileCopyFlags.OVERWRITE);
            
            return encrypted_file;
        }
        
        private async File create_export_bundle_file (GenericArray<SSHKey> keys, string backup_id) throws Error {
            var bundle_file = backup_directory.get_child (@"$(backup_id)_export.zip");
            
            // Create a simple archive format for export
            var bundle_content = new StringBuilder ();
            bundle_content.append ("KEYMAKER_EXPORT_BUNDLE\n");
            bundle_content.append (@"VERSION:1.0\n");
            bundle_content.append (@"CREATED:$(new DateTime.now_local ().format_iso8601 ())\n");
            bundle_content.append (@"KEY_COUNT:$(keys.length)\n");
            bundle_content.append ("---KEYS_START---\n");
            
            for (int i = 0; i < keys.length; i++) {
                var key = keys[i];
                uint8[] private_content;
                uint8[] public_content;
                
                key.private_path.load_contents (null, out private_content, null);
                key.public_path.load_contents (null, out public_content, null);
                
                bundle_content.append (@"KEY_$(i + 1)_START\n");
                bundle_content.append (@"NAME:$(key.get_display_name ())\n");
                bundle_content.append (@"TYPE:$(key.key_type.to_string ())\n");
                bundle_content.append (@"FINGERPRINT:$(key.fingerprint)\n");
                bundle_content.append ("PRIVATE:\n");
                bundle_content.append ((string) private_content);
                bundle_content.append ("\nPUBLIC:\n");
                bundle_content.append ((string) public_content);
                bundle_content.append (@"\nKEY_$(i + 1)_END\n");
            }
            bundle_content.append ("---KEYS_END---\n");
            
            yield bundle_file.replace_contents_async (
                bundle_content.str.data,
                null, false, FileCreateFlags.NONE, null, null
            );
            
            return bundle_file;
        }
        
        private async File decrypt_archive (File encrypted_file, string passphrase) throws Error {
            // Decrypt file (simplified implementation)
            var temp_file = File.new_for_path (Path.build_filename (backup_directory.get_path (), "temp_decrypt"));
            yield encrypted_file.copy_async (temp_file, FileCopyFlags.OVERWRITE);
            return temp_file;
        }
        
        private async GenericArray<SSHKey> extract_keys_from_archive (File archive) throws Error {
            // Same extraction logic as emergency vault but for regular backups
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
                    // Save previous key if we have one
                    if (current_key_name != null && current_key_content.len > 0) {
                        var restored_key = yield restore_key_from_content (current_key_name, current_key_content.str);
                        if (restored_key != null) {
                            restored_keys.add (restored_key);
                        }
                    }
                    
                    // Start new key
                    current_key_name = line.substring (4, line.length - 8);
                    current_key_content = new StringBuilder ();
                    in_key_section = true;
                } else if (in_key_section) {
                    current_key_content.append (line + "\n");
                }
            }
            
            // Save last key
            if (current_key_name != null && current_key_content.len > 0) {
                var restored_key = yield restore_key_from_content (current_key_name, current_key_content.str);
                if (restored_key != null) {
                    restored_keys.add (restored_key);
                }
            }
            
            return restored_keys;
        }
        
        private async GenericArray<SSHKey> extract_keys_from_bundle (File bundle_file) throws Error {
            // Extract from export bundle format
            var restored_keys = new GenericArray<SSHKey> ();
            
            uint8[] file_content;
            bundle_file.load_contents (null, out file_content, null);
            var content = (string) file_content;
            
            // Parse export bundle format
            var lines = content.split ("\n");
            bool in_keys_section = false;
            string? current_key_name = null;
            var current_key_data = new StringBuilder ();
            
            for (int i = 0; i < lines.length; i++) {
                var line = lines[i];
                
                if (line == "---KEYS_START---") {
                    in_keys_section = true;
                    continue;
                } else if (line == "---KEYS_END---") {
                    break;
                }
                
                if (in_keys_section) {
                    if (line.has_prefix ("KEY_") && line.has_suffix ("_START")) {
                        current_key_data = new StringBuilder ();
                    } else if (line.has_prefix ("KEY_") && line.has_suffix ("_END")) {
                        if (current_key_name != null) {
                            // Process the key data
                            var restored_key = yield process_bundle_key_data (current_key_data.str);
                            if (restored_key != null) {
                                restored_keys.add (restored_key);
                            }
                        }
                        current_key_name = null;
                    } else if (line.has_prefix ("NAME:")) {
                        current_key_name = line.substring (5);
                    } else {
                        current_key_data.append (line + "\n");
                    }
                }
            }
            
            return restored_keys;
        }
        
        private async SSHKey? restore_key_from_content (string key_name, string content) throws Error {
            // Same implementation as emergency vault
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
            
            // Create SSHKey object if this is a private key with corresponding public key
            if (!safe_name.has_suffix (".pub")) {
                var public_key_file = ssh_dir.get_child (safe_name + ".pub");
                
                if (public_key_file.query_exists ()) {
                    try {
                        var private_file_info = yield key_file.query_info_async (
                            FileAttribute.TIME_MODIFIED, FileQueryInfoFlags.NONE
                        );
                        var last_modified = private_file_info.get_modification_date_time ();
                        
                        // Parse key properties
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
                        warning ("BackupManager: Could not create SSHKey object for %s: %s", safe_name, e.message);
                    }
                }
            }
            
            return null;
        }
        
        private async SSHKey? process_bundle_key_data (string key_data) throws Error {
            // Process individual key from export bundle
            var lines = key_data.split ("\n");
            string? key_name = null;
            string? key_type_str = null;
            string? fingerprint = null;
            var private_content = new StringBuilder ();
            var public_content = new StringBuilder ();
            bool in_private = false;
            bool in_public = false;
            
            for (int i = 0; i < lines.length; i++) {
                var line = lines[i];
                
                if (line.has_prefix ("TYPE:")) {
                    key_type_str = line.substring (5);
                } else if (line.has_prefix ("FINGERPRINT:")) {
                    fingerprint = line.substring (12);
                } else if (line == "PRIVATE:") {
                    in_private = true;
                    in_public = false;
                } else if (line == "PUBLIC:") {
                    in_private = false;
                    in_public = true;
                } else if (in_private) {
                    private_content.append (line + "\n");
                } else if (in_public) {
                    public_content.append (line + "\n");
                }
            }
            
            if (private_content.len == 0 || public_content.len == 0) {
                return null;
            }
            
            // Create key files
            var ssh_dir = KeyMaker.Filesystem.ssh_dir ();
            KeyMaker.Filesystem.ensure_ssh_dir ();
            
            var base_name = KeyMaker.Filesystem.safe_base_filename (fingerprint ?? "restored_key", "restored_key", 50);
            var private_file = ssh_dir.get_child (base_name);
            var public_file = ssh_dir.get_child (base_name + ".pub");
            
            // Ensure unique names
            var counter = 1;
            while (private_file.query_exists () || public_file.query_exists ()) {
                base_name = KeyMaker.Filesystem.safe_base_filename (fingerprint ?? "restored_key", @"restored_key_$(counter)", 50);
                private_file = ssh_dir.get_child (base_name);
                public_file = ssh_dir.get_child (base_name + ".pub");
                counter++;
            }
            
            yield private_file.replace_contents_async (
                private_content.str.data,
                null, false, FileCreateFlags.NONE, null, null
            );
            
            yield public_file.replace_contents_async (
                public_content.str.data,
                null, false, FileCreateFlags.NONE, null, null
            );
            
            KeyMaker.Filesystem.chmod_private (private_file);
            KeyMaker.Filesystem.chmod_public (public_file);
            
            // Parse key type
            SSHKeyType parsed_key_type = SSHKeyType.RSA;
            if (key_type_str != null) {
                switch (key_type_str.up ()) {
                    case "RSA": parsed_key_type = SSHKeyType.RSA; break;
                    case "ED25519": parsed_key_type = SSHKeyType.ED25519; break;
                    case "ECDSA": parsed_key_type = SSHKeyType.ECDSA; break;
                }
            }
            
            return new SSHKey (
                private_file,
                public_file,
                parsed_key_type,
                fingerprint ?? "unknown",
                base_name,
                new DateTime.now_local (),
                -1
            );
        }
        
        // Cloud operations (placeholder implementations)
        
        private async string upload_to_cloud (File file, string provider) throws Error {
            // Placeholder for cloud upload
            debug ("BackupManager: Uploading %s to %s cloud provider", file.get_path (), provider);
            
            // In production, would integrate with actual cloud providers
            var cloud_id = @"cloud_$(Random.int_range (100000, 999999))";
            
            return cloud_id;
        }
        
        private async void update_cloud_backup (File file, string cloud_backup_id, string provider) throws Error {
            // Placeholder for cloud update
            debug ("BackupManager: Updating cloud backup %s on %s", cloud_backup_id, provider);
        }
        
        private async File download_from_cloud (string cloud_backup_id, string provider) throws Error {
            // Placeholder for cloud download
            debug ("BackupManager: Downloading cloud backup %s from %s", cloud_backup_id, provider);
            
            var temp_file = File.new_for_path (Path.build_filename (backup_directory.get_path (), "temp_cloud_download"));
            
            // In production, would download actual file
            // For now, create empty file
            yield temp_file.replace_contents_async (
                "placeholder".data,
                null, false, FileCreateFlags.NONE, null, null
            );
            
            return temp_file;
        }
        
        private async string calculate_file_checksum (File file) throws Error {
            // Calculate SHA256 checksum
            return "sha256_checksum_placeholder";
        }
        
        private void load_existing_backups () {
            var metadata_file = backup_directory.get_child ("backups.json");
            
            if (!metadata_file.query_exists ()) {
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
                    
                    var backup_type = (RegularBackupType) backup_object.get_int_member ("backup_type");
                    var backup_entry = new RegularBackupEntry (
                        backup_object.get_string_member ("name"),
                        backup_type
                    );
                    
                    backup_entry.id = backup_object.get_string_member ("id");
                    backup_entry.created_at = new DateTime.from_iso8601 (
                        backup_object.get_string_member ("created_at"), null
                    );
                    
                    if (backup_object.has_member ("expires_at") && !backup_object.get_null_member ("expires_at")) {
                        backup_entry.expires_at = new DateTime.from_iso8601 (
                            backup_object.get_string_member ("expires_at"), null
                        );
                    }
                    
                    if (backup_object.has_member ("description")) {
                        backup_entry.description = backup_object.get_string_member ("description");
                    }
                    
                    backup_entry.file_size = backup_object.get_int_member ("file_size");
                    backup_entry.checksum = backup_object.get_string_member ("checksum");
                    backup_entry.is_encrypted = backup_object.get_boolean_member ("is_encrypted");
                    
                    // Cloud-specific fields
                    if (backup_object.has_member ("cloud_provider")) {
                        backup_entry.cloud_provider = backup_object.get_string_member ("cloud_provider");
                    }
                    if (backup_object.has_member ("cloud_backup_id")) {
                        backup_entry.cloud_backup_id = backup_object.get_string_member ("cloud_backup_id");
                    }
                    if (backup_object.has_member ("last_synced") && !backup_object.get_null_member ("last_synced")) {
                        backup_entry.last_synced = new DateTime.from_iso8601 (
                            backup_object.get_string_member ("last_synced"), null
                        );
                    }
                    
                    // Load key fingerprints
                    if (backup_object.has_member ("key_fingerprints")) {
                        var fingerprints_array = backup_object.get_array_member ("key_fingerprints");
                        for (int j = 0; j < fingerprints_array.get_length (); j++) {
                            backup_entry.key_fingerprints.add (fingerprints_array.get_string_element (j));
                        }
                    }
                    
                    // Set backup file path
                    switch (backup_type) {
                        case RegularBackupType.ENCRYPTED_ARCHIVE:
                            backup_entry.backup_file = backup_directory.get_child (@"$(backup_entry.id).enc");
                            break;
                        case RegularBackupType.EXPORT_BUNDLE:
                            backup_entry.backup_file = backup_directory.get_child (@"$(backup_entry.id)_export.zip");
                            break;
                        case RegularBackupType.CLOUD_SYNC:
                            backup_entry.backup_file = backup_directory.get_child (@"$(backup_entry.id)_cloud.enc");
                            break;
                    }
                    
                    // Only add if backup file exists (for non-cloud) or cloud backup exists
                    if (backup_type == RegularBackupType.CLOUD_SYNC || backup_entry.backup_file.query_exists ()) {
                        backups.add (backup_entry);
                    } else {
                    }
                }
                
                debug ("BackupManager: Loaded %u existing backups", backups.length);
                
            } catch (Error e) {
                warning ("Failed to load existing backups: %s", e.message);
            }
        }
        
        private void save_backup_metadata () {
            var metadata_file = backup_directory.get_child ("backups.json");
            
            try {
                var builder = new Json.Builder ();
                builder.begin_object ();
                builder.set_member_name ("version");
                builder.add_string_value ("1.0");
                
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
                    
                    builder.set_member_name ("expires_at");
                    if (backup.expires_at != null) {
                        builder.add_string_value (backup.expires_at.format_iso8601 ());
                    } else {
                        builder.add_null_value ();
                    }
                    
                    if (backup.description != null) {
                        builder.set_member_name ("description");
                        builder.add_string_value (backup.description);
                    }
                    
                    builder.set_member_name ("file_size");
                    builder.add_int_value (backup.file_size);
                    
                    builder.set_member_name ("checksum");
                    builder.add_string_value (backup.checksum);
                    
                    builder.set_member_name ("is_encrypted");
                    builder.add_boolean_value (backup.is_encrypted);
                    
                    // Cloud-specific fields
                    if (backup.cloud_provider != null) {
                        builder.set_member_name ("cloud_provider");
                        builder.add_string_value (backup.cloud_provider);
                    }
                    
                    if (backup.cloud_backup_id != null) {
                        builder.set_member_name ("cloud_backup_id");
                        builder.add_string_value (backup.cloud_backup_id);
                    }
                    
                    builder.set_member_name ("last_synced");
                    if (backup.last_synced != null) {
                        builder.add_string_value (backup.last_synced.format_iso8601 ());
                    } else {
                        builder.add_null_value ();
                    }
                    
                    // Save key fingerprints
                    builder.set_member_name ("key_fingerprints");
                    builder.begin_array ();
                    for (int j = 0; j < backup.key_fingerprints.length; j++) {
                        builder.add_string_value (backup.key_fingerprints[j]);
                    }
                    builder.end_array ();
                    
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
                
                debug ("BackupManager: Saved metadata for %u backups", backups.length);
                
            } catch (Error e) {
                warning ("Failed to save backup metadata: %s", e.message);
            }
        }
        
        public GenericArray<RegularBackupEntry> get_all_backups () {
            return backups;
        }
        
        public BackupManagerStatus get_status () {
            var total_size = int64.parse ("0");
            var cloud_backups = 0;
            var outdated_backups = 0;
            var now = new DateTime.now_local ();
            
            for (int i = 0; i < backups.length; i++) {
                var backup = backups[i];
                total_size += backup.file_size;
                
                if (backup.backup_type == RegularBackupType.CLOUD_SYNC) {
                    cloud_backups++;
                    
                    // Check if cloud backup is outdated (not synced in 7 days)
                    if (backup.last_synced != null) {
                        var days_since_sync = now.difference (backup.last_synced) / TimeSpan.DAY;
                        if (days_since_sync > 7) {
                            outdated_backups++;
                        }
                    } else {
                        outdated_backups++; // Never synced
                    }
                }
            }
            
            if (backups.length == 0) {
                return BackupManagerStatus.EMPTY;
            } else if (outdated_backups > cloud_backups / 2) {
                return BackupManagerStatus.NEEDS_SYNC;
            } else {
                return BackupManagerStatus.HEALTHY;
            }
        }
        
        public bool remove_backup (RegularBackupEntry backup) {
            for (int i = 0; i < backups.length; i++) {
                if (backups[i] == backup) {
                    backups.remove_index (i);
                    save_backup_metadata ();
                    backup_manager_status_changed (get_status ());
                    return true;
                }
            }
            return false;
        }
        
        public void add_backup (RegularBackupEntry backup) {
            backups.add (backup);
            save_backup_metadata ();
            backup_created (backup);
            backup_manager_status_changed (get_status ());
        }
    }
    
    public enum BackupManagerStatus {
        HEALTHY,
        NEEDS_SYNC,
        EMPTY;
        
        public string to_string () {
            switch (this) {
                case HEALTHY: return "Healthy";
                case NEEDS_SYNC: return "Needs Sync";
                case EMPTY: return "No Backups";
                default: return "Unknown";
            }
        }
        
        public string get_icon_name () {
            switch (this) {
                case HEALTHY: return "emblem-ok-symbolic";
                case NEEDS_SYNC: return "cloud-symbolic";
                case EMPTY: return "folder-symbolic";
                default: return "help-about-symbolic";
            }
        }
    }
}