/*
 * Key Maker - Key Rotation Rollback
 * 
 * Handles rollback operations when key rotation fails.
 */

namespace KeyMaker {
    
    public class RotationRollback {
        
        /**
         * Rollback a failed key rotation deployment
         */
        public static async void rollback_deployment (RotationPlan plan) throws KeyMakerError {
            try {
                KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Starting rollback for rotation: %s", 
                                 plan.rotation_id);
                
                // Remove the new key from any targets where it was successfully deployed
                if (plan.new_key != null) {
                    yield remove_new_key_from_targets(plan);
                }
                
                // Delete the new key from local filesystem if it exists
                if (plan.new_key != null) {
                    yield cleanup_new_key(plan);
                }
                
                // Restore old key from backup if it was deleted
                if (plan.remove_old_key && plan.backup_old_key) {
                    yield attempt_restore_old_key(plan);
                }
                
                KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Rollback completed for rotation: %s", 
                                 plan.rotation_id);
                
            } catch (KeyMakerError e) {
                throw e;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED("Rollback failed: %s", e.message);
            }
        }
        
        /**
         * Remove new key from all targets where deployment succeeded
         */
        private static async void remove_new_key_from_targets (RotationPlan plan) throws KeyMakerError {
            KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Removing new key from successfully deployed targets");
            
            for (int i = 0; i < plan.targets.length; i++) {
                var target = plan.targets[i];
                
                // Only attempt removal from targets where deployment succeeded
                if (!target.deployment_success) {
                    continue;
                }
                
                try {
                    yield RotationDeploy.remove_key_from_target(plan.new_key, target);
                    
                    KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Removed new key from: %s", 
                                     target.get_display_name());
                    
                } catch (KeyMakerError e) {
                    KeyMaker.Log.warning(KeyMaker.Log.Categories.ROTATION, 
                                        "Failed to remove new key from %s: %s", 
                                        target.get_display_name(), e.message);
                    // Continue with other targets
                }
            }
        }
        
        /**
         * Delete the new key from local filesystem
         */
        private static async void cleanup_new_key (RotationPlan plan) throws KeyMakerError {
            try {
                KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Cleaning up new key: %s", 
                                 plan.new_key.fingerprint);
                
                yield SSHMutate.delete_key_pair(plan.new_key);
                
                KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Successfully cleaned up new key");
                
            } catch (KeyMakerError e) {
                KeyMaker.Log.warning(KeyMaker.Log.Categories.ROTATION, "Failed to cleanup new key: %s", e.message);
                // Don't throw - this is cleanup, not critical for rollback
            }
        }
        
        /**
         * Attempt to restore old key from backup
         */
        private static async void attempt_restore_old_key (RotationPlan plan) throws KeyMakerError {
            try {
                KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Attempting to restore old key from backup");
                
                // Find the backup created during rotation
                var vault = new EmergencyVault();
                var backups = vault.get_all_backups_legacy();
                
                BackupEntry? rotation_backup = null;
                for (int i = 0; i < backups.length; i++) {
                    var backup = backups[i];
                    if (backup.name.contains(plan.rotation_id)) {
                        rotation_backup = backup;
                        break;
                    }
                }
                
                if (rotation_backup == null) {
                    throw new KeyMakerError.OPERATION_FAILED("Could not find rotation backup");
                }
                
                // Restore the backup
                var restored_keys = yield vault.restore_backup_legacy(rotation_backup, "");
                
                if (restored_keys.length > 0) {
                    KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, 
                                     "Successfully restored old key from backup");
                } else {
                    throw new KeyMakerError.OPERATION_FAILED("No keys restored from backup");
                }
                
            } catch (KeyMakerError e) {
                KeyMaker.Log.error(KeyMaker.Log.Categories.ROTATION, "Failed to restore old key: %s", e.message);
                // Don't re-throw - rollback should continue even if restore fails
            }
        }
        
        /**
         * Rollback a single target deployment
         */
        public static async void rollback_target (RotationPlan plan, RotationTarget target) throws KeyMakerError {
            if (plan.new_key == null) {
                return;
            }
            
            try {
                KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Rolling back deployment to: %s", 
                                 target.get_display_name());
                
                yield RotationDeploy.remove_key_from_target(plan.new_key, target);
                
                // Reset target state
                target.deployment_success = false;
                target.verification_success = false;
                target.error_message = "Deployment rolled back";
                
                KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Successfully rolled back target: %s", 
                                 target.get_display_name());
                
            } catch (KeyMakerError e) {
                throw e;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED("Failed to rollback target: %s", e.message);
            }
        }
        
        /**
         * Emergency rollback - attempt to restore system to previous state
         */
        public static async void emergency_rollback (RotationPlan plan) throws KeyMakerError {
            KeyMaker.Log.warning(KeyMaker.Log.Categories.ROTATION, "Performing emergency rollback for: %s", 
                                plan.rotation_id);
            
            try {
                // First, try to restore old key if it was removed
                if (plan.remove_old_key) {
                    yield attempt_restore_old_key(plan);
                }
                
                // Then remove new key from all targets
                if (plan.new_key != null) {
                    for (int i = 0; i < plan.targets.length; i++) {
                        var target = plan.targets[i];
                        try {
                            yield RotationDeploy.remove_key_from_target(plan.new_key, target);
                        } catch (KeyMakerError e) {
                            KeyMaker.Log.error(KeyMaker.Log.Categories.ROTATION, 
                                              "Emergency rollback failed for %s: %s", 
                                              target.get_display_name(), e.message);
                        }
                    }
                    
                    // Clean up new key
                    yield cleanup_new_key(plan);
                }
                
                KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Emergency rollback completed");
                
            } catch (Error e) {
                KeyMaker.Log.error(KeyMaker.Log.Categories.ROTATION, "Emergency rollback failed: %s", e.message);
                throw new KeyMakerError.OPERATION_FAILED("Emergency rollback failed: %s", e.message);
            }
        }
        
        /**
         * Validate rollback prerequisites
         */
        public static bool can_rollback (RotationPlan plan) {
            // Can rollback if we have a new key and at least one successful deployment
            if (plan.new_key == null) {
                return false;
            }
            
            return plan.get_successful_deployments() > 0;
        }
        
        /**
         * Get rollback status summary
         */
        public static string get_rollback_summary (RotationPlan plan) {
            if (!can_rollback(plan)) {
                return "No rollback needed - no successful deployments";
            }
            
            var successful_deployments = plan.get_successful_deployments();
            return @"Rollback needed for $(successful_deployments) successful deployments";
        }
    }
}