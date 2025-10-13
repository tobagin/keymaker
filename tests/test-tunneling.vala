/*
 * SSHer - Tunneling Tests
 * 
 * Tests for tunneling modules: configuration, active-tunnel, manager
 */

using KeyMaker;

namespace KeyMakerTests {
    
    public class TunnelingTests {
        
        public static void test_tunnel_configuration() {
            var config = new TunnelConfiguration();
            
            // Test basic properties
            config.name = "Test Tunnel";
            config.tunnel_type = TunnelType.LOCAL_PORT_FORWARD;
            config.hostname = "example.com";
            config.username = "user";
            config.port = 22;
            config.local_port = 8080;
            config.remote_port = 80;
            
            assert(config.name == "Test Tunnel");
            assert(config.tunnel_type == TunnelType.LOCAL_PORT_FORWARD);
            assert(config.hostname == "example.com");
            assert(config.username == "user");
            assert(config.port == 22);
            assert(config.local_port == 8080);
            assert(config.remote_port == 80);
            
            // Test validation
            assert(config.validate() == true);
            
            // Test display name generation
            var display_name = config.get_display_name();
            assert(display_name.length > 0);
            assert("Test Tunnel" in display_name);
            
            print("✓ TunnelConfiguration tests passed\n");
        }
        
        public static void test_tunnel_types() {
            // Test tunnel type enum
            assert(TunnelType.LOCAL_PORT_FORWARD.to_string() == "Local Port Forward");
            assert(TunnelType.REMOTE_PORT_FORWARD.to_string() == "Remote Port Forward");
            assert(TunnelType.DYNAMIC_SOCKS.to_string() == "Dynamic SOCKS");
            
            print("✓ TunnelType tests passed\n");
        }
        
        public static void test_tunnel_status() {
            // Test tunnel status enum
            assert(TunnelStatus.INACTIVE.to_string() == "Inactive");
            assert(TunnelStatus.CONNECTING.to_string() == "Connecting");
            assert(TunnelStatus.ACTIVE.to_string() == "Active");
            assert(TunnelStatus.ERROR.to_string() == "Error");
            assert(TunnelStatus.DISCONNECTING.to_string() == "Disconnecting");
            
            print("✓ TunnelStatus tests passed\n");
        }
        
        public static void test_active_tunnel() {
            var config = new TunnelConfiguration();
            config.name = "Test Active Tunnel";
            config.tunnel_type = TunnelType.LOCAL_PORT_FORWARD;
            config.hostname = "example.com";
            config.username = "user";
            
            var tunnel = new ActiveTunnel(config);
            assert(tunnel.config == config);
            assert(tunnel.status == TunnelStatus.INACTIVE);
            
            // Test duration string method
            var duration = tunnel.get_duration_string();
            assert(duration.length > 0);
            
            print("✓ ActiveTunnel tests passed\n");
        }
        
        public static void test_configuration_serialization() {
            var config = new TunnelConfiguration();
            config.name = "Serialization Test";
            config.tunnel_type = TunnelType.DYNAMIC_SOCKS;
            config.hostname = "test.com";
            config.username = "testuser";
            config.local_port = 1080;
            
            try {
                // Test serialization
                var variant = config.to_variant();
                assert(variant != null);
                
                // Test deserialization
                var deserialized = TunnelConfiguration.from_variant(variant);
                assert(deserialized != null);
                assert(deserialized.name == config.name);
                assert(deserialized.tunnel_type == config.tunnel_type);
                assert(deserialized.hostname == config.hostname);
                assert(deserialized.username == config.username);
                assert(deserialized.local_port == config.local_port);
                
                print("✓ Configuration serialization tests passed\n");
            } catch (Error e) {
                error("Serialization test failed: %s", e.message);
            }
        }
        
        public static async void run_all() {
            print("Running tunneling tests...\n");
            
            test_tunnel_configuration();
            test_tunnel_types();
            test_tunnel_status();
            test_active_tunnel();
            test_configuration_serialization();
            
            print("✓ All tunneling tests passed!\n");
        }
    }
}