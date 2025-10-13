/*
 * SSHer - SSH Connection Pool
 * 
 * Optimizes SSH operations by reusing connections and caching results.
 */

namespace KeyMaker {
    
    /**
     * Connection pool for SSH operations to improve performance
     */
    public class ConnectionPool : Object {
        
        private static ConnectionPool _instance;
        private Gee.HashMap<string, CachedConnection> connections;
        private Gee.HashMap<string, CachedResult> result_cache;
        private const int MAX_CACHE_SIZE = 50;
        public const int CONNECTION_TIMEOUT_MS = 30000; // 30 seconds
        public const int CACHE_TTL_MS = 300000; // 5 minutes
        
        public static ConnectionPool get_instance() {
            if (_instance == null) {
                _instance = new ConnectionPool();
            }
            return _instance;
        }
        
        construct {
            connections = new Gee.HashMap<string, CachedConnection>();
            result_cache = new Gee.HashMap<string, CachedResult>();
            
            // Clean up expired connections every minute
            Timeout.add_seconds(60, cleanup_expired_entries);
        }
        
        /**
         * Get a cached SSH connection or create a new one
         */
        public async Subprocess? get_connection(string hostname, string username, int port = 22, string? key_path = null) throws KeyMakerError {
            var connection_key = @"$(username)@$(hostname):$(port)";
            if (key_path != null) {
                connection_key += @":$(key_path)";
            }
            
            var cached = connections.get(connection_key);
            if (cached != null && !cached.is_expired() && cached.subprocess != null) {
                try {
                    // Test if connection is still alive
                    if (!cached.subprocess.get_if_exited()) {
                        KeyMaker.Log.debug("CONNECTION_POOL", "Reusing cached connection for %s", connection_key);
                        return cached.subprocess;
                    }
                } catch (Error e) {
                    // Connection died, remove from cache
                    connections.unset(connection_key);
                }
            }
            
            // Create new connection with master socket for reuse
            try {
                var cmd = new GenericArray<string>();
                cmd.add("ssh");
                cmd.add("-M"); // Master mode
                cmd.add("-S");
                var socket_path = @"/tmp/ssh_$(username)_$(hostname)_$(port)";
                cmd.add(socket_path);
                cmd.add("-o");
                cmd.add("ControlPersist=30s");
                cmd.add("-o");
                cmd.add("ConnectTimeout=10");
                cmd.add("-o");
                cmd.add("BatchMode=yes");
                
                if (key_path != null) {
                    cmd.add("-i");
                    cmd.add(key_path);
                }
                
                if (port != 22) {
                    cmd.add("-p");
                    cmd.add(port.to_string());
                }
                
                cmd.add(@"$(username)@$(hostname)");
                cmd.add("sleep 30"); // Keep connection alive
                
                var launcher = new SubprocessLauncher(SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_SILENCE);
                var subprocess = launcher.spawnv(cmd.data);
                
                var cached_conn = new CachedConnection(subprocess, socket_path);
                connections.set(connection_key, cached_conn);
                
                KeyMaker.Log.debug("CONNECTION_POOL", "Created new cached connection for %s", connection_key);
                return subprocess;
                
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED("Failed to create SSH connection: %s", e.message);
            }
        }
        
        /**
         * Cache a command result to avoid repeated execution
         */
        public void cache_result(string command_key, Command.Result result) {
            // Implement LRU cache behavior
            if (result_cache.size >= MAX_CACHE_SIZE) {
                // Remove oldest entry
                var oldest_key = "";
                int64 oldest_time = int64.MAX;
                
                result_cache.map_iterator().foreach((key, cached) => {
                    if (cached.timestamp < oldest_time) {
                        oldest_time = cached.timestamp;
                        oldest_key = key;
                    }
                    return true;
                });
                
                if (oldest_key.length > 0) {
                    result_cache.unset(oldest_key);
                }
            }
            
            result_cache.set(command_key, new CachedResult(result));
            KeyMaker.Log.debug("CONNECTION_POOL", "Cached result for %s", command_key);
        }
        
        /**
         * Get a cached command result if available and not expired
         */
        public Command.Result? get_cached_result(string command_key) {
            var cached = result_cache.get(command_key);
            if (cached != null && !cached.is_expired()) {
                KeyMaker.Log.debug("CONNECTION_POOL", "Using cached result for %s", command_key);
                return cached.result;
            }
            return null;
        }
        
        /**
         * Clean up expired connections and cache entries
         */
        private bool cleanup_expired_entries() {
            var expired_connections = new GenericArray<string>();
            var expired_results = new GenericArray<string>();
            
            // Find expired connections
            connections.map_iterator().foreach((key, cached) => {
                if (cached.is_expired()) {
                    expired_connections.add(key);
                }
                return true;
            });
            
            // Find expired results
            result_cache.map_iterator().foreach((key, cached) => {
                if (cached.is_expired()) {
                    expired_results.add(key);
                }
                return true;
            });
            
            // Remove expired entries
            for (int i = 0; i < expired_connections.length; i++) {
                var key = expired_connections[i];
                var cached = connections.get(key);
                if (cached != null && cached.subprocess != null) {
                    try {
                        cached.subprocess.force_exit();
                    } catch (Error e) {
                        // Ignore cleanup errors
                    }
                }
                connections.unset(key);
                KeyMaker.Log.debug("CONNECTION_POOL", "Removed expired connection %s", key);
            }
            
            for (int i = 0; i < expired_results.length; i++) {
                result_cache.unset(expired_results[i]);
            }
            
            if (expired_connections.length > 0 || expired_results.length > 0) {
                KeyMaker.Log.debug("CONNECTION_POOL", "Cleaned up %u connections and %u cached results", 
                                 expired_connections.length, expired_results.length);
            }
            
            return Source.CONTINUE; // Continue periodic cleanup
        }
        
        /**
         * Clear all cached connections and results
         */
        public void clear_all() {
            connections.clear();
            result_cache.clear();
            KeyMaker.Log.info("CONNECTION_POOL", "Cleared all cached connections and results");
        }
    }
    
    private class CachedConnection {
        public Subprocess? subprocess;
        public string socket_path;
        public int64 timestamp;
        
        public CachedConnection(Subprocess subprocess, string socket_path) {
            this.subprocess = subprocess;
            this.socket_path = socket_path;
            this.timestamp = get_monotonic_time();
        }
        
        public bool is_expired() {
            var now = get_monotonic_time();
            return (now - timestamp) > (ConnectionPool.CONNECTION_TIMEOUT_MS * 1000);
        }
    }
    
    private class CachedResult {
        public Command.Result result;
        public int64 timestamp;
        
        public CachedResult(Command.Result result) {
            this.result = result;
            this.timestamp = get_monotonic_time();
        }
        
        public bool is_expired() {
            var now = get_monotonic_time();
            return (now - timestamp) > (ConnectionPool.CACHE_TTL_MS * 1000);
        }
    }
}