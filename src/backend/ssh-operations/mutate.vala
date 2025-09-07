/*
 * Key Maker - SSH Key Mutation Operations
 * 
 * SSH key mutation operations like deleting keys and changing passphrases.
 */

namespace KeyMaker {
    
    public class SSHMutate {
        
        /**
         * Change passphrase of an SSH key
         */
        public static async void change_passphrase (PassphraseChangeRequest request) throws KeyMakerError {
            try {
                KeyMaker.Log.info(KeyMaker.Log.Categories.SSH_OPS, "Changing passphrase for key: %s", 
                                 request.key_path);
                
                // Build command with non-interactive flags
                var cmd_list = new GenericArray<string> ();
                cmd_list.add ("ssh-keygen");
                cmd_list.add ("-p");
                cmd_list.add ("-f");
                cmd_list.add (request.key_path);
                
                // Add old passphrase (-P flag)
                cmd_list.add ("-P");
                cmd_list.add (request.old_passphrase ?? "");
                
                // Add new passphrase (-N flag)
                cmd_list.add ("-N");
                cmd_list.add (request.new_passphrase ?? "");
                
                // Convert to array for subprocess
                string[] cmd = new string[cmd_list.length];
                for (int i = 0; i < cmd_list.length; i++) {
                    cmd[i] = cmd_list[i];
                }
                
                var result = yield KeyMaker.Command.run_capture(cmd);
                
                if (result.status != 0) {
                    throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to change passphrase: %s", result.stderr);
                }
                
                KeyMaker.Log.info(KeyMaker.Log.Categories.SSH_OPS, "Successfully changed passphrase for key");
                
            } catch (KeyMakerError e) {
                throw e;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to change passphrase: %s", e.message);
            }
        }
        
        /**
         * Delete SSH key pair (both private and public keys)
         */
        public static async void delete_key_pair (SSHKey ssh_key) throws KeyMakerError {
            try {
                KeyMaker.Log.info(KeyMaker.Log.Categories.SSH_OPS, "Deleting key pair: %s", 
                                 ssh_key.get_display_name());
                
                bool private_deleted = false;
                bool public_deleted = false;
                var errors = new GenericArray<string>();
                
                // Delete private key
                if (ssh_key.private_path.query_exists ()) {
                    try {
                        yield ssh_key.private_path.delete_async ();
                        private_deleted = true;
                        KeyMaker.Log.debug(KeyMaker.Log.Categories.SSH_OPS, "Deleted private key: %s", 
                                          ssh_key.private_path.get_path());
                    } catch (Error e) {
                        errors.add (@"Failed to delete private key: $(e.message)");
                    }
                } else {
                    private_deleted = true; // Consider it "deleted" if it didn't exist
                }
                
                // Delete public key
                if (ssh_key.public_path.query_exists ()) {
                    try {
                        yield ssh_key.public_path.delete_async ();
                        public_deleted = true;
                        KeyMaker.Log.debug(KeyMaker.Log.Categories.SSH_OPS, "Deleted public key: %s", 
                                          ssh_key.public_path.get_path());
                    } catch (Error e) {
                        errors.add (@"Failed to delete public key: $(e.message)");
                    }
                } else {
                    public_deleted = true; // Consider it "deleted" if it didn't exist
                }
                
                // Check if operation was successful
                if (!private_deleted || !public_deleted) {
                    var error_msg = new StringBuilder("Failed to delete key pair:");
                    for (int i = 0; i < errors.length; i++) {
                        error_msg.append(" ");
                        error_msg.append(errors[i]);
                    }
                    throw new KeyMakerError.OPERATION_FAILED(error_msg.str);
                }
                
                KeyMaker.Log.info(KeyMaker.Log.Categories.SSH_OPS, "Successfully deleted key pair");
                
            } catch (KeyMakerError e) {
                throw e;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to delete key pair: %s", e.message);
            }
        }
        
        /**
         * Set key file permissions to secure values
         */
        public static void secure_key_permissions(SSHKey ssh_key) throws KeyMakerError {
            try {
                if (ssh_key.private_path.query_exists()) {
                    KeyMaker.Filesystem.chmod_private(ssh_key.private_path);
                }
                
                if (ssh_key.public_path.query_exists()) {
                    KeyMaker.Filesystem.chmod_public(ssh_key.public_path);
                }
                
                KeyMaker.Log.debug(KeyMaker.Log.Categories.SSH_OPS, "Secured permissions for key: %s", 
                                  ssh_key.get_display_name());
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to secure key permissions: %s", e.message);
            }
        }
    }
}