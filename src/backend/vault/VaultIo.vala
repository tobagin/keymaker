/*
 * Key Maker - Vault I/O Operations
 *
 * Shared I/O operations for writing keys, sanitizing filenames, and managing permissions.
 */

namespace KeyMaker {
    public class VaultIO {
        
        /**
         * Write SSH key to ~/.ssh directory with proper permissions and naming
         */
        public static async SSHKey write_ssh_key_to_directory(string private_content, string public_content, 
                                                             SSHKeyType key_type, string display_name, 
                                                             string fingerprint) throws KeyMakerError {
            try {
                // Ensure SSH directory exists
                var ssh_dir = KeyMaker.Filesystem.ssh_dir ();
                KeyMaker.Filesystem.ensure_ssh_dir ();
                
                // Generate safe filename based on display name
                string base_name_input = (display_name.length == 0 || display_name == fingerprint) ? "restored_key" : display_name;
                var base_name = KeyMaker.Filesystem.safe_base_filename (base_name_input, "restored_key", 50);
                KeyMaker.Log.info(KeyMaker.Log.Categories.VAULT, "Sanitized key name: %s", base_name);
                
                // Find unique name (avoid overwriting existing keys)
                var private_name = base_name;
                var public_name = base_name + ".pub";
                var counter = 1;
                
                while (ssh_dir.get_child(private_name).query_exists() || ssh_dir.get_child(public_name).query_exists()) {
                    private_name = @"$(base_name)_$(counter)";
                    public_name = @"$(base_name)_$(counter).pub";
                    counter++;
                }
                
                var private_dest = ssh_dir.get_child(private_name);
                var public_dest = ssh_dir.get_child(public_name);
                
                // Write files
                yield private_dest.replace_contents_async(
                    private_content.data, 
                    null, false, FileCreateFlags.NONE, null, null
                );
                
                yield public_dest.replace_contents_async(
                    public_content.data, 
                    null, false, FileCreateFlags.NONE, null, null
                );
                
                // Set proper permissions
                KeyMaker.Filesystem.chmod_private(private_dest);
                KeyMaker.Filesystem.chmod_public(public_dest);
                
                // Create SSHKey object
                var now = new DateTime.now_local ();
                var bit_size = key_type == SSHKeyType.RSA ? 2048 : -1; // Default RSA size, -1 for others
                
                var ssh_key = new SSHKey (
                    private_dest,
                    public_dest,
                    key_type,
                    display_name,
                    fingerprint,
                    now,
                    bit_size
                );
                
                KeyMaker.Log.info(KeyMaker.Log.Categories.VAULT, "Successfully wrote key to SSH directory: %s (%s)", 
                                 display_name, fingerprint);
                
                return ssh_key;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to write SSH key to directory: %s", e.message);
            }
        }
        
        /**
         * Create temporary key files for processing
         */
        public static async void create_temp_key_files(string private_content, string public_content, 
                                                      out File private_file, out File public_file) throws KeyMakerError {
            try {
                // Create temporary directory
                var temp_dir_template = Path.build_filename(Environment.get_tmp_dir(), "keymaker_restore_XXXXXX");
                var temp_dir_path = DirUtils.mkdtemp(temp_dir_template);
                if (temp_dir_path == null) {
                    throw new KeyMakerError.OPERATION_FAILED ("Failed to create temporary directory");
                }
                
                var temp_dir = File.new_for_path(temp_dir_path);
                private_file = temp_dir.get_child("temp_key");
                public_file = temp_dir.get_child("temp_key.pub");
                
                // Write temporary files
                yield private_file.replace_contents_async(
                    private_content.data,
                    null, false, FileCreateFlags.NONE, null, null
                );
                
                yield public_file.replace_contents_async(
                    public_content.data,
                    null, false, FileCreateFlags.NONE, null, null
                );
                
                // Set proper permissions
                KeyMaker.Filesystem.chmod_private(private_file);
                KeyMaker.Filesystem.chmod_public(public_file);
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to create temporary key files: %s", e.message);
            }
        }
        
        /**
         * Clean up temporary files and directory
         */
        public static void cleanup_temp_files(File private_file, File public_file) {
            try {
                var temp_dir = private_file.get_parent();
                
                if (private_file.query_exists()) {
                    private_file.delete();
                }
                
                if (public_file.query_exists()) {
                    public_file.delete();
                }
                
                if (temp_dir != null && temp_dir.query_exists()) {
                    temp_dir.delete();
                }
                
            } catch (Error e) {
                KeyMaker.Log.warning(KeyMaker.Log.Categories.VAULT, "Failed to clean up temporary files: %s", e.message);
            }
        }
        
        /**
         * Calculate file checksum using SHA256
         */
        public static async string calculate_file_checksum(File file) throws KeyMakerError {
            try {
                var stream = yield file.read_async();
                var checksum = new Checksum(ChecksumType.SHA256);
                
                var buffer = new uint8[8192];
                size_t bytes_read;
                
                while ((bytes_read = yield stream.read_async(buffer)) > 0) {
                    checksum.update(buffer, bytes_read);
                }
                
                return checksum.get_string();
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to calculate file checksum: %s", e.message);
            }
        }
        
        /**
         * Get file size safely
         */
        public static int64 get_file_size(File file) {
            try {
                var info = file.query_info("standard::size", FileQueryInfoFlags.NONE);
                return info.get_size();
            } catch (Error e) {
                KeyMaker.Log.warning(KeyMaker.Log.Categories.VAULT, "Failed to get file size: %s", e.message);
                return 0;
            }
        }
        
        /**
         * Ensure directory exists with proper permissions
         */
        public static void ensure_vault_directory(File dir) throws KeyMakerError {
            try {
                if (!dir.query_exists()) {
                    dir.make_directory_with_parents();
                }
                // Set restrictive permissions
                KeyMaker.Filesystem.ensure_directory_with_perms(dir);
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to ensure vault directory: %s", e.message);
            }
        }
    }
}