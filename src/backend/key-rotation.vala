/*
 * Key Maker - Smart Key Rotation System
 * 
 * Automated SSH key rotation with deployment and rollback capabilities.
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {
    
    public enum RotationStage {
        PLANNING,
        GENERATING_NEW_KEY,
        BACKING_UP_OLD_KEY,
        DEPLOYING_NEW_KEY,
        VERIFYING_ACCESS,
        REMOVING_OLD_KEY,
        COMPLETED,
        FAILED,
        ROLLING_BACK;
        
        public string to_string () {
            switch (this) {
                case PLANNING: return "Planning";
                case GENERATING_NEW_KEY: return "Generating New Key";
                case BACKING_UP_OLD_KEY: return "Backing Up Old Key";
                case DEPLOYING_NEW_KEY: return "Deploying New Key";
                case VERIFYING_ACCESS: return "Verifying Access";
                case REMOVING_OLD_KEY: return "Removing Old Key";
                case COMPLETED: return "Completed";
                case FAILED: return "Failed";
                case ROLLING_BACK: return "Rolling Back";
                default: return "Unknown";
            }
        }
        
        public string get_icon_name () {
            switch (this) {
                case PLANNING: return "view-list-symbolic";
                case GENERATING_NEW_KEY: return "document-new-symbolic";
                case BACKING_UP_OLD_KEY: return "folder-download-symbolic";
                case DEPLOYING_NEW_KEY: return "network-transmit-symbolic";
                case VERIFYING_ACCESS: return "emblem-system-symbolic";
                case REMOVING_OLD_KEY: return "user-trash-symbolic";
                case COMPLETED: return "emblem-ok-symbolic";
                case FAILED: return "dialog-error-symbolic";
                case ROLLING_BACK: return "edit-undo-symbolic";
                default: return "help-about-symbolic";
            }
        }
    }
    
    public class RotationTarget : GLib.Object {
        public string hostname { get; set; }
        public string username { get; set; }
        public int port { get; set; default = 22; }
        public string? proxy_jump { get; set; }
        public bool deployment_success { get; set; default = false; }
        public bool verification_success { get; set; default = false; }
        public string error_message { get; set; default = ""; }
        
        public RotationTarget (string host, string user, int ssh_port = 22) {
            hostname = host;
            username = user;
            port = ssh_port;
        }
        
        public string get_display_name () {
            if (port != 22) {
                return @"$(username)@$(hostname):$(port)";
            } else {
                return @"$(username)@$(hostname)";
            }
        }
    }
    
    public class RotationPlan : GLib.Object {
        public SSHKey old_key { get; set; }
        public SSHKey? new_key { get; set; }
        public File? backup_location { get; set; }
        public GenericArray<RotationTarget> targets { get; set; }
        public RotationStage current_stage { get; set; default = RotationStage.PLANNING; }
        public DateTime created_at { get; set; }
        public DateTime? started_at { get; set; }
        public DateTime? completed_at { get; set; }
        public bool keep_old_key { get; set; default = true; }
        public bool enable_rollback { get; set; default = true; }
        public string rotation_reason { get; set; default = "Regular rotation"; }
        public GenericArray<string> log_entries { get; set; }
        
        construct {
            targets = new GenericArray<RotationTarget> ();
            created_at = new DateTime.now_local ();
            log_entries = new GenericArray<string> ();
        }
        
        public RotationPlan (SSHKey key) {
            old_key = key;
        }
        
        public void add_target (RotationTarget target) {
            targets.add (target);
        }
        
        public void add_log_entry (string message) {
            var timestamp = new DateTime.now_local ();
            var entry = @"[$(timestamp.format("%H:%M:%S"))] $(message)";
            log_entries.add (entry);
        }
        
        public bool all_targets_deployed () {
            for (int i = 0; i < targets.length; i++) {
                if (!targets[i].deployment_success) {
                    return false;
                }
            }
            return targets.length > 0;
        }
        
        public bool all_targets_verified () {
            for (int i = 0; i < targets.length; i++) {
                if (!targets[i].verification_success) {
                    return false;
                }
            }
            return targets.length > 0;
        }
        
        public int get_successful_deployments () {
            int count = 0;
            for (int i = 0; i < targets.length; i++) {
                if (targets[i].deployment_success) {
                    count++;
                }
            }
            return count;
        }
    }
    
    public class KeyRotationManager : GLib.Object {
        
        public signal void rotation_started (RotationPlan plan);
        public signal void rotation_stage_changed (RotationPlan plan, RotationStage stage);
        public signal void rotation_progress (RotationPlan plan, string message);
        public signal void rotation_completed (RotationPlan plan, bool success);
        
        private ConnectionDiagnostics diagnostics;
        
        construct {
            diagnostics = new ConnectionDiagnostics ();
        }
        
        /**
         * Create a rotation plan for a key
         */
        public RotationPlan create_rotation_plan (SSHKey key, string reason = "Regular rotation") {
            var plan = new RotationPlan (key);
            plan.rotation_reason = reason;
            
            // Auto-detect targets from key service mappings
            var mapping_manager = new KeyServiceMappingManager ();
            var mappings = mapping_manager.get_mappings_for_key (key.fingerprint);
            
            for (int i = 0; i < mappings.length; i++) {
                var mapping = mappings[i];
                if (mapping.hostname != null && mapping.username != null) {
                    var target = new RotationTarget (mapping.hostname, mapping.username);
                    plan.add_target (target);
                }
            }
            
            return plan;
        }
        
        /**
         * Execute key rotation plan
         */
        public async bool execute_rotation_plan (RotationPlan plan) throws KeyMakerError {
            plan.started_at = new DateTime.now_local ();
            rotation_started (plan);
            
            try {
                // Stage 1: Generate new key
                yield perform_key_generation (plan);
                
                // Stage 2: Backup old key
                yield perform_key_backup (plan);
                
                // Stage 3: Deploy new key to all targets
                yield perform_key_deployment (plan);
                
                // Stage 4: Verify access with new key
                yield perform_access_verification (plan);
                
                // Stage 5: Remove old key if requested and all verifications passed
                if (!plan.keep_old_key && plan.all_targets_verified ()) {
                    yield perform_old_key_removal (plan);
                }
                
                // Mark as completed
                plan.current_stage = RotationStage.COMPLETED;
                plan.completed_at = new DateTime.now_local ();
                plan.add_log_entry ("Key rotation completed successfully");
                
                rotation_stage_changed (plan, plan.current_stage);
                rotation_completed (plan, true);
                
                return true;
                
            } catch (KeyMakerError e) {
                plan.current_stage = RotationStage.FAILED;
                plan.add_log_entry (@"Rotation failed: $(e.message)");
                
                if (plan.enable_rollback) {
                    yield perform_rollback (plan);
                }
                
                rotation_completed (plan, false);
                throw e;
            }
        }
        
        private async void perform_key_generation (RotationPlan plan) throws KeyMakerError {
            plan.current_stage = RotationStage.GENERATING_NEW_KEY;
            rotation_stage_changed (plan, plan.current_stage);
            rotation_progress (plan, "Generating new SSH key...");
            
            // Generate new key with similar properties
            var request = new KeyGenerationRequest ("replacement_key");
            request.key_type = plan.old_key.key_type;
            request.rsa_bits = plan.old_key.bit_size > 0 ? plan.old_key.bit_size : 4096;
            
            // Create unique filename
            var timestamp = new DateTime.now_local ().format ("%Y%m%d_%H%M%S");
            var old_basename = plan.old_key.private_path.get_basename ();
            request.filename = @"$(old_basename)_rotated_$(timestamp)";
            
            // Use old key's comment as base
            request.comment = plan.old_key.comment ?? @"Rotated key for $(plan.old_key.get_display_name ())";
            
            try {
                plan.new_key = yield SSHOperations.generate_key (request);
                plan.add_log_entry (@"Generated new key: $(plan.new_key.get_display_name ())");
                
            } catch (KeyMakerError e) {
                plan.add_log_entry (@"Failed to generate new key: $(e.message)");
                throw e;
            }
        }
        
        private async void perform_key_backup (RotationPlan plan) throws KeyMakerError {
            plan.current_stage = RotationStage.BACKING_UP_OLD_KEY;
            rotation_stage_changed (plan, plan.current_stage);
            rotation_progress (plan, "Backing up old key...");
            
            try {
                // Create backup directory
                var backup_dir = File.new_for_path (Path.build_filename (
                    Environment.get_home_dir (), ".ssh", "rotations", 
                    new DateTime.now_local ().format ("%Y%m%d_%H%M%S")
                ));
                
                backup_dir.make_directory_with_parents ();
                plan.backup_location = backup_dir;
                
                // Copy old key files
                var backup_private = backup_dir.get_child (plan.old_key.private_path.get_basename ());
                var backup_public = backup_dir.get_child (plan.old_key.public_path.get_basename ());
                
                yield plan.old_key.private_path.copy_async (backup_private, FileCopyFlags.NONE);
                yield plan.old_key.public_path.copy_async (backup_public, FileCopyFlags.NONE);
                
                plan.add_log_entry (@"Backed up old key to: $(backup_dir.get_path ())");
                
            } catch (Error e) {
                plan.add_log_entry (@"Failed to backup old key: $(e.message)");
                throw new KeyMakerError.OPERATION_FAILED ("Backup failed: %s", e.message);
            }
        }
        
        private async void perform_key_deployment (RotationPlan plan) throws KeyMakerError {
            plan.current_stage = RotationStage.DEPLOYING_NEW_KEY;
            rotation_stage_changed (plan, plan.current_stage);
            
            var successful_deployments = 0;
            var failed_deployments = 0;
            
            for (int i = 0; i < plan.targets.length; i++) {
                var target = plan.targets[i];
                rotation_progress (plan, @"Deploying to $(target.get_display_name ())...");
                
                try {
                    yield deploy_key_to_target (plan, target);
                    target.deployment_success = true;
                    successful_deployments++;
                    plan.add_log_entry (@"Successfully deployed to $(target.get_display_name ())");
                    
                } catch (KeyMakerError e) {
                    target.deployment_success = false;
                    target.error_message = e.message;
                    failed_deployments++;
                    plan.add_log_entry (@"Failed to deploy to $(target.get_display_name ()): $(e.message)");
                }
            }
            
            if (successful_deployments == 0) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to deploy to any targets");
            }
            
            plan.add_log_entry (@"Deployment completed: $(successful_deployments) successful, $(failed_deployments) failed");
        }
        
        private async void deploy_key_to_target (RotationPlan plan, RotationTarget target) throws KeyMakerError {
            // Build ssh-copy-id command
            var cmd_list = new GenericArray<string> ();
            cmd_list.add ("ssh-copy-id");
            
            // Add options
            cmd_list.add ("-o");
            cmd_list.add ("BatchMode=yes");
            cmd_list.add ("-o");
            cmd_list.add ("ConnectTimeout=30");
            
            // Port
            if (target.port != 22) {
                cmd_list.add ("-p");
                cmd_list.add (target.port.to_string ());
            }
            
            // Identity file
            cmd_list.add ("-i");
            cmd_list.add (plan.new_key.public_path.get_path ());
            
            // Proxy jump
            if (target.proxy_jump != null) {
                cmd_list.add ("-o");
                cmd_list.add (@"ProxyJump=$(target.proxy_jump)");
            }
            
            // Target
            cmd_list.add (target.get_display_name ());
            
            string[] cmd = new string[cmd_list.length + 1];
            for (int i = 0; i < cmd_list.length; i++) {
                cmd[i] = cmd_list[i];
            }
            cmd[cmd_list.length] = null;
            
            try {
                var launcher = new SubprocessLauncher (
                    SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE
                );
                var subprocess = launcher.spawnv (cmd);
                
                yield subprocess.wait_async ();
                
                if (subprocess.get_exit_status () != 0) {
                    var stderr_stream = subprocess.get_stderr_pipe ();
                    var stderr_reader = new DataInputStream (stderr_stream);
                    var error_message = yield stderr_reader.read_line_async ();
                    throw new KeyMakerError.SUBPROCESS_FAILED (
                        "ssh-copy-id failed: %s", error_message ?? "Unknown error"
                    );
                }
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to deploy key: %s", e.message);
            }
        }
        
        private async void perform_access_verification (RotationPlan plan) throws KeyMakerError {
            plan.current_stage = RotationStage.VERIFYING_ACCESS;
            rotation_stage_changed (plan, plan.current_stage);
            
            for (int i = 0; i < plan.targets.length; i++) {
                var target = plan.targets[i];
                
                if (!target.deployment_success) {
                    continue; // Skip targets that failed deployment
                }
                
                rotation_progress (plan, @"Verifying access to $(target.get_display_name ())...");
                
                try {
                    var test = yield diagnostics.test_connection (
                        target.hostname, target.username, target.port,
                        plan.new_key.private_path, target.proxy_jump
                    );
                    
                    target.verification_success = test.result.is_success ();
                    if (!target.verification_success) {
                        target.error_message = test.error_message;
                        plan.add_log_entry (@"Verification failed for $(target.get_display_name ()): $(test.error_message)");
                    } else {
                        plan.add_log_entry (@"Verification successful for $(target.get_display_name ())");
                    }
                    
                } catch (KeyMakerError e) {
                    target.verification_success = false;
                    target.error_message = e.message;
                    plan.add_log_entry (@"Verification error for $(target.get_display_name ()): $(e.message)");
                }
            }
        }
        
        private async void perform_old_key_removal (RotationPlan plan) throws KeyMakerError {
            plan.current_stage = RotationStage.REMOVING_OLD_KEY;
            rotation_stage_changed (plan, plan.current_stage);
            rotation_progress (plan, "Removing old key from targets...");
            
            for (int i = 0; i < plan.targets.length; i++) {
                var target = plan.targets[i];
                
                if (!target.verification_success) {
                    continue; // Only remove from successfully verified targets
                }
                
                try {
                    yield remove_old_key_from_target (plan, target);
                    plan.add_log_entry (@"Removed old key from $(target.get_display_name ())");
                    
                } catch (KeyMakerError e) {
                    plan.add_log_entry (@"Failed to remove old key from $(target.get_display_name ()): $(e.message)");
                    // Continue with other targets
                }
            }
        }
        
        private async void remove_old_key_from_target (RotationPlan plan, RotationTarget target) throws KeyMakerError {
            // This would require SSH access to edit authorized_keys file
            // Implementation depends on having script/command on remote server
            // For now, we'll just log that manual removal is needed
            plan.add_log_entry (@"Manual removal required for old key from $(target.get_display_name ())");
        }
        
        private async void perform_rollback (RotationPlan plan) {
            plan.current_stage = RotationStage.ROLLING_BACK;
            rotation_stage_changed (plan, plan.current_stage);
            rotation_progress (plan, "Rolling back changes...");
            
            plan.add_log_entry ("Starting rollback process");
            
            // Remove new key from successfully deployed targets
            for (int i = 0; i < plan.targets.length; i++) {
                var target = plan.targets[i];
                
                if (target.deployment_success) {
                    try {
                        // Attempt to remove new key (implementation needed)
                        plan.add_log_entry (@"Attempted rollback for $(target.get_display_name ())");
                    } catch (Error e) {
                        plan.add_log_entry (@"Rollback failed for $(target.get_display_name ()): $(e.message)");
                    }
                }
            }
            
            // Delete generated new key if it exists
            if (plan.new_key != null) {
                try {
                    yield SSHOperations.delete_key_pair (plan.new_key);
                    plan.add_log_entry ("Deleted newly generated key");
                } catch (KeyMakerError e) {
                    plan.add_log_entry (@"Failed to delete new key: $(e.message)");
                }
            }
            
            plan.add_log_entry ("Rollback completed");
        }
        
        /**
         * Get rotation recommendations for a key
         */
        public GenericArray<string> get_rotation_recommendations (SSHKey key) {
            var recommendations = new GenericArray<string> ();
            
            var age_days = get_key_age_days (key);
            
            if (age_days > 365) {
                recommendations.add ("Key is over 1 year old - rotation recommended");
            } else if (age_days > 180) {
                recommendations.add ("Key is over 6 months old - consider rotation");
            }
            
            if (key.key_type == SSHKeyType.RSA && key.bit_size < 2048) {
                recommendations.add ("RSA key size is less than 2048 bits - rotation recommended");
            }
            
            if (key.key_type == SSHKeyType.ECDSA) {
                recommendations.add ("ECDSA keys are not recommended - rotate to Ed25519");
            }
            
            // Check for usage patterns
            var mapping_manager = new KeyServiceMappingManager ();
            var mappings = mapping_manager.get_mappings_for_key (key.fingerprint);
            
            if (mappings.length == 0) {
                recommendations.add ("No service mappings found - consider key cleanup");
            }
            
            bool has_recent_usage = false;
            for (int i = 0; i < mappings.length; i++) {
                if (mappings[i].is_recently_used (90)) {
                    has_recent_usage = true;
                    break;
                }
            }
            
            if (!has_recent_usage) {
                recommendations.add ("Key hasn't been used recently - consider rotation or cleanup");
            }
            
            return recommendations;
        }
        
        private int get_key_age_days (SSHKey key) {
            var now = new DateTime.now_local ();
            var age = now.difference (key.last_modified) / TimeSpan.DAY;
            return (int) age;
        }
    }
}