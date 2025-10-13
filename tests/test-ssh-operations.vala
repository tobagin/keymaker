/*
 * SSHer - SSH Operations Tests
 * 
 * Tests for SSH operations modules: generation, metadata, mutate
 */

using KeyMaker;

namespace KeyMakerTests {
    
    public class SSHOperationsTests {
        
        public static void test_key_generation_request() {
            // Test KeyGenerationRequest construction
            var request = new KeyGenerationRequest("test_key");
            assert(request.filename == "test_key");
            
            // Test property access
            request.key_type = SSHKeyType.ED25519;
            request.key_size = 2048;
            request.comment = "Test key";
            
            assert(request.key_type == SSHKeyType.ED25519);
            assert(request.key_size == 2048);
            assert(request.comment == "Test key");
            
            print("✓ KeyGenerationRequest tests passed\n");
        }
        
        public static void test_passphrase_change_request() {
            // Create mock SSHKey for testing
            var private_file = File.new_for_path("/tmp/test_key");
            var public_file = File.new_for_path("/tmp/test_key.pub");
            var ssh_key = new SSHKey(private_file, public_file);
            
            var request = new PassphraseChangeRequest(ssh_key);
            assert(request.ssh_key == ssh_key);
            
            // Test compatibility properties
            request.old_passphrase = "old_pass";
            request.passphrase = "new_pass";
            
            assert(request.old_passphrase == "old_pass");
            assert(request.passphrase == "new_pass");
            assert(request.key_path == ssh_key.private_path.get_path());
            
            print("✓ PassphraseChangeRequest tests passed\n");
        }
        
        public static void test_ssh_key_types() {
            // Test key type enum
            assert(SSHKeyType.ED25519.to_string() == "ed25519");
            assert(SSHKeyType.RSA.to_string() == "rsa");
            assert(SSHKeyType.ECDSA.to_string() == "ecdsa");
            
            // Test from_string
            try {
                assert(SSHKeyType.from_string("ed25519") == SSHKeyType.ED25519);
                assert(SSHKeyType.from_string("rsa") == SSHKeyType.RSA);
                assert(SSHKeyType.from_string("ecdsa") == SSHKeyType.ECDSA);
                
                print("✓ SSH key type tests passed\n");
            } catch (KeyMakerError e) {
                error("Key type test failed: %s", e.message);
            }
        }
        
        public static void test_ssh_key_model() {
            var private_file = File.new_for_path("/tmp/test_key");
            var public_file = File.new_for_path("/tmp/test_key.pub");
            
            var ssh_key = new SSHKey(private_file, public_file);
            assert(ssh_key.private_path == private_file);
            assert(ssh_key.public_path == public_file);
            
            // Test computed properties
            assert(ssh_key.get_display_name().length > 0);
            
            print("✓ SSH key model tests passed\n");
        }
        
        public static async void run_all() {
            print("Running SSH operations tests...\n");
            
            test_key_generation_request();
            test_passphrase_change_request();
            test_ssh_key_types();
            test_ssh_key_model();
            
            print("✓ All SSH operations tests passed!\n");
        }
    }
}