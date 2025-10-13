/*
 * SSHer - Key Rotation Manager (Facade)
 * 
 * Main facade for key rotation operations, delegates to specialized modules.
 * 
 * Copyright (C) 2025 Thiago Fernandes
 */

namespace KeyMaker {
    
    public class KeyRotationManager : GLib.Object {
        
        public signal void stage_changed (RotationStage stage);
        public signal void progress_updated (double percentage);
        public signal void target_deployed (RotationTarget target, bool success);
        public signal void target_verified (RotationTarget target, bool success);
        public signal void rotation_completed (RotationPlan plan, bool success = true);
        public signal void rotation_failed (RotationPlan plan, string error);
        
        // Additional signals expected by UI
        public signal void rotation_started (RotationPlan plan);
        public signal void rotation_stage_changed (RotationPlan plan, RotationStage stage);
        public signal void rotation_progress (RotationPlan plan, string message);
        
        private RotationRunner? current_runner;
        private RotationPlan? current_plan;
        
        /**
         * Create a new rotation plan for the given key
         */
        public RotationPlan create_plan (SSHKey ssh_key) {
            current_plan = new RotationPlan(ssh_key);
            return current_plan;
        }
        
        /**
         * Start executing a rotation plan
         */
        public async void execute_plan (RotationPlan plan, Cancellable? cancellable = null) throws KeyMakerError {
            rotation_started(plan);
            yield execute_rotation_plan(plan, cancellable);
        }
        
        /**
         * Execute rotation plan (method expected by UI)
         */
        public async void execute_rotation_plan (RotationPlan plan, Cancellable? cancellable = null) throws KeyMakerError {
            if (current_runner != null) {
                throw new KeyMakerError.OPERATION_FAILED ("A rotation is already in progress");
            }
            
            current_plan = plan;
            current_runner = new RotationRunner(plan);
            
            // Connect signals from runner to our signals
            current_runner.stage_changed.connect((stage) => {
                stage_changed(stage);
                rotation_stage_changed(current_plan, stage);
            });
            
            current_runner.progress_updated.connect((percentage) => {
                progress_updated(percentage);
                var message = @"Progress: $((int)percentage)%";
                rotation_progress(current_plan, message);
            });
            
            current_runner.target_deployed.connect((target, success) => {
                target_deployed(target, success);
            });
            
            current_runner.target_verified.connect((target, success) => {
                target_verified(target, success);
            });
            
            current_runner.rotation_completed.connect((plan) => {
                current_runner = null;
                rotation_completed(plan, true);
            });
            
            current_runner.rotation_failed.connect((plan, error) => {
                current_runner = null;
                rotation_completed(plan, false);
                rotation_failed(plan, error);
            });
            
            try {
                yield current_runner.start_rotation(cancellable);
            } catch (KeyMakerError e) {
                current_runner = null;
                throw e;
            }
        }
        
        /**
         * Cancel the current rotation
         */
        public void cancel_rotation () {
            if (current_runner != null) {
                current_runner.cancel_rotation();
            }
        }
        
        /**
         * Check if a rotation is currently in progress
         */
        public bool is_rotation_in_progress () {
            return current_runner != null;
        }
        
        /**
         * Get the current rotation plan
         */
        public RotationPlan? get_current_plan () {
            return current_plan;
        }
        
        /**
         * Rollback the current or specified rotation plan
         */
        public async void rollback_rotation (RotationPlan? plan = null) throws KeyMakerError {
            var target_plan = plan ?? current_plan;
            if (target_plan == null) {
                throw new KeyMakerError.OPERATION_FAILED ("No rotation plan to rollback");
            }
            
            yield RotationRollback.rollback_deployment(target_plan);
        }
        
        /**
         * Deploy a single key to a target (standalone operation)
         */
        public async void deploy_key_to_target (SSHKey ssh_key, RotationTarget target) throws KeyMakerError {
            yield RotationDeploy.deploy_key_to_target(ssh_key, target);
        }
        
        /**
         * Verify access to a target with a specific key
         */
        public async void verify_key_access (SSHKey ssh_key, RotationTarget target) throws KeyMakerError {
            yield RotationDeploy.verify_key_access(ssh_key, target);
        }
        
        /**
         * Remove a key from a target
         */
        public async void remove_key_from_target (SSHKey ssh_key, RotationTarget target) throws KeyMakerError {
            yield RotationDeploy.remove_key_from_target(ssh_key, target);
        }
        
        /**
         * Create a new rotation plan (expected by UI)
         */
        public RotationPlan create_rotation_plan (SSHKey ssh_key, string reason) {
            return new RotationPlan(ssh_key, reason);
        }
        
        /**
         * Get rotation recommendations for a key
         */
        public GenericArray<string> get_rotation_recommendations (SSHKey ssh_key) {
            var recommendations = new GenericArray<string>();
            
            // Basic recommendations based on key type and age
            switch (ssh_key.key_type) {
                case SSHKeyType.RSA:
                    if (ssh_key.bit_size < 2048) {
                        recommendations.add("Upgrade to at least RSA 2048-bit");
                    }
                    recommendations.add("Consider migrating to ED25519 for better security");
                    break;
                    
                case SSHKeyType.ECDSA:
                    recommendations.add("Consider migrating to ED25519 for better compatibility");
                    break;
                    
                case SSHKeyType.ED25519:
                    recommendations.add("ED25519 is the recommended key type");
                    break;
            }
            
            // Age-based recommendations
            var now = new DateTime.now_local();
            var key_age = now.difference(ssh_key.last_modified);
            var days_old = key_age / TimeSpan.DAY;
            
            if (days_old > 365) {
                recommendations.add("Key is over 1 year old, rotation recommended");
            } else if (days_old > 90) {
                recommendations.add("Consider rotating key every 3-6 months for high-security environments");
            }
            
            if (recommendations.length == 0) {
                recommendations.add("Key appears to be in good condition");
            }
            
            return recommendations;
        }
    }
}