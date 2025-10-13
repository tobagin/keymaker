/*
 * SSHer - Utility Tests
 * 
 * Tests for shared utilities: logging, filesystem, command execution
 */

using KeyMaker;

namespace KeyMakerTests {
    
    public class UtilityTests {
        
        public static void test_filesystem_utilities() {
            // Test safe filename generation
            var safe_name = KeyMaker.Filesystem.safe_base_filename("user/../key", "fallback", 20);
            assert(!safe_name.contains("/"));
            assert(!safe_name.contains(".."));
            
            // Test SSH directory path generation
            var ssh_dir = KeyMaker.Filesystem.get_ssh_directory();
            assert(ssh_dir.get_path().has_suffix("/.ssh"));
            
            print("✓ Filesystem utilities tests passed\n");
        }
        
        public static async void test_command_execution() {
            try {
                // Test basic command execution
                string[] cmd = {"echo", "hello world"};
                var result = yield KeyMaker.Command.run_capture(cmd);
                
                assert(result.status == 0);
                assert("hello world" in result.stdout);
                
                // Test command timeout (should work within timeout)
                string[] fast_cmd = {"echo", "fast"};
                var timeout_result = yield KeyMaker.Command.run_capture_with_timeout(fast_cmd, 5000);
                assert(timeout_result.status == 0);
                
                print("✓ Command execution tests passed\n");
            } catch (Error e) {
                error("Command test failed: %s", e.message);
            }
        }
        
        public static void test_logging() {
            // Test logging categories are defined
            assert(KeyMaker.Log.Categories.SSH_OPS != null);
            assert(KeyMaker.Log.Categories.VAULT != null);
            assert(KeyMaker.Log.Categories.ROTATION != null);
            
            // Test log methods don't crash
            KeyMaker.Log.info(KeyMaker.Log.Categories.SSH_OPS, "Test info message");
            KeyMaker.Log.debug(KeyMaker.Log.Categories.VAULT, "Test debug message"); 
            KeyMaker.Log.warning(KeyMaker.Log.Categories.ROTATION, "Test warning message");
            
            print("✓ Logging tests passed\n");
        }
        
        public static void test_settings_manager() {
            // Test settings don't crash
            var theme = KeyMaker.SettingsManager.get_theme_preference();
            assert(theme != null);
            
            // Test window size methods
            int width, height;
            bool maximized;
            KeyMaker.SettingsManager.get_window_geometry(out width, out height, out maximized);
            assert(width > 0);
            assert(height > 0);
            
            print("✓ Settings manager tests passed\n");
        }
        
        public static async void run_all() {
            print("Running utility tests...\n");
            
            test_filesystem_utilities();
            yield test_command_execution();
            test_logging();
            test_settings_manager();
            
            print("✓ All utility tests passed!\n");
        }
    }
}