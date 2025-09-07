/*
 * Key Maker - Key Rotation Deployment
 * 
 * Handles deploying SSH keys to remote targets using ssh-copy-id.
 */

namespace KeyMaker {
    
    public class RotationDeploy {
        
        /**
         * Deploy SSH key to a target server using ssh-copy-id
         */
        public static async void deploy_key_to_target (SSHKey ssh_key, RotationTarget target) throws KeyMakerError {
            try {
                KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Deploying key %s to %s", 
                                 ssh_key.fingerprint, target.get_display_name());
                
                var cmd = build_ssh_copy_id_command(ssh_key, target);
                
                var result = yield KeyMaker.Command.run_capture(cmd);
                
                if (result.status != 0) {
                    var error_msg = @"ssh-copy-id failed with exit code $(result.status): $(result.stderr)";
                    throw new KeyMakerError.SUBPROCESS_FAILED(error_msg);
                }
                
                KeyMaker.Log.debug(KeyMaker.Log.Categories.ROTATION, "ssh-copy-id output: %s", result.stdout);
                
            } catch (KeyMakerError e) {
                throw e;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED("Failed to deploy key: %s", e.message);
            }
        }
        
        /**
         * Verify that SSH key can be used to access the target
         */
        public static async void verify_key_access (SSHKey ssh_key, RotationTarget target) throws KeyMakerError {
            try {
                KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Verifying access to %s with key %s", 
                                 target.get_display_name(), ssh_key.fingerprint);
                
                var cmd = build_ssh_test_command(ssh_key, target);
                
                var result = yield KeyMaker.Command.run_capture(cmd);
                
                if (result.status != 0) {
                    var error_msg = @"SSH access verification failed with exit code $(result.status): $(result.stderr)";
                    throw new KeyMakerError.SUBPROCESS_FAILED(error_msg);
                }
                
                KeyMaker.Log.debug(KeyMaker.Log.Categories.ROTATION, "SSH verification successful: %s", result.stdout);
                
            } catch (KeyMakerError e) {
                throw e;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED("Failed to verify access: %s", e.message);
            }
        }
        
        /**
         * Deploy key to multiple targets sequentially
         */
        public static async void deploy_key_to_targets (SSHKey ssh_key, GenericArray<RotationTarget> targets) throws KeyMakerError {
            for (int i = 0; i < targets.length; i++) {
                var target = targets[i];
                try {
                    yield deploy_key_to_target(ssh_key, target);
                } catch (KeyMakerError e) {
                    KeyMaker.Log.warning(KeyMaker.Log.Categories.ROTATION, "Deployment failed for target %d: %s", i, e.message);
                    // Continue with other deployments
                }
            }
        }
        
        /**
         * Remove SSH key from remote target's authorized_keys
         */
        public static async void remove_key_from_target (SSHKey ssh_key, RotationTarget target) throws KeyMakerError {
            try {
                KeyMaker.Log.info(KeyMaker.Log.Categories.ROTATION, "Removing key %s from %s", 
                                 ssh_key.fingerprint, target.get_display_name());
                
                // Get the public key content to match against
                var public_key_content = SSHMetadata.get_public_key_content(ssh_key);
                var key_parts = public_key_content.strip().split(" ");
                
                if (key_parts.length < 2) {
                    throw new KeyMakerError.OPERATION_FAILED("Invalid public key format");
                }
                
                var key_data = key_parts[1]; // The base64 encoded key data
                
                // Build SSH command to remove the key
                var cmd = build_ssh_remove_key_command(key_data, target);
                
                var result = yield KeyMaker.Command.run_capture(cmd);
                
                if (result.status != 0) {
                    var error_msg = @"Failed to remove key with exit code $(result.status): $(result.stderr)";
                    throw new KeyMakerError.SUBPROCESS_FAILED(error_msg);
                }
                
                KeyMaker.Log.debug(KeyMaker.Log.Categories.ROTATION, "Key removal result: %s", result.stdout);
                
            } catch (KeyMakerError e) {
                throw e;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED("Failed to remove key from target: %s", e.message);
            }
        }
        
        private static string[] build_ssh_copy_id_command (SSHKey ssh_key, RotationTarget target) {
            var cmd = new GenericArray<string>();
            cmd.add("ssh-copy-id");
            
            // Use the private key file
            cmd.add("-i");
            cmd.add(ssh_key.private_path.get_path());
            
            // Add port if not default
            if (target.port != 22) {
                cmd.add("-p");
                cmd.add(target.port.to_string());
            }
            
            // Add options for non-interactive use
            cmd.add("-o");
            cmd.add("BatchMode=yes");
            cmd.add("-o");
            cmd.add("StrictHostKeyChecking=ask");
            
            // Add proxy jump if specified
            if (target.proxy_jump != null && target.proxy_jump.length > 0) {
                cmd.add("-o");
                cmd.add(@"ProxyJump=$(target.proxy_jump)");
            }
            
            // Add the target
            if (target.port != 22) {
                cmd.add(@"$(target.username)@$(target.hostname)");
            } else {
                cmd.add(@"$(target.username)@$(target.hostname)");
            }
            
            string[] result = new string[cmd.length];
            for (int i = 0; i < cmd.length; i++) {
                result[i] = cmd[i];
            }
            
            return result;
        }
        
        private static string[] build_ssh_test_command (SSHKey ssh_key, RotationTarget target) {
            var cmd = new GenericArray<string>();
            cmd.add("ssh");
            
            // Use the private key file
            cmd.add("-i");
            cmd.add(ssh_key.private_path.get_path());
            
            // Add port if not default
            if (target.port != 22) {
                cmd.add("-p");
                cmd.add(target.port.to_string());
            }
            
            // Add options for testing
            cmd.add("-o");
            cmd.add("BatchMode=yes");
            cmd.add("-o");
            cmd.add("ConnectTimeout=10");
            cmd.add("-o");
            cmd.add("StrictHostKeyChecking=no");
            
            // Add proxy jump if specified
            if (target.proxy_jump != null && target.proxy_jump.length > 0) {
                cmd.add("-o");
                cmd.add(@"ProxyJump=$(target.proxy_jump)");
            }
            
            // Add the target and test command
            cmd.add(@"$(target.username)@$(target.hostname)");
            cmd.add("echo 'SSH connection successful'");
            
            string[] result = new string[cmd.length];
            for (int i = 0; i < cmd.length; i++) {
                result[i] = cmd[i];
            }
            
            return result;
        }
        
        private static string[] build_ssh_remove_key_command (string key_data, RotationTarget target) {
            var cmd = new GenericArray<string>();
            cmd.add("ssh");
            
            // Add port if not default
            if (target.port != 22) {
                cmd.add("-p");
                cmd.add(target.port.to_string());
            }
            
            // Add options
            cmd.add("-o");
            cmd.add("BatchMode=yes");
            cmd.add("-o");
            cmd.add("StrictHostKeyChecking=no");
            
            // Add proxy jump if specified
            if (target.proxy_jump != null && target.proxy_jump.length > 0) {
                cmd.add("-o");
                cmd.add(@"ProxyJump=$(target.proxy_jump)");
            }
            
            // Add the target
            cmd.add(@"$(target.username)@$(target.hostname)");
            
            // Command to remove the key from authorized_keys
            var remove_cmd = @"sed -i '/$(key_data)/d' ~/.ssh/authorized_keys";
            cmd.add(remove_cmd);
            
            string[] result = new string[cmd.length];
            for (int i = 0; i < cmd.length; i++) {
                result[i] = cmd[i];
            }
            
            return result;
        }
    }
}