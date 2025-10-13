/*
 * SSHer - SSH Key Generation
 * 
 * SSH key generation operations using ssh-keygen subprocess.
 */

namespace KeyMaker {
    
    public class SSHGeneration {
        
        /**
         * Generate SSH key using ssh-keygen
         */
        public static async SSHKey generate_key (KeyGenerationRequest request) throws KeyMakerError {
            // Validate request
            request.validate ();
            
            // Build key path
            var key_path = request.get_key_path ();
            
            // Ensure .ssh directory exists with proper permissions
            try {
                KeyMaker.Filesystem.ensure_ssh_dir ();
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to prepare SSH directory: %s", e.message);
            }
            
            // Check if key already exists
            var public_path = File.new_for_path (key_path.get_path () + ".pub");
            if (key_path.query_exists () || public_path.query_exists ()) {
                throw new KeyMakerError.OPERATION_FAILED ("Key %s already exists", request.filename);
            }
            
            // Build command args safely
            var cmd_list = new GenericArray<string> ();
            cmd_list.add ("ssh-keygen");
            cmd_list.add ("-t");
            cmd_list.add (request.key_type.to_string ());
            
            // Add algorithm-specific options
            switch (request.key_type) {
                case SSHKeyType.ED25519:
                    // Ed25519 has fixed size, no bits option
                    break;
                case SSHKeyType.RSA:
                    cmd_list.add ("-b");
                    cmd_list.add (request.key_size.to_string ());
                    break;
                case SSHKeyType.ECDSA:
                    cmd_list.add ("-b");
                    cmd_list.add (request.key_size.to_string ());
                    break;
            }
            
            cmd_list.add ("-f");
            cmd_list.add (key_path.get_path ());
            
            // Set passphrase (empty if none provided)
            cmd_list.add ("-N");
            cmd_list.add (request.passphrase ?? "");
            
            // Add comment if provided
            if (request.comment != null && request.comment.length > 0) {
                cmd_list.add ("-C");
                cmd_list.add (request.comment);
            }
            
            // Convert to array for subprocess
            string[] cmd = new string[cmd_list.length];
            for (int i = 0; i < cmd_list.length; i++) {
                cmd[i] = cmd_list[i];
            }
            
            try {
                KeyMaker.Log.info(KeyMaker.Log.Categories.SSH_OPS, "Generating %s key: %s", 
                                 request.key_type.to_string(), request.filename);
                
                var result = yield KeyMaker.Command.run_capture(cmd);
                
                if (result.status != 0) {
                    throw new KeyMakerError.SUBPROCESS_FAILED ("ssh-keygen failed with exit code %d: %s", 
                                                              result.status, result.stderr);
                }
                
                // Set proper permissions on private key
                KeyMaker.Filesystem.chmod_private (key_path);
                KeyMaker.Filesystem.chmod_public (public_path);
                
                // Get fingerprint for the new key
                var fingerprint = yield SSHMetadata.get_fingerprint (key_path);
                
                // Create SSHKey object
                var ssh_key = new SSHKey (
                    key_path,
                    public_path,
                    request.key_type,
                    request.comment ?? "",
                    fingerprint,
                    new DateTime.now_local (),
                    request.key_size
                );
                
                KeyMaker.Log.info(KeyMaker.Log.Categories.SSH_OPS, "Successfully generated key: %s", fingerprint);
                
                return ssh_key;
                
            } catch (KeyMakerError.OPERATION_CANCELLED e) {
                throw e;
            } catch (KeyMakerError e) {
                throw e;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to generate key: %s", e.message);
            }
        }
    }
}