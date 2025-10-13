/*
 * SSHer - Rotation Tests
 * 
 * Tests for key rotation modules: plan, runner, deploy, rollback
 */

using KeyMaker;

namespace KeyMakerTests {
    
    public class RotationTests {
        
        public static void test_rotation_target() {
            var target = new RotationTarget("test.example.com", "user");
            assert(target.hostname == "test.example.com");
            assert(target.username == "user");
            assert(target.port == 22); // default port
            
            target.port = 2222;
            assert(target.port == 2222);
            
            var display_name = target.get_display_name();
            assert("user@test.example.com" in display_name);
            
            print("✓ RotationTarget tests passed\n");
        }
        
        public static void test_rotation_plan() {
            // Create mock SSH key
            var private_file = File.new_for_path("/tmp/test_key");
            var public_file = File.new_for_path("/tmp/test_key.pub");
            var ssh_key = new SSHKey(private_file, public_file);
            
            var plan = new RotationPlan(ssh_key, "Test rotation");
            assert(plan.old_key == ssh_key);
            assert(plan.rotation_reason == "Test rotation");
            assert(plan.current_stage == RotationStage.PLANNING);
            
            // Test target management
            var target = new RotationTarget("server1.com", "user");
            plan.add_target(target);
            assert(plan.targets.length == 1);
            
            plan.remove_target(target);
            assert(plan.targets.length == 0);
            
            // Test log functionality
            plan.add_log_entry("Test log entry");
            var logs = plan.get_log_entries();
            assert(logs.length == 1);
            assert("Test log entry" in logs[0]);
            
            print("✓ RotationPlan tests passed\n");
        }
        
        public static void test_rotation_stages() {
            // Test stage enum
            assert(RotationStage.PLANNING.to_string() == "Planning");
            assert(RotationStage.GENERATING_NEW_KEY.to_string() == "Generating New Key");
            assert(RotationStage.DEPLOYING_NEW_KEY.to_string() == "Deploying New Key");
            assert(RotationStage.COMPLETED.to_string() == "Completed");
            
            print("✓ RotationStage tests passed\n");
        }
        
        public static void test_progress_tracking() {
            var private_file = File.new_for_path("/tmp/test_key");
            var public_file = File.new_for_path("/tmp/test_key.pub");
            var ssh_key = new SSHKey(private_file, public_file);
            
            var plan = new RotationPlan(ssh_key);
            
            // Add targets to test progress calculation
            plan.add_target(new RotationTarget("server1.com", "user"));
            plan.add_target(new RotationTarget("server2.com", "user"));
            
            // Test initial progress
            var progress = plan.get_progress_percentage();
            assert(progress >= 0.0 && progress <= 100.0);
            
            print("✓ Progress tracking tests passed\n");
        }
        
        public static async void run_all() {
            print("Running rotation tests...\n");
            
            test_rotation_target();
            test_rotation_plan();
            test_rotation_stages();
            test_progress_tracking();
            
            print("✓ All rotation tests passed!\n");
        }
    }
}