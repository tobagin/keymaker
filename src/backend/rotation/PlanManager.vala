/*
 * SSHer - Rotation Plan Manager
 * 
 * Manages multiple rotation plans with CRUD operations, persistence, and batch execution.
 */

namespace KeyMaker {
    
    public class RotationPlanManager : GLib.Object {
        
        // Signals for plan management
        public signal void plan_added (RotationPlan plan);
        public signal void plan_updated (RotationPlan plan);
        public signal void plan_removed (RotationPlan plan);
        public signal void plan_status_changed (RotationPlan plan, RotationPlanStatus old_status);
        
        // Signals for execution monitoring
        public signal void execution_started (RotationPlan plan);
        public signal void execution_completed (RotationPlan plan, bool success);
        public signal void batch_execution_started (GenericArray<RotationPlan> plans);
        public signal void batch_execution_completed (int successful, int failed);
        
        // Signal for loading completion
        public signal void plans_loaded ();
        
        private GenericArray<RotationPlan> plans;
        private HashTable<string, RotationPlan> plans_by_id;
        private KeyRotationManager rotation_manager;
        private GenericArray<RotationPlan> running_plans;
        
        public RotationPlanManager () {
            plans = new GenericArray<RotationPlan>();
            plans_by_id = new HashTable<string, RotationPlan>(str_hash, str_equal);
            rotation_manager = new KeyRotationManager();
            running_plans = new GenericArray<RotationPlan>();
            
            load_plans_from_storage.begin();
            setup_cleanup_timer();
        }
        
        /**
         * Create a new rotation plan
         */
        public RotationPlan create_plan (SSHKey ssh_key, string reason = "Manual rotation") {
            var plan = new RotationPlan(ssh_key, reason);
            add_plan(plan);
            return plan;
        }
        
        /**
         * Add a plan to the manager
         */
        public void add_plan (RotationPlan plan) {
            plans.add(plan);
            plans_by_id[plan.rotation_id] = plan;
            save_plans_to_storage();
            plan_added(plan);
        }
        
        /**
         * Update an existing plan
         */
        public void update_plan (RotationPlan plan) {
            save_plans_to_storage();
            plan_updated(plan);
        }
        
        /**
         * Remove a plan from the manager
         */
        public void remove_plan (RotationPlan plan) {
            if (!plan.can_edit()) {
                warning("Cannot remove plan that is not in draft state");
                return;
            }
            
            plans.remove(plan);
            plans_by_id.remove(plan.rotation_id);
            save_plans_to_storage();
            plan_removed(plan);
        }
        
        /**
         * Get plan by ID
         */
        public RotationPlan? get_plan_by_id (string plan_id) {
            return plans_by_id[plan_id];
        }
        
        /**
         * Get all plans
         */
        public GenericArray<RotationPlan> get_all_plans () {
            return plans;
        }
        
        /**
         * Get plans by status
         */
        public GenericArray<RotationPlan> get_plans_by_status (RotationPlanStatus status) {
            var filtered_plans = new GenericArray<RotationPlan>();
            for (int i = 0; i < plans.length; i++) {
                var plan = plans[i];
                if (plan.status == status) {
                    filtered_plans.add(plan);
                }
            }
            return filtered_plans;
        }
        
        /**
         * Get draft plans (editable)
         */
        public GenericArray<RotationPlan> get_draft_plans () {
            return get_plans_by_status(RotationPlanStatus.DRAFT);
        }
        
        /**
         * Get running plans
         */
        public GenericArray<RotationPlan> get_running_plans () {
            return get_plans_by_status(RotationPlanStatus.RUNNING);
        }
        
        /**
         * Get completed plans that can be rolled back
         */
        public GenericArray<RotationPlan> get_rollback_available_plans () {
            var rollback_plans = new GenericArray<RotationPlan>();
            for (int i = 0; i < plans.length; i++) {
                var plan = plans[i];
                if (plan.can_rollback()) {
                    rollback_plans.add(plan);
                }
            }
            return rollback_plans;
        }
        
        /**
         * Get historical plans (completed, failed, rolled back)
         */
        public GenericArray<RotationPlan> get_historical_plans () {
            var historical_plans = new GenericArray<RotationPlan>();
            for (int i = 0; i < plans.length; i++) {
                var plan = plans[i];
                if (plan.status == RotationPlanStatus.COMPLETED && !plan.can_rollback() ||
                    plan.status == RotationPlanStatus.FAILED ||
                    plan.status == RotationPlanStatus.ROLLED_BACK ||
                    plan.status == RotationPlanStatus.CANCELLED) {
                    historical_plans.add(plan);
                }
            }
            return historical_plans;
        }
        
        /**
         * Execute a single plan
         */
        public async void execute_plan (RotationPlan plan) throws KeyMakerError {
            if (!plan.can_execute()) {
                throw new KeyMakerError.OPERATION_FAILED("Plan cannot be executed in current state");
            }
            
            var old_status = plan.status;
            plan.start_execution();
            plan_status_changed(plan, old_status);
            
            running_plans.add(plan);
            execution_started(plan);
            
            try {
                yield rotation_manager.execute_rotation_plan(plan);
                plan.complete_execution(true);
                execution_completed(plan, true);
            } catch (KeyMakerError e) {
                plan.complete_execution(false);
                plan.error_message = e.message;
                execution_completed(plan, false);
                throw e;
            } finally {
                running_plans.remove(plan);
                plan_status_changed(plan, old_status);
                save_plans_to_storage();
            }
        }
        
        /**
         * Execute multiple plans in batch
         */
        public async void execute_batch (GenericArray<RotationPlan> batch_plans) {
            var executable_plans = new GenericArray<RotationPlan>();
            
            // Filter plans that can be executed
            for (int i = 0; i < batch_plans.length; i++) {
                var plan = batch_plans[i];
                if (plan.can_execute()) {
                    executable_plans.add(plan);
                }
            }
            
            if (executable_plans.length == 0) {
                return;
            }
            
            batch_execution_started(executable_plans);
            
            int successful = 0;
            int failed = 0;
            
            // Execute plans sequentially
            for (int i = 0; i < executable_plans.length; i++) {
                var plan = executable_plans[i];
                try {
                    yield execute_plan(plan);
                    successful++;
                } catch (KeyMakerError e) {
                    warning("Plan execution failed: %s", e.message);
                    failed++;
                }
            }
            
            batch_execution_completed(successful, failed);
        }
        
        /**
         * Rollback a completed plan
         */
        public async void rollback_plan (RotationPlan plan) throws KeyMakerError {
            if (!plan.can_rollback()) {
                throw new KeyMakerError.OPERATION_FAILED("Plan cannot be rolled back");
            }
            
            var old_status = plan.status;
            
            try {
                yield rotation_manager.rollback_rotation(plan);
                plan.mark_rolled_back();
                plan_status_changed(plan, old_status);
                save_plans_to_storage();
            } catch (KeyMakerError e) {
                plan.error_message = e.message;
                save_plans_to_storage();
                throw e;
            }
        }
        
        /**
         * Cancel a running plan
         */
        public void cancel_plan (RotationPlan plan) {
            if (!plan.can_cancel()) {
                return;
            }
            
            var old_status = plan.status;
            plan.cancel_execution("Cancelled by user");
            running_plans.remove(plan);
            rotation_manager.cancel_rotation();
            plan_status_changed(plan, old_status);
            save_plans_to_storage();
        }
        
        /**
         * Duplicate an existing plan
         */
        public RotationPlan duplicate_plan (RotationPlan original) {
            var duplicate = original.create_copy();
            add_plan(duplicate);
            return duplicate;
        }
        
        /**
         * Clean up expired rollback plans
         */
        private void cleanup_expired_rollbacks () {
            for (int i = 0; i < plans.length; i++) {
                var plan = plans[i];
                if (plan.status == RotationPlanStatus.COMPLETED && 
                    plan.rollback_expires_at != null &&
                    !plan.can_rollback()) {
                    // Rollback period has expired, but don't remove the plan
                    // Just ensure it won't show up in rollback lists
                    continue;
                }
            }
            save_plans_to_storage();
        }
        
        /**
         * Set up timer to clean up expired rollbacks
         */
        private void setup_cleanup_timer () {
            // Run cleanup every hour
            Timeout.add_seconds(3600, () => {
                cleanup_expired_rollbacks();
                return true;
            });
        }
        
        /**
         * Save plans to persistent storage
         */
        private void save_plans_to_storage () {
            try {
                var builder = new Json.Builder();
                builder.begin_array();
                
                for (int i = 0; i < plans.length; i++) {
                    serialize_plan(builder, plans[i]);
                }
                
                builder.end_array();
                var generator = new Json.Generator();
                generator.set_root(builder.get_root());
                
                var data_dir = Environment.get_user_data_dir();
                var keymaker_dir = File.new_for_path(Path.build_filename(data_dir, "keymaker"));
                
                if (!keymaker_dir.query_exists()) {
                    keymaker_dir.make_directory_with_parents();
                }
                
                var plans_file = keymaker_dir.get_child("rotation-plans.json");
                generator.to_file(plans_file.get_path());
                
            } catch (Error e) {
                warning("Failed to save rotation plans: %s", e.message);
            }
        }
        
        /**
         * Load plans from persistent storage
         */
        private async void load_plans_from_storage () {
            try {
                var data_dir = Environment.get_user_data_dir();
                var plans_file = File.new_for_path(Path.build_filename(data_dir, "keymaker", "rotation-plans.json"));
                
                if (!plans_file.query_exists()) {
                    return;
                }
                
                var parser = new Json.Parser();
                parser.load_from_file(plans_file.get_path());
                
                var root = parser.get_root();
                if (root.get_node_type() != Json.NodeType.ARRAY) {
                    return;
                }
                
                var array = root.get_array();
                for (uint i = 0; i < array.get_length(); i++) {
                    var node = array.get_element(i);
                    var plan = yield deserialize_plan(node);
                    if (plan != null) {
                        plans.add(plan);
                        plans_by_id[plan.rotation_id] = plan;
                        // Emit signal for each loaded plan to update UI
                        plan_added(plan);
                    }
                }
                
                // Emit completion signal
                plans_loaded();
                
            } catch (Error e) {
                warning("Failed to load rotation plans: %s", e.message);
                // Still emit completion signal even if loading failed
                plans_loaded();
            }
        }
        
        /**
         * Serialize a plan to JSON
         */
        private void serialize_plan (Json.Builder builder, RotationPlan plan) {
            builder.begin_object();
            
            builder.set_member_name("rotation_id");
            builder.add_string_value(plan.rotation_id);
            
            builder.set_member_name("name");
            builder.add_string_value(plan.name);
            
            builder.set_member_name("description");
            builder.add_string_value(plan.description ?? "");
            
            builder.set_member_name("rotation_reason");
            builder.add_string_value(plan.rotation_reason);
            
            builder.set_member_name("status");
            builder.add_int_value((int)plan.status);
            
            builder.set_member_name("created_at");
            builder.add_string_value(plan.created_at.format_iso8601());
            
            if (plan.started_at != null) {
                builder.set_member_name("started_at");
                builder.add_string_value(plan.started_at.format_iso8601());
            }
            
            if (plan.completed_at != null) {
                builder.set_member_name("completed_at");
                builder.add_string_value(plan.completed_at.format_iso8601());
            }
            
            if (plan.rollback_expires_at != null) {
                builder.set_member_name("rollback_expires_at");
                builder.add_string_value(plan.rollback_expires_at.format_iso8601());
            }
            
            builder.set_member_name("old_key_fingerprint");
            builder.add_string_value(plan.old_key.fingerprint);
            
            // Add other plan properties...
            builder.set_member_name("backup_old_key");
            builder.add_boolean_value(plan.backup_old_key);
            
            builder.set_member_name("keep_old_key");
            builder.add_boolean_value(plan.keep_old_key);
            
            builder.set_member_name("enable_rollback");
            builder.add_boolean_value(plan.enable_rollback);
            
            builder.set_member_name("rollback_period");
            builder.add_int_value((int)plan.rollback_period);
            
            if (plan.error_message != null) {
                builder.set_member_name("error_message");
                builder.add_string_value(plan.error_message);
            }
            
            // Serialize targets
            builder.set_member_name("targets");
            builder.begin_array();
            for (int i = 0; i < plan.targets.length; i++) {
                var target = plan.targets[i];
                builder.begin_object();
                builder.set_member_name("hostname");
                builder.add_string_value(target.hostname);
                builder.set_member_name("username");
                builder.add_string_value(target.username);
                builder.set_member_name("port");
                builder.add_int_value(target.port);
                if (target.proxy_jump != null) {
                    builder.set_member_name("proxy_jump");
                    builder.add_string_value(target.proxy_jump);
                }
                builder.end_object();
            }
            builder.end_array();
            
            builder.end_object();
        }
        
        /**
         * Deserialize a plan from JSON
         */
        private async RotationPlan? deserialize_plan (Json.Node node) {
            if (node.get_node_type() != Json.NodeType.OBJECT) {
                return null;
            }
            
            var obj = node.get_object();
            
            // Find the SSH key by fingerprint
            var key_fingerprint = obj.get_string_member("old_key_fingerprint");
            var ssh_key = yield find_ssh_key_by_fingerprint(key_fingerprint);
            if (ssh_key == null) {
                warning("SSH key not found for plan: %s", key_fingerprint);
                return null;
            }
            
            var plan = new RotationPlan(ssh_key, obj.get_string_member("rotation_reason"));
            
            // Restore basic properties
            plan.rotation_id = obj.get_string_member("rotation_id");
            plan.name = obj.get_string_member("name");
            plan.description = obj.has_member("description") ? obj.get_string_member("description") : null;
            plan.status = (RotationPlanStatus)obj.get_int_member("status");
            
            // Restore timestamps
            plan.created_at = new DateTime.from_iso8601(obj.get_string_member("created_at"), null);
            
            if (obj.has_member("started_at")) {
                plan.started_at = new DateTime.from_iso8601(obj.get_string_member("started_at"), null);
            }
            
            if (obj.has_member("completed_at")) {
                plan.completed_at = new DateTime.from_iso8601(obj.get_string_member("completed_at"), null);
            }
            
            if (obj.has_member("rollback_expires_at")) {
                plan.rollback_expires_at = new DateTime.from_iso8601(obj.get_string_member("rollback_expires_at"), null);
            }
            
            // Restore configuration
            plan.backup_old_key = obj.get_boolean_member("backup_old_key");
            plan.keep_old_key = obj.get_boolean_member("keep_old_key");
            plan.enable_rollback = obj.get_boolean_member("enable_rollback");
            plan.rollback_period = (RollbackPeriod)obj.get_int_member("rollback_period");
            
            if (obj.has_member("error_message")) {
                plan.error_message = obj.get_string_member("error_message");
            }
            
            // Restore targets
            var targets_array = obj.get_array_member("targets");
            targets_array.foreach_element((arr, index, target_node) => {
                var target_obj = target_node.get_object();
                var target = new RotationTarget(
                    target_obj.get_string_member("hostname"),
                    target_obj.get_string_member("username"),
                    (int)target_obj.get_int_member("port")
                );
                
                if (target_obj.has_member("proxy_jump")) {
                    target.proxy_jump = target_obj.get_string_member("proxy_jump");
                }
                
                plan.add_target(target);
            });
            
            return plan;
        }
        
        /**
         * Find SSH key by fingerprint using key scanner
         */
        private async SSHKey? find_ssh_key_by_fingerprint (string fingerprint) {
            try {
                var key_scanner = new KeyScanner();
                var available_keys = yield KeyScanner.scan_ssh_directory();
                
                for (int i = 0; i < available_keys.length; i++) {
                    var key = available_keys[i];
                    if (key.fingerprint == fingerprint) {
                        return key;
                    }
                }
            } catch (Error e) {
                warning("Failed to find SSH key by fingerprint: %s", e.message);
            }
            return null;
        }
    }
}