/*
 * SSHer - Test Runner
 * 
 * Main entry point for running all tests
 */

using KeyMaker;

namespace KeyMakerTests {
    
    public static int main(string[] args) {
        print("SSHer Test Suite\n");
        print("===================\n\n");
        
        // Parse command line arguments
        bool test_utils = false;
        bool test_ssh_ops = false;
        bool test_rotation = false;
        bool test_tunneling = false;
        bool test_all = true;
        
        foreach (var arg in args) {
            switch (arg) {
                case "--test-utils":
                    test_utils = true;
                    test_all = false;
                    break;
                case "--test-ssh-ops":
                    test_ssh_ops = true;
                    test_all = false;
                    break;
                case "--test-rotation":
                    test_rotation = true;
                    test_all = false;
                    break;
                case "--test-tunneling":
                    test_tunneling = true;
                    test_all = false;
                    break;
            }
        }
        
        if (test_all) {
            test_utils = test_ssh_ops = test_rotation = test_tunneling = true;
        }
        
        var main_loop = new MainLoop();
        
        run_tests_async.begin(test_utils, test_ssh_ops, test_rotation, test_tunneling, (obj, res) => {
            try {
                var success = run_tests_async.end(res);
                main_loop.quit();
                if (success) {
                    print("\n🎉 All tests passed successfully!\n");
                    Posix.exit(0);
                } else {
                    print("\n❌ Some tests failed!\n");
                    Posix.exit(1);
                }
            } catch (Error e) {
                print("Test execution error: %s\n", e.message);
                main_loop.quit();
                Posix.exit(1);
            }
        });
        
        main_loop.run();
        return 0;
    }
    
    private static async bool run_tests_async(bool test_utils, bool test_ssh_ops, bool test_rotation, bool test_tunneling) throws Error {
        bool all_passed = true;
        
        try {
            if (test_utils) {
                yield UtilityTests.run_all();
                print("");
            }
            
            if (test_ssh_ops) {
                yield SSHOperationsTests.run_all();
                print("");
            }
            
            if (test_rotation) {
                yield RotationTests.run_all();
                print("");
            }
            
            if (test_tunneling) {
                yield TunnelingTests.run_all();
                print("");
            }
            
        } catch (Error e) {
            print("Test failed: %s\n", e.message);
            all_passed = false;
        }
        
        return all_passed;
    }
}