/*
 * Key Maker - SSH Tunneling Manager
 * 
 * Central manager for SSH tunnel configurations and active tunnels.
 */

namespace KeyMaker {
    
    public class TunnelingManager : Object {
        
        public signal void tunnel_added (TunnelConfiguration config);
        public signal void tunnel_removed (TunnelConfiguration config);
        public signal void tunnel_started (ActiveTunnel tunnel);
        public signal void tunnel_stopped (ActiveTunnel tunnel);
        public signal void tunnel_status_changed (ActiveTunnel tunnel, TunnelStatus status);
        
        private GenericArray<TunnelConfiguration> configurations;
        private GenericArray<ActiveTunnel> active_tunnels;
        private GLib.Settings settings;
        
        private static TunnelingManager? _instance;
        
        public static TunnelingManager get_instance () {
            if (_instance == null) {
                _instance = new TunnelingManager();
            }
            return _instance;
        }
        
        private TunnelingManager () {
            configurations = new GenericArray<TunnelConfiguration>();
            active_tunnels = new GenericArray<ActiveTunnel>();
            settings = KeyMaker.SettingsManager.tunneling;
            
            load_configurations();
        }
        
        /**
         * Add a new tunnel configuration
         */
        public void add_configuration (TunnelConfiguration config) {
            configurations.add(config);
            save_configurations();
            
            KeyMaker.Log.info(KeyMaker.Log.Categories.TUNNELING, "Added tunnel configuration: %s", 
                             config.get_display_name());
            
            tunnel_added(config);
        }
        
        /**
         * Remove a tunnel configuration
         */
        public void remove_configuration (TunnelConfiguration config) {
            // Stop active tunnel if running
            var active_tunnel = find_active_tunnel(config);
            if (active_tunnel != null) {
                stop_tunnel.begin(config);
            }
            
            configurations.remove(config);
            save_configurations();
            
            KeyMaker.Log.info(KeyMaker.Log.Categories.TUNNELING, "Removed tunnel configuration: %s", 
                             config.get_display_name());
            
            tunnel_removed(config);
        }
        
        /**
         * Update an existing tunnel configuration
         */
        public void update_configuration (TunnelConfiguration config) {
            save_configurations();
            
            KeyMaker.Log.info(KeyMaker.Log.Categories.TUNNELING, "Updated tunnel configuration: %s", 
                             config.get_display_name());
        }
        
        /**
         * Get all tunnel configurations
         */
        public GenericArray<TunnelConfiguration> get_configurations () {
            return configurations;
        }
        
        /**
         * Get all active tunnels
         */
        public GenericArray<ActiveTunnel> get_active_tunnels () {
            return active_tunnels;
        }
        
        /**
         * Start a tunnel
         */
        public async void start_tunnel (TunnelConfiguration config, bool auto_reconnect = true) throws KeyMakerError {
            // Check if tunnel is already active
            var existing_tunnel = find_active_tunnel(config);
            if (existing_tunnel != null) {
                throw new KeyMakerError.OPERATION_FAILED ("Tunnel is already active");
            }
            
            var tunnel = new ActiveTunnel(config);
            
            // Connect signals
            tunnel.status_changed.connect((status) => {
                tunnel_status_changed(tunnel, status);
            });
            
            tunnel.connection_established.connect(() => {
                config.last_used = new DateTime.now_local();
                save_configurations();
            });
            
            tunnel.connection_lost.connect(() => {
                KeyMaker.Log.warning(KeyMaker.Log.Categories.TUNNELING, "Connection lost for tunnel: %s", 
                                    config.get_display_name());
            });
            
            active_tunnels.add(tunnel);
            
            try {
                yield tunnel.start(auto_reconnect);
                
                KeyMaker.Log.info(KeyMaker.Log.Categories.TUNNELING, "Started tunnel: %s", 
                                 config.get_display_name());
                
                tunnel_started(tunnel);
                
            } catch (KeyMakerError e) {
                active_tunnels.remove(tunnel);
                throw e;
            }
        }
        
        /**
         * Stop a tunnel
         */
        public async void stop_tunnel (TunnelConfiguration config) throws KeyMakerError {
            var tunnel = find_active_tunnel(config);
            if (tunnel == null) {
                throw new KeyMakerError.OPERATION_FAILED ("Tunnel is not active");
            }
            
            yield tunnel.stop();
            active_tunnels.remove(tunnel);
            
            KeyMaker.Log.info(KeyMaker.Log.Categories.TUNNELING, "Stopped tunnel: %s", 
                             config.get_display_name());
            
            tunnel_stopped(tunnel);
        }
        
        /**
         * Stop all active tunnels
         */
        public async void stop_all_tunnels () {
            var tunnels_to_stop = new GenericArray<ActiveTunnel>();
            
            // Copy active tunnels to avoid modifying collection during iteration
            for (int i = 0; i < active_tunnels.length; i++) {
                tunnels_to_stop.add(active_tunnels[i]);
            }
            
            for (int i = 0; i < tunnels_to_stop.length; i++) {
                try {
                    yield tunnels_to_stop[i].stop();
                } catch (KeyMakerError e) {
                    KeyMaker.Log.warning(KeyMaker.Log.Categories.TUNNELING, 
                                        "Error stopping tunnel: %s", e.message);
                }
            }
            
            active_tunnels.remove_range(0, active_tunnels.length);
            
            KeyMaker.Log.info(KeyMaker.Log.Categories.TUNNELING, "Stopped all tunnels");
        }
        
        /**
         * Start all auto-start tunnels
         */
        public async void start_auto_start_tunnels () {
            for (int i = 0; i < configurations.length; i++) {
                var config = configurations[i];
                if (config.auto_start) {
                    try {
                        yield start_tunnel(config);
                    } catch (KeyMakerError e) {
                        KeyMaker.Log.warning(KeyMaker.Log.Categories.TUNNELING, 
                                            "Failed to auto-start tunnel %s: %s", 
                                            config.get_display_name(), e.message);
                    }
                }
            }
        }
        
        /**
         * Check if a tunnel is active
         */
        public bool is_tunnel_active (TunnelConfiguration config) {
            return find_active_tunnel(config) != null;
        }
        
        /**
         * Find active tunnel by configuration
         */
        public ActiveTunnel? find_active_tunnel (TunnelConfiguration config) {
            for (int i = 0; i < active_tunnels.length; i++) {
                var tunnel = active_tunnels[i];
                if (tunnel.config.config_id == config.config_id) {
                    return tunnel;
                }
            }
            return null;
        }
        
        /**
         * Find configuration by ID
         */
        public TunnelConfiguration? find_configuration (string config_id) {
            for (int i = 0; i < configurations.length; i++) {
                var config = configurations[i];
                if (config.config_id == config_id) {
                    return config;
                }
            }
            return null;
        }
        
        /**
         * Get tunnel statistics
         */
        public TunnelStatistics get_statistics () {
            var stats = new TunnelStatistics();
            stats.total_configurations = (int)configurations.length;
            stats.active_tunnels = (int)active_tunnels.length;
            
            for (int i = 0; i < active_tunnels.length; i++) {
                var tunnel = active_tunnels[i];
                switch (tunnel.status) {
                    case TunnelStatus.CONNECTING:
                        stats.connecting_tunnels++;
                        break;
                    case TunnelStatus.ACTIVE:
                        stats.healthy_tunnels++;
                        break;
                    case TunnelStatus.ERROR:
                        stats.failed_tunnels++;
                        break;
                }
            }
            
            return stats;
        }
        
        private void load_configurations () {
            try {
                var saved_configs = settings.get_strv("saved-tunnels");
                
                foreach (var config_string in saved_configs) {
                    try {
                        var variant = Variant.parse(null, config_string);
                        var config = TunnelConfiguration.from_variant(variant);
                        if (config != null) {
                            configurations.add(config);
                        }
                    } catch (Error e) {
                        KeyMaker.Log.warning(KeyMaker.Log.Categories.TUNNELING, 
                                            "Failed to load tunnel configuration: %s", e.message);
                    }
                }
                
                KeyMaker.Log.info(KeyMaker.Log.Categories.TUNNELING, "Loaded %u tunnel configurations", 
                                 configurations.length);
                
            } catch (Error e) {
                KeyMaker.Log.error(KeyMaker.Log.Categories.TUNNELING, "Failed to load configurations: %s", e.message);
            }
        }
        
        private void save_configurations () {
            try {
                var config_strings = new GenericArray<string>();
                
                for (int i = 0; i < configurations.length; i++) {
                    var config = configurations[i];
                    var variant = config.to_variant();
                    config_strings.add(variant.print(true));
                }
                
                settings.set_strv("saved-tunnels", config_strings.data);
                
                KeyMaker.Log.debug(KeyMaker.Log.Categories.TUNNELING, "Saved %u tunnel configurations", 
                                  configurations.length);
                
            } catch (Error e) {
                KeyMaker.Log.error(KeyMaker.Log.Categories.TUNNELING, "Failed to save configurations: %s", e.message);
            }
        }
    }
    
    /**
     * Tunnel statistics data structure
     */
    public class TunnelStatistics : Object {
        public int total_configurations { get; set; }
        public int active_tunnels { get; set; }
        public int healthy_tunnels { get; set; }
        public int connecting_tunnels { get; set; }
        public int failed_tunnels { get; set; }
        
        public string get_summary () {
            return @"$(active_tunnels) active ($(healthy_tunnels) healthy, $(failed_tunnels) failed) of $(total_configurations) total";
        }
    }
}