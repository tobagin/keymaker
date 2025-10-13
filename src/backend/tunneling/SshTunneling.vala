/*
 * SSHer - SSH Tunneling (Facade)
 * 
 * Main facade for SSH tunneling operations, delegates to specialized modules.
 * 
 * Copyright (C) 2025 Thiago Fernandes
 */

namespace KeyMaker {
    
    public class SSHTunneling : Object {
        
        public signal void tunnel_added (TunnelConfiguration config);
        public signal void tunnel_removed (TunnelConfiguration config);
        public signal void tunnel_started (ActiveTunnel tunnel);
        public signal void tunnel_stopped (ActiveTunnel tunnel);
        public signal void tunnel_status_changed (ActiveTunnel tunnel, TunnelStatus status);
        
        private TunnelingManager manager;
        
        public SSHTunneling () {
            manager = TunnelingManager.get_instance();
            
            // Forward signals from manager
            manager.tunnel_added.connect((config) => tunnel_added(config));
            manager.tunnel_removed.connect((config) => tunnel_removed(config));
            manager.tunnel_started.connect((tunnel) => tunnel_started(tunnel));
            manager.tunnel_stopped.connect((tunnel) => tunnel_stopped(tunnel));
            manager.tunnel_status_changed.connect((tunnel, status) => tunnel_status_changed(tunnel, status));
        }
        
        // Configuration management (delegates to TunnelingManager)
        public void add_configuration (TunnelConfiguration config) {
            manager.add_configuration(config);
        }
        
        public void remove_configuration (TunnelConfiguration config) {
            manager.remove_configuration(config);
        }
        
        public void update_configuration (TunnelConfiguration config) {
            manager.update_configuration(config);
        }
        
        public GenericArray<TunnelConfiguration> get_configurations () {
            return manager.get_configurations();
        }
        
        // Tunnel management (delegates to TunnelingManager)
        public async void start_tunnel (TunnelConfiguration config, bool auto_reconnect = true) throws KeyMakerError {
            yield manager.start_tunnel(config, auto_reconnect);
        }
        
        public async void stop_tunnel (TunnelConfiguration config) throws KeyMakerError {
            yield manager.stop_tunnel(config);
        }
        
        public async void stop_all_tunnels () {
            yield manager.stop_all_tunnels();
        }
        
        public async void start_auto_start_tunnels () {
            yield manager.start_auto_start_tunnels();
        }
        
        public bool is_tunnel_active (TunnelConfiguration config) {
            return manager.is_tunnel_active(config);
        }
        
        public GenericArray<ActiveTunnel> get_active_tunnels () {
            return manager.get_active_tunnels();
        }
        
        public ActiveTunnel? find_active_tunnel (TunnelConfiguration config) {
            return manager.find_active_tunnel(config);
        }
        
        public TunnelConfiguration? find_configuration (string config_id) {
            return manager.find_configuration(config_id);
        }
        
        public TunnelStatistics get_statistics () {
            return manager.get_statistics();
        }
        
        // Legacy compatibility methods (if needed by existing UI code)
        public TunnelConfiguration create_configuration () {
            return new TunnelConfiguration();
        }
        
        public bool validate_configuration (TunnelConfiguration config) {
            return config.validate();
        }
    }
}