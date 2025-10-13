/*
 * SSHer - Known Host Entry Model
 *
 * Represents an entry in the ~/.ssh/known_hosts file
 *
 * Copyright (C) 2025 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {

    public enum HostEntryStatus {
        NORMAL,
        VERIFIED,
        STALE,
        CONFLICT
    }

    public class KnownHostEntry : GLib.Object {
        public string hostnames { get; set; }  // Comma-separated list or hashed
        public string key_type { get; set; }   // ssh-rsa, ecdsa-sha2-nistp256, ssh-ed25519, etc.
        public string key_data { get; set; }   // Base64 encoded public key
        public string? comment { get; set; }   // Optional comment
        public bool is_hashed { get; set; }
        public int line_number { get; set; }
        public HostEntryStatus status { get; set; default = HostEntryStatus.NORMAL; }

        // Calculated properties
        public string fingerprint_sha256 { get; private set; }
        public string fingerprint_md5 { get; private set; }

        public KnownHostEntry (string hostnames, string key_type, string key_data, string? comment = null) {
            this.hostnames = hostnames;
            this.key_type = key_type;
            this.key_data = key_data;
            this.comment = comment;
            this.is_hashed = hostnames.has_prefix ("|1|");
            this.line_number = -1;

            calculate_fingerprints ();
        }

        /**
         * Calculate SHA256 and MD5 fingerprints from the key data
         */
        private void calculate_fingerprints () {
            try {
                // Decode base64 key data
                var key_bytes = Base64.decode (key_data);

                // Calculate SHA256 fingerprint
                var sha256 = new Checksum (ChecksumType.SHA256);
                sha256.update (key_bytes, key_bytes.length);
                uint8[] sha256_digest = new uint8[32];
                size_t digest_len = 32;
                sha256.get_digest (sha256_digest, ref digest_len);

                // Format as SHA256:base64
                fingerprint_sha256 = "SHA256:" + Base64.encode (sha256_digest).replace ("=", "");

                // Calculate MD5 fingerprint
                var md5 = new Checksum (ChecksumType.MD5);
                md5.update (key_bytes, key_bytes.length);
                uint8[] md5_digest = new uint8[16];
                digest_len = 16;
                md5.get_digest (md5_digest, ref digest_len);

                // Format as xx:xx:xx:...
                var md5_parts = new GenericArray<string> ();
                for (int i = 0; i < md5_digest.length; i++) {
                    md5_parts.add ("%02x".printf (md5_digest[i]));
                }
                fingerprint_md5 = string.joinv (":", md5_parts.data);

            } catch (Error e) {
                warning ("Failed to calculate fingerprints: %s", e.message);
                fingerprint_sha256 = "Unknown";
                fingerprint_md5 = "Unknown";
            }
        }

        /**
         * Get display name for the host entry
         */
        public string get_display_name () {
            if (is_hashed) {
                // Show shortened hash representation
                var parts = hostnames.split ("|");
                if (parts.length >= 3) {
                    var hash_preview = parts[2].substring (0, int.min (8, parts[2].length));
                    return "hashed:" + hash_preview + "...";
                }
                return "hashed:unknown";
            }

            // Return first hostname if multiple
            var hosts = hostnames.split (",");
            return hosts[0];
        }

        /**
         * Get all hostnames as an array
         */
        public string[] get_hostname_list () {
            if (is_hashed) {
                return { hostnames };
            }
            return hostnames.split (",");
        }

        /**
         * Check if this entry matches another (for duplicate detection)
         */
        public bool matches (KnownHostEntry other) {
            // Same hostname pattern and key type
            if (this.hostnames == other.hostnames && this.key_type == other.key_type) {
                return true;
            }

            // Check if any hostname overlaps (for non-hashed entries)
            if (!is_hashed && !other.is_hashed) {
                var my_hosts = get_hostname_list ();
                var other_hosts = other.get_hostname_list ();

                foreach (var my_host in my_hosts) {
                    foreach (var other_host in other_hosts) {
                        if (my_host.strip () == other_host.strip ()) {
                            return true;
                        }
                    }
                }
            }

            return false;
        }

        /**
         * Check if this entry is a duplicate with same key
         */
        public bool is_duplicate_of (KnownHostEntry other) {
            return matches (other) && this.key_data == other.key_data;
        }

        /**
         * Get the original line format for known_hosts file
         */
        public string to_line () {
            var parts = new GenericArray<string> ();
            parts.add (hostnames);
            parts.add (key_type);
            parts.add (key_data);

            if (comment != null && comment.length > 0) {
                parts.add (comment);
            }

            return string.joinv (" ", parts.data);
        }

        /**
         * Create a merged entry from multiple entries
         */
        public static KnownHostEntry merge (GenericArray<KnownHostEntry> entries) {
            if (entries.length == 0) {
                warning ("Cannot merge zero entries");
                return null;
            }

            var first = entries[0];
            var all_hostnames = new GenericArray<string> ();

            // Collect all unique hostnames
            foreach (var entry in entries.data) {
                if (entry.is_hashed) {
                    all_hostnames.add (entry.hostnames);
                } else {
                    foreach (var host in entry.get_hostname_list ()) {
                        var host_trimmed = host.strip ();
                        bool found = false;
                        for (int i = 0; i < all_hostnames.length; i++) {
                            if (all_hostnames[i] == host_trimmed) {
                                found = true;
                                break;
                            }
                        }
                        if (!found) {
                            all_hostnames.add (host_trimmed);
                        }
                    }
                }
            }

            // Create merged entry
            var merged_hostnames = string.joinv (",", all_hostnames.data);
            var merged = new KnownHostEntry (
                merged_hostnames,
                first.key_type,
                first.key_data,
                first.comment
            );

            return merged;
        }
    }
}
