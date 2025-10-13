/*
 * SSHer - Key Rotation Planning Data Types
 * 
 * Data structures for planning and tracking key rotation operations.
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
                case PLANNING: return "accessories-text-editor-symbolic";
                case GENERATING_NEW_KEY: return "document-new-symbolic";
                case BACKING_UP_OLD_KEY: return "folder-download-symbolic";
                case DEPLOYING_NEW_KEY: return "network-transmit-symbolic";
                case VERIFYING_ACCESS: return "emblem-system-symbolic";
                case REMOVING_OLD_KEY: return "user-trash-symbolic";
                case COMPLETED: return "emblem-ok-symbolic";
                case FAILED: return "dialog-error-symbolic";
                case ROLLING_BACK: return "io.github.tobagin.keysmith-rollback-symbolic";
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
        
        public string[] get_ssh_command_args () {
            var args = new GenericArray<string>();
            args.add("ssh");
            
            if (port != 22) {
                args.add("-p");
                args.add(port.to_string());
            }
            
            if (proxy_jump != null && proxy_jump.length > 0) {
                args.add("-J");
                args.add(proxy_jump);
            }
            
            args.add(@"$(username)@$(hostname)");
            
            string[] result = new string[args.length];
            for (int i = 0; i < args.length; i++) {
                result[i] = args[i];
            }
            return result;
        }
    }
    
    public class RotationPlan : GLib.Object {
        public SSHKey old_key { get; set; }
        public SSHKey? new_key { get; set; }
        public GenericArray<RotationTarget> targets { get; set; }
        public RotationStage current_stage { get; set; default = RotationStage.PLANNING; }
        public RotationPlanStatus status { get; set; default = RotationPlanStatus.DRAFT; }
        public bool backup_old_key { get; set; default = true; }
        public bool remove_old_key { get; set; default = false; }
        public bool verify_access { get; set; default = true; }
        public DateTime created_at { get; set; }
        public DateTime? started_at { get; set; }
        public DateTime? completed_at { get; set; }
        public DateTime? rollback_expires_at { get; set; }
        public string rotation_id { get; set; }
        public string? error_message { get; set; }
        
        // Plan configuration properties
        public string rotation_reason { get; set; default = "Manual rotation"; }
        public bool keep_old_key { get; set; default = true; }
        public bool enable_rollback { get; set; default = true; }
        public RollbackPeriod rollback_period { get; set; default = RollbackPeriod.ONE_WEEK; }
        public string name { get; set; default = ""; }
        public string? description { get; set; }
        
        // State tracking
        public double progress_percentage { 
            get { 
                int total_steps = get_total_steps();
                int completed_steps = get_completed_steps();
                
                if (total_steps == 0) return 0.0;
                return (double)completed_steps / total_steps * 100.0;
            } 
        }
        public string current_operation { get; set; default = ""; }
        
        private GenericArray<string> log_entries;
        
        construct {
            targets = new GenericArray<RotationTarget>();
            log_entries = new GenericArray<string>();
            created_at = new DateTime.now_local();
            rotation_id = generate_rotation_id();
            name = @"Rotation for $(old_key != null ? old_key.get_display_name() : "Unknown Key")";
        }
        
        public RotationPlan (SSHKey key, string reason = "Manual rotation") {
            old_key = key;
            rotation_reason = reason;
            name = @"Rotation for $(key.get_display_name())";
        }
        
        private string generate_rotation_id () {
            var timestamp = new DateTime.now_local ().format ("%Y%m%d_%H%M%S");
            var random = Random.int_range (1000, 9999);
            return @"rotation_$(timestamp)_$(random)";
        }
        
        public void add_target (RotationTarget target) {
            targets.add(target);
        }
        
        public void remove_target (RotationTarget target) {
            targets.remove(target);
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
        
        public int get_successful_verifications () {
            int count = 0;
            for (int i = 0; i < targets.length; i++) {
                if (targets[i].verification_success) {
                    count++;
                }
            }
            return count;
        }
        
        public bool is_completed () {
            return current_stage == RotationStage.COMPLETED;
        }
        
        public bool has_failed () {
            return current_stage == RotationStage.FAILED;
        }
        
        
        private int get_total_steps () {
            int steps = 1; // Planning
            steps += 1; // Generate new key
            if (backup_old_key) steps += 1;
            steps += (int)targets.length; // Deploy to each target
            if (verify_access) steps += (int)targets.length; // Verify each target
            if (remove_old_key) steps += 1;
            return steps;
        }
        
        private int get_completed_steps () {
            switch (current_stage) {
                case RotationStage.PLANNING:
                    return 0;
                case RotationStage.GENERATING_NEW_KEY:
                    return 1;
                case RotationStage.BACKING_UP_OLD_KEY:
                    return backup_old_key ? 2 : 1;
                case RotationStage.DEPLOYING_NEW_KEY:
                    var base_steps = backup_old_key ? 3 : 2;
                    return base_steps + get_successful_deployments();
                case RotationStage.VERIFYING_ACCESS:
                    int deploy_base = backup_old_key ? 3 : 2;
                    return deploy_base + (int)targets.length + get_successful_verifications();
                case RotationStage.REMOVING_OLD_KEY:
                case RotationStage.COMPLETED:
                    return get_total_steps();
                default:
                    return 0;
            }
        }
        
        public void add_log_entry (string entry) {
            var timestamp = new DateTime.now_local().format("%H:%M:%S");
            log_entries.add(@"[$(timestamp)] $(entry)");
            KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Plan %s: %s", rotation_id, entry);
        }
        
        public GenericArray<string> get_log_entries () {
            return log_entries;
        }
        
        // New methods for comprehensive plan management
        
        /**
         * Check if the plan can be executed
         */
        public bool can_execute () {
            return status == RotationPlanStatus.DRAFT && targets.length > 0;
        }
        
        /**
         * Check if the plan can be edited
         */
        public bool can_edit () {
            return status == RotationPlanStatus.DRAFT;
        }
        
        /**
         * Check if the plan can be cancelled
         */
        public bool can_cancel () {
            return status == RotationPlanStatus.RUNNING;
        }
        
        /**
         * Check if rollback is available
         */
        public bool can_rollback () {
            if (!enable_rollback || status != RotationPlanStatus.COMPLETED) {
                return false;
            }
            
            if (rollback_expires_at == null) {
                return false;
            }
            
            var now = new DateTime.now_local();
            return now.compare(rollback_expires_at) < 0;
        }
        
        /**
         * Get time remaining for rollback
         */
        public string get_rollback_time_remaining () {
            if (!can_rollback() || rollback_expires_at == null) {
                return "";
            }
            
            var now = new DateTime.now_local();
            var time_span = rollback_expires_at.difference(now);
            var days = time_span / TimeSpan.DAY;
            var hours = (time_span % TimeSpan.DAY) / TimeSpan.HOUR;
            
            if (days > 0) {
                return @"$(days) day$(days > 1 ? "s" : ""), $(hours) hour$(hours > 1 ? "s" : "")";
            } else if (hours > 0) {
                return @"$(hours) hour$(hours > 1 ? "s" : "")";
            } else {
                var minutes = (time_span % TimeSpan.HOUR) / TimeSpan.MINUTE;
                return @"$(minutes) minute$(minutes > 1 ? "s" : "")";
            }
        }
        
        /**
         * Start the plan execution (updates status and timestamps)
         */
        public void start_execution () {
            status = RotationPlanStatus.RUNNING;
            started_at = new DateTime.now_local();
            add_log_entry("Plan execution started");
        }
        
        /**
         * Complete the plan (updates status and sets rollback expiry)
         */
        public void complete_execution (bool success = true) {
            if (success) {
                status = RotationPlanStatus.COMPLETED;
                completed_at = new DateTime.now_local();
                
                if (enable_rollback && completed_at != null) {
                    rollback_expires_at = completed_at.add_seconds(rollback_period.to_seconds());
                }
                
                add_log_entry("Plan executed successfully");
            } else {
                status = RotationPlanStatus.FAILED;
                add_log_entry("Plan execution failed");
            }
        }
        
        /**
         * Cancel the plan execution
         */
        public void cancel_execution (string? reason = null) {
            status = RotationPlanStatus.CANCELLED;
            if (reason != null) {
                error_message = reason;
                add_log_entry(@"Plan cancelled: $(reason)");
            } else {
                add_log_entry("Plan cancelled by user");
            }
        }
        
        /**
         * Mark the plan as rolled back
         */
        public void mark_rolled_back () {
            status = RotationPlanStatus.ROLLED_BACK;
            add_log_entry("Plan rolled back successfully");
        }
        
        /**
         * Get a summary of the plan
         */
        public string get_summary () {
            var summary = new StringBuilder();
            summary.append(@"Key: $(old_key.get_display_name())\n");
            summary.append(@"Reason: $(rotation_reason)\n");
            summary.append(@"Targets: $(targets.length)\n");
            
            if (status == RotationPlanStatus.COMPLETED && rollback_expires_at != null) {
                summary.append(@"Rollback expires: $(rollback_expires_at.format("%Y-%m-%d %H:%M"))\n");
            }
            
            return summary.str;
        }
        
        /**
         * Create a copy of this plan for editing
         */
        public RotationPlan create_copy () {
            var copy = new RotationPlan(old_key, rotation_reason);
            copy.name = @"$(name) (Copy)";
            copy.description = description;
            copy.backup_old_key = backup_old_key;
            copy.remove_old_key = remove_old_key;
            copy.verify_access = verify_access;
            copy.keep_old_key = keep_old_key;
            copy.enable_rollback = enable_rollback;
            copy.rollback_period = rollback_period;
            
            // Copy targets
            for (int i = 0; i < targets.length; i++) {
                var original_target = targets[i];
                var target_copy = new RotationTarget(
                    original_target.hostname,
                    original_target.username,
                    original_target.port
                );
                target_copy.proxy_jump = original_target.proxy_jump;
                copy.add_target(target_copy);
            }
            
            return copy;
        }
    }
}