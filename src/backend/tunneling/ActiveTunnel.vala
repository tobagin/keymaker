/*
 * SSHer - Active SSH Tunnel
 * 
 * Manages individual active SSH tunnel processes.
 */

namespace KeyMaker {
    
    public class ActiveTunnel : Object {
        
        public signal void status_changed (TunnelStatus status);
        public signal void connection_failed (string error);
        public signal void connection_established ();
        public signal void connection_lost ();
        
        public TunnelConfiguration config { get; set; }
        public TunnelStatus status { get; private set; default = TunnelStatus.INACTIVE; }
        public DateTime? started_at { get; private set; }
        public DateTime? stopped_at { get; private set; }
        public string error_message { get; private set; default = ""; }
        public int process_id { get; private set; default = -1; }
        
        private Subprocess? process;
        private Cancellable? cancellable;
        private bool auto_reconnect = false;
        private int reconnect_attempts = 0;
        private const int MAX_RECONNECT_ATTEMPTS = 3;
        private uint reconnect_timer_id = 0;
        
        public ActiveTunnel (TunnelConfiguration tunnel_config) {
            config = tunnel_config;
        }
        
        /**
         * Start the SSH tunnel
         */
        public async void start (bool enable_auto_reconnect = false) throws KeyMakerError {
            if (status != TunnelStatus.INACTIVE) {
                throw new KeyMakerError.OPERATION_FAILED ("Tunnel is already active or starting");
            }
            
            if (!config.validate()) {
                throw new KeyMakerError.OPERATION_FAILED ("Invalid tunnel configuration");
            }
            
            auto_reconnect = enable_auto_reconnect;
            cancellable = new Cancellable();
            
            try {
                KeyMaker.Log.info(KeyMaker.Log.Categories.TUNNELING, "Starting tunnel: %s", config.get_display_name());
                
                yield start_tunnel_process();
                
            } catch (KeyMakerError e) {
                yield update_status(TunnelStatus.ERROR);
                error_message = e.message;
                throw e;
            }
        }
        
        /**
         * Stop the SSH tunnel
         */
        public async void stop () {
            KeyMaker.Log.info(KeyMaker.Log.Categories.TUNNELING, "Stopping tunnel: %s", config.get_display_name());
            
            auto_reconnect = false; // Disable auto-reconnect when manually stopping
            
            if (reconnect_timer_id > 0) {
                Source.remove(reconnect_timer_id);
                reconnect_timer_id = 0;
            }
            
            if (cancellable != null) {
                cancellable.cancel();
            }
            
            yield update_status(TunnelStatus.DISCONNECTING);
            
            if (process != null) {
                try {
                    process.force_exit();
                    yield process.wait_async();
                } catch (Error e) {
                    KeyMaker.Log.warning(KeyMaker.Log.Categories.TUNNELING, "Error stopping tunnel process: %s", e.message);
                }
                process = null;
            }
            
            yield update_status(TunnelStatus.INACTIVE);
            stopped_at = new DateTime.now_local();
            process_id = -1;
        }
        
        /**
         * Check if the tunnel is currently active
         */
        public bool is_active () {
            return status == TunnelStatus.ACTIVE;
        }
        
        /**
         * Get tunnel uptime
         */
        public TimeSpan get_uptime () {
            if (started_at == null) {
                return 0;
            }
            
            var end_time = stopped_at ?? new DateTime.now_local();
            return end_time.difference(started_at);
        }
        
        /**
         * Get formatted uptime string
         */
        public string get_uptime_string () {
            var uptime = get_uptime();
            if (uptime <= 0) {
                return "Not running";
            }
            
            var seconds = uptime / TimeSpan.SECOND;
            var minutes = seconds / 60;
            var hours = minutes / 60;
            
            if (hours > 0) {
                return @"$(hours)h $(minutes % 60)m";
            } else if (minutes > 0) {
                return @"$(minutes)m $(seconds % 60)s";
            } else {
                return @"$(seconds)s";
            }
        }
        
        /**
         * Get formatted duration string (alias for uptime)
         */
        public string get_duration_string () {
            return get_uptime_string();
        }
        
        private async void start_tunnel_process () throws KeyMakerError {
            yield update_status(TunnelStatus.CONNECTING);

            try {
                var ssh_args = config.get_ssh_arguments();
                string[] cmd = new string[ssh_args.length];
                for (int i = 0; i < ssh_args.length; i++) {
                    cmd[i] = ssh_args[i];
                }

                KeyMaker.Log.debug(KeyMaker.Log.Categories.TUNNELING, "SSH command: %s", string.joinv(" ", cmd));

                // NOTE: This uses direct Subprocess instead of Command utility because SSH tunnels
                // run indefinitely as long-running background processes that need to be monitored.
                // This is an approved exception until Command utility supports background processes.
                process = new Subprocess.newv (cmd, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                process_id = (int)process.get_identifier();
                
                // Monitor process
                yield monitor_tunnel_process();
                
            } catch (Error e) {
                throw new KeyMakerError.SUBPROCESS_FAILED ("Failed to start tunnel process: %s", e.message);
            }
        }
        
        private async void monitor_tunnel_process () throws KeyMakerError {
            if (process == null) {
                throw new KeyMakerError.OPERATION_FAILED ("No process to monitor");
            }
            
            try {
                // Give the process a moment to establish the connection
                yield wait_with_timeout(2000); // 2 seconds
                
                // Check if process is still running
                if (process.get_if_exited()) {
                    var exit_status = process.get_exit_status();
                    var error_output = yield read_process_stderr();
                    var error_msg = @"SSH tunnel process exited with status $(exit_status): $(error_output)";
                    
                    yield update_status(TunnelStatus.ERROR);
                    error_message = error_msg;
                    
                    if (auto_reconnect && reconnect_attempts < MAX_RECONNECT_ATTEMPTS) {
                        yield attempt_reconnect();
                        return;
                    }
                    
                    throw new KeyMakerError.SUBPROCESS_FAILED(error_msg);
                }
                
                // Process is still running, assume connection is established
                yield update_status(TunnelStatus.ACTIVE);
                started_at = new DateTime.now_local();
                connection_established();
                
                // Continue monitoring in the background
                monitor_process_background.begin();
                
            } catch (KeyMakerError e) {
                throw e;
            } catch (Error e) {
                throw new KeyMakerError.OPERATION_FAILED ("Failed to monitor tunnel process: %s", e.message);
            }
        }
        
        private async void monitor_process_background () {
            if (process == null) return;
            
            try {
                yield process.wait_async(cancellable);
                
                // Process has exited
                if (!cancellable.is_cancelled()) {
                    var exit_status = process.get_exit_status();
                    KeyMaker.Log.warning(KeyMaker.Log.Categories.TUNNELING, 
                                        "Tunnel process exited unexpectedly with status: %d", exit_status);
                    
                    connection_lost();
                    
                    if (auto_reconnect && reconnect_attempts < MAX_RECONNECT_ATTEMPTS) {
                        yield attempt_reconnect();
                    } else {
                        yield update_status(TunnelStatus.ERROR);
                        error_message = @"Process exited with status $(exit_status)";
                    }
                }
                
            } catch (Error e) {
                if (e is IOError.CANCELLED) {
                    KeyMaker.Log.debug(KeyMaker.Log.Categories.TUNNELING, "Tunnel monitoring cancelled");
                } else {
                    KeyMaker.Log.error(KeyMaker.Log.Categories.TUNNELING, "Error monitoring tunnel: %s", e.message);
                    yield update_status(TunnelStatus.ERROR);
                    error_message = e.message;
                }
            }
        }
        
        private async void attempt_reconnect () {
            reconnect_attempts++;
            
            KeyMaker.Log.info(KeyMaker.Log.Categories.TUNNELING, 
                             "Attempting reconnect %d/%d for tunnel: %s", 
                             reconnect_attempts, MAX_RECONNECT_ATTEMPTS, config.get_display_name());
            
            yield update_status(TunnelStatus.CONNECTING);
            
            // Wait before reconnecting
            reconnect_timer_id = Timeout.add_seconds(5, () => {
                start_tunnel_process.begin();
                reconnect_timer_id = 0;
                return false;
            });
        }
        
        private async string read_process_stderr () {
            if (process == null) return "";
            
            try {
                var stderr_stream = process.get_stderr_pipe();
                if (stderr_stream == null) return "";
                
                var data_stream = new DataInputStream(stderr_stream);
                var error_lines = new GenericArray<string>();
                
                string? line;
                while ((line = data_stream.read_line()) != null) {
                    error_lines.add(line);
                    if (error_lines.length > 10) break; // Limit output
                }
                
                return string.joinv("\n", error_lines.data);
                
            } catch (Error e) {
                return @"Failed to read error output: $(e.message)";
            }
        }
        
        private async void wait_with_timeout (int timeout_ms) throws KeyMakerError {
            var main_context = MainContext.default();
            var timeout_reached = false;
            
            var timeout_source = new TimeoutSource(timeout_ms);
            timeout_source.set_callback(() => {
                timeout_reached = true;
                return false;
            });
            timeout_source.attach(main_context);
            
            while (!timeout_reached && main_context.pending()) {
                main_context.iteration(false);
                yield;
            }
            
            timeout_source.destroy();
        }
        
        private async void update_status (TunnelStatus new_status) {
            if (status == new_status) return;
            
            status = new_status;
            
            KeyMaker.Log.debug(KeyMaker.Log.Categories.TUNNELING, 
                              "Tunnel %s status changed to: %s", 
                              config.get_display_name(), status.to_string());
            
            status_changed(status);
        }
    }
}