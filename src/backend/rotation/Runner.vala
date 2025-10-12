/*
 * Key Maker - Key Rotation Runner
 * 
 * Orchestrates the key rotation process through all stages.
 */

namespace KeyMaker {
    
    public class RotationRunner : GLib.Object {
        
        public signal void stage_changed (RotationStage stage);
        public signal void progress_updated (double percentage);
        public signal void target_deployed (RotationTarget target, bool success);
        public signal void target_verified (RotationTarget target, bool success);
        public signal void rotation_completed (RotationPlan plan);
        public signal void rotation_failed (RotationPlan plan, string error);
        
        private RotationPlan plan;
        private Cancellable? cancellable;
        private bool is_running = false;
        
        public RotationRunner (RotationPlan rotation_plan) {
            plan = rotation_plan;
        }
        
        /**
         * Start the key rotation process
         */
        public async void start_rotation (Cancellable? cancel = null) throws KeyMakerError {
            if (is_running) {
                throw new KeyMakerError.OPERATION_FAILED ("Rotation is already running");
            }
            
            is_running = true;
            cancellable = cancel;
            plan.started_at = new DateTime.now_local();
            
            try {
                KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Starting key rotation: %s", plan.rotation_id);
                
                yield run_stage_generate_new_key();
                
                if (plan.backup_old_key) {
                    yield run_stage_backup_old_key();
                }
                
                yield run_stage_deploy_new_key();
                
                if (plan.verify_access) {
                    yield run_stage_verify_access();
                }
                
                if (plan.remove_old_key) {
                    yield run_stage_remove_old_key();
                }
                
                yield complete_rotation();
                
            } catch (KeyMakerError e) {
                yield fail_rotation(e.message);
                throw e;
            } catch (Error e) {
                yield fail_rotation(e.message);
                throw new KeyMakerError.OPERATION_FAILED("Rotation failed: %s", e.message);
            } finally {
                is_running = false;
            }
        }
        
        /**
         * Cancel the rotation process
         */
        public void cancel_rotation() {
            if (cancellable != null) {
                cancellable.cancel();
            }
            is_running = false;
            KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Rotation cancelled: %s", plan.rotation_id);
        }
        
        private async void run_stage_generate_new_key() throws KeyMakerError {
            set_stage(RotationStage.GENERATING_NEW_KEY);
            
            KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Generating new key based on old key: %s", 
                             plan.old_key.get_display_name());
            
            // Create a generation request based on the old key
            var filename = @"$(plan.old_key.private_path.get_basename())_new";
            var request = new KeyGenerationRequest(filename);
            request.key_type = plan.old_key.key_type;
            
            // Set the appropriate size based on key type
            switch (plan.old_key.key_type) {
                case SSHKeyType.RSA:
                    request.rsa_bits = plan.old_key.bit_size > 0 ? plan.old_key.bit_size : 4096;
                    break;
                case SSHKeyType.ECDSA:
                    request.ecdsa_curve = plan.old_key.bit_size > 0 ? plan.old_key.bit_size : 256;
                    break;
                // ED25519 has fixed sizes, no need to set
            }
            
            request.comment = @"Rotated key for $(plan.old_key.comment)";
            
            plan.new_key = yield SSHGeneration.generate_key(request);
            
            KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Successfully generated new key: %s", 
                             plan.new_key.fingerprint);
        }
        
        private async void run_stage_backup_old_key() throws KeyMakerError {
            set_stage(RotationStage.BACKING_UP_OLD_KEY);
            
            KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Backing up old key");
            
            // Create emergency vault backup
            var vault = new EmergencyVault();
            var keys = new GenericArray<SSHKey>();
            keys.add(plan.old_key);
            
            var backup_name = @"rotation_backup_$(plan.rotation_id)";
            var backup = yield vault.create_encrypted_backup(keys, backup_name, "");
            
            KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Successfully backed up old key: %s", 
                             backup.name);
        }
        
        private async void run_stage_deploy_new_key() throws KeyMakerError {
            set_stage(RotationStage.DEPLOYING_NEW_KEY);
            
            KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Deploying new key to %u targets", 
                             plan.targets.length);
            
            for (int i = 0; i < plan.targets.length; i++) {
                if (cancellable != null && cancellable.is_cancelled()) {
                    throw new KeyMakerError.OPERATION_CANCELLED("Rotation was cancelled");
                }
                
                var target = plan.targets[i];
                
                try {
                    yield RotationDeploy.deploy_key_to_target(plan.new_key, target);
                    target.deployment_success = true;
                    target.error_message = "";
                    
                    KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Successfully deployed to: %s", 
                                     target.get_display_name());
                    target_deployed(target, true);
                    
                } catch (KeyMakerError e) {
                    target.deployment_success = false;
                    target.error_message = e.message;
                    
                    KeyMaker.Log.warning(KeyMaker.Log.Categories.ROTATION, "Failed to deploy to %s: %s", 
                                        target.get_display_name(), e.message);
                    target_deployed(target, false);
                }
                
                update_progress();
            }
        }
        
        private async void run_stage_verify_access() throws KeyMakerError {
            set_stage(RotationStage.VERIFYING_ACCESS);
            
            KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Verifying access with new key");
            
            for (int i = 0; i < plan.targets.length; i++) {
                if (cancellable != null && cancellable.is_cancelled()) {
                    throw new KeyMakerError.OPERATION_CANCELLED("Rotation was cancelled");
                }
                
                var target = plan.targets[i];
                
                // Only verify targets where deployment succeeded
                if (!target.deployment_success) {
                    target.verification_success = false;
                    continue;
                }
                
                try {
                    yield RotationDeploy.verify_key_access(plan.new_key, target);
                    target.verification_success = true;
                    
                    KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Successfully verified access to: %s", 
                                     target.get_display_name());
                    target_verified(target, true);
                    
                } catch (KeyMakerError e) {
                    target.verification_success = false;
                    target.error_message = e.message;
                    
                    KeyMaker.Log.warning(KeyMaker.Log.Categories.ROTATION, "Failed to verify access to %s: %s", 
                                        target.get_display_name(), e.message);
                    target_verified(target, false);
                }
                
                update_progress();
            }
        }
        
        private async void run_stage_remove_old_key() throws KeyMakerError {
            set_stage(RotationStage.REMOVING_OLD_KEY);
            
            KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Removing old key from filesystem");
            
            // Only remove if all verifications were successful
            int successful_verifications = plan.get_successful_verifications();
            if (successful_verifications < plan.targets.length) {
                var warning = @"Not all verifications succeeded ($successful_verifications/$(plan.targets.length)). Skipping old key removal for safety.";
                KeyMaker.Log.warning(KeyMaker.Log.Categories.ROTATION, warning);
                plan.error_message = warning;
                return;
            }
            
            yield SSHMutate.delete_key_pair(plan.old_key);
            
            KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Successfully removed old key");
        }
        
        private async void complete_rotation() throws KeyMakerError {
            set_stage(RotationStage.COMPLETED);
            plan.completed_at = new DateTime.now_local();
            
            KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Key rotation completed successfully: %s", 
                             plan.rotation_id);
            
            rotation_completed(plan);
        }
        
        private async void fail_rotation(string error_message) throws KeyMakerError {
            set_stage(RotationStage.FAILED);
            plan.error_message = error_message;
            plan.completed_at = new DateTime.now_local();
            
            KeyMaker.Log.error(KeyMaker.Log.Categories.ROTATION, "Key rotation failed: %s - %s", 
                              plan.rotation_id, error_message);
            
            rotation_failed(plan, error_message);
            
            // Attempt rollback if new key was generated
            if (plan.new_key != null) {
                yield attempt_rollback();
            }
        }
        
        private async void attempt_rollback() throws KeyMakerError {
            set_stage(RotationStage.ROLLING_BACK);
            
            KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Attempting rollback");
            
            try {
                yield RotationRollback.rollback_deployment(plan);
                KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Rollback completed");
            } catch (KeyMakerError e) {
                KeyMaker.Log.error(KeyMaker.Log.Categories.ROTATION, "Rollback failed: %s", e.message);
            }
        }
        
        private void set_stage(RotationStage stage) {
            plan.current_stage = stage;
            stage_changed(stage);
            update_progress();
        }
        
        private void update_progress() {
            progress_updated(plan.progress_percentage);
        }
    }
}