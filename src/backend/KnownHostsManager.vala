/*
 * SSHer - Known Hosts Manager
 *
 * Manages the ~/.ssh/known_hosts file
 *
 * Copyright (C) 2025 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {

    public class KnownHostsManager : GLib.Object {
        private File known_hosts_file;
        private GenericArray<KnownHostEntry> entries;
        private GenericArray<string> comment_lines;  // Preserve comments

        // Trusted fingerprints database for common services
        private static HashTable<string, GenericArray<string>>? trusted_fingerprints = null;

        public signal void entries_changed ();

        construct {
            entries = new GenericArray<KnownHostEntry> ();
            comment_lines = new GenericArray<string> ();

            var ssh_dir = File.new_for_path (Path.build_filename (Environment.get_home_dir (), ".ssh"));
            known_hosts_file = ssh_dir.get_child ("known_hosts");

            init_trusted_fingerprints ();
        }

        /**
         * Initialize database of trusted fingerprints for common services
         */
        private static void init_trusted_fingerprints () {
            if (trusted_fingerprints != null) {
                return;
            }

            trusted_fingerprints = new HashTable<string, GenericArray<string>> (str_hash, str_equal);

            // GitHub
            var github_fps = new GenericArray<string> ();
            github_fps.add ("SHA256:nThbg6kXUpJWGl7E1IGOCspRomTxdCARLviKw6E5SY8");  // RSA
            github_fps.add ("SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s");  // ECDSA
            github_fps.add ("SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU");  // Ed25519
            trusted_fingerprints.set ("github.com", github_fps);

            // GitLab
            var gitlab_fps = new GenericArray<string> ();
            gitlab_fps.add ("SHA256:HbW3g8zUjNSksFbqTiUWPWg2Bq1x8xdGUrliXFzSnUw");  // ECDSA
            gitlab_fps.add ("SHA256:eUXGGm1YGsMAS7vkcx6JOJdOGHPem5gQp4taiCfCLB8");  // Ed25519
            gitlab_fps.add ("SHA256:ROQFvPThGrW4RuWLoL9tq9I9zJ42fK4XywyRtbOz/EQ");  // RSA
            trusted_fingerprints.set ("gitlab.com", gitlab_fps);
        }

        /**
         * Load known_hosts file
         */
        public async void load () throws KeyMakerError {
            entries.remove_range (0, entries.length);
            comment_lines.remove_range (0, comment_lines.length);

            if (!known_hosts_file.query_exists ()) {
                debug ("known_hosts file does not exist");
                return;
            }

            try {
                uint8[] contents;
                yield known_hosts_file.load_contents_async (null, out contents, null);
                var content = (string) contents;
                var lines = content.split ("\n");

                int line_num = 0;
                foreach (var line in lines) {
                    line_num++;
                    var trimmed = line.strip ();

                    // Skip empty lines
                    if (trimmed.length == 0) {
                        continue;
                    }

                    // Preserve comment lines
                    if (trimmed.has_prefix ("#")) {
                        comment_lines.add (line);
                        continue;
                    }

                    // Parse entry
                    var entry = parse_line (trimmed);
                    if (entry != null) {
                        entry.line_number = line_num;
                        entries.add (entry);
                    } else {
                        warning ("Failed to parse line %d: %s", line_num, trimmed);
                    }
                }

                debug ("Loaded %u entries from known_hosts", entries.length);

            } catch (Error e) {
                throw new KeyMakerError.FILE_READ_ERROR ("Failed to load known_hosts: %s", e.message);
            }
        }

        /**
         * Parse a single line from known_hosts file
         */
        private KnownHostEntry? parse_line (string line) {
            // Format: hostname[,hostname...] keytype key [comment]
            var parts = line.split (" ");

            if (parts.length < 3) {
                return null;
            }

            var hostnames = parts[0];
            var key_type = parts[1];
            var key_data = parts[2];
            string? comment = null;

            if (parts.length > 3) {
                comment = string.joinv (" ", parts[3:parts.length]);
            }

            return new KnownHostEntry (hostnames, key_type, key_data, comment);
        }

        /**
         * Save known_hosts file with automatic backup
         */
        public async void save () throws KeyMakerError {
            try {
                // Create backup first
                yield create_backup ();

                // Build content
                var content_builder = new StringBuilder ();

                // Add preserved comments
                foreach (var comment in comment_lines.data) {
                    content_builder.append (comment).append ("\n");
                }

                // Add entries
                foreach (var entry in entries.data) {
                    content_builder.append (entry.to_line ()).append ("\n");
                }

                var content = content_builder.str;

                // Write to file
                yield known_hosts_file.replace_contents_async (
                    content.data,
                    null,
                    false,
                    FileCreateFlags.PRIVATE,
                    null,
                    null
                );

                debug ("Saved %u entries to known_hosts", entries.length);
                entries_changed ();

            } catch (Error e) {
                throw new KeyMakerError.FILE_WRITE_ERROR ("Failed to save known_hosts: %s", e.message);
            }
        }

        /**
         * Create backup of known_hosts file
         */
        private async void create_backup () throws KeyMakerError {
            if (!known_hosts_file.query_exists ()) {
                return;
            }

            try {
                var timestamp = new DateTime.now_local ().format ("%Y%m%d_%H%M%S");
                var backup_name = "known_hosts.backup." + timestamp;
                var backup_file = known_hosts_file.get_parent ().get_child (backup_name);

                yield known_hosts_file.copy_async (
                    backup_file,
                    FileCopyFlags.OVERWRITE,
                    Priority.DEFAULT,
                    null,
                    null
                );

                debug ("Created backup: %s", backup_name);

                // Cleanup old backups (keep last 5)
                yield cleanup_old_backups ();

            } catch (Error e) {
                throw new KeyMakerError.FILE_WRITE_ERROR ("Failed to create backup: %s", e.message);
            }
        }

        /**
         * Cleanup old backup files, keeping only the last 5
         */
        private async void cleanup_old_backups () {
            try {
                var ssh_dir = known_hosts_file.get_parent ();
                var enumerator = yield ssh_dir.enumerate_children_async (
                    FileAttribute.STANDARD_NAME,
                    FileQueryInfoFlags.NONE,
                    Priority.DEFAULT,
                    null
                );

                var backups = new GenericArray<string> ();
                FileInfo? info = null;

                while ((info = enumerator.next_file (null)) != null) {
                    var name = info.get_name ();
                    if (name.has_prefix ("known_hosts.backup.")) {
                        backups.add (name);
                    }
                }

                // Sort backups by name (which includes timestamp)
                var backup_array = backups.data;
                GLib.qsort_with_data<string> (backup_array, backup_array.length, (a, b) => {
                    return strcmp (b, a);  // Reverse order (newest first)
                });

                // Delete old backups (keep first 5)
                for (int i = 5; i < backup_array.length; i++) {
                    var old_backup = ssh_dir.get_child (backup_array[i]);
                    yield old_backup.delete_async (Priority.DEFAULT, null);
                    debug ("Deleted old backup: %s", backup_array[i]);
                }

            } catch (Error e) {
                warning ("Failed to cleanup old backups: %s", e.message);
            }
        }

        /**
         * Get all entries
         */
        public GenericArray<KnownHostEntry> get_entries () {
            return entries;
        }

        /**
         * Remove a single entry
         */
        public async void remove_entry (KnownHostEntry entry) throws KeyMakerError {
            for (int i = 0; i < entries.length; i++) {
                if (entries[i] == entry) {
                    entries.remove_index (i);
                    yield save ();
                    return;
                }
            }

            throw new KeyMakerError.NOT_FOUND ("Entry not found");
        }

        /**
         * Remove multiple entries
         */
        public async void remove_entries (GenericArray<KnownHostEntry> to_remove) throws KeyMakerError {
            foreach (var entry in to_remove.data) {
                for (int i = 0; i < entries.length; i++) {
                    if (entries[i] == entry) {
                        entries.remove_index (i);
                        break;
                    }
                }
            }

            yield save ();
        }

        /**
         * Find duplicate entries
         */
        public GenericArray<GenericArray<KnownHostEntry>> find_duplicates () {
            var duplicate_groups = new GenericArray<GenericArray<KnownHostEntry>> ();

            for (int i = 0; i < entries.length; i++) {
                var entry_i = entries[i];

                // Skip if already in a group
                bool already_grouped = false;
                foreach (var group in duplicate_groups.data) {
                    for (int k = 0; k < group.length; k++) {
                        if (group[k] == entry_i) {
                            already_grouped = true;
                            break;
                        }
                    }
                    if (already_grouped) break;
                }
                if (already_grouped) continue;

                // Find all matching entries
                var group = new GenericArray<KnownHostEntry> ();
                group.add (entry_i);

                for (int j = i + 1; j < entries.length; j++) {
                    if (entry_i.matches (entries[j])) {
                        group.add (entries[j]);
                    }
                }

                if (group.length > 1) {
                    duplicate_groups.add (group);
                }
            }

            return duplicate_groups;
        }

        /**
         * Merge duplicate entries
         */
        public async void merge_duplicates (GenericArray<KnownHostEntry> to_merge) throws KeyMakerError {
            if (to_merge.length < 2) {
                return;
            }

            var merged = KnownHostEntry.merge (to_merge);
            if (merged == null) {
                throw new KeyMakerError.INVALID_INPUT ("Failed to merge entries");
            }

            // Remove original entries
            foreach (var entry in to_merge.data) {
                for (int i = 0; i < entries.length; i++) {
                    if (entries[i] == entry) {
                        entries.remove_index (i);
                        break;
                    }
                }
            }

            // Add merged entry
            entries.add (merged);

            yield save ();
        }

        /**
         * Check if a host is reachable (for stale detection)
         */
        public async bool check_host_reachable (string hostname, int timeout_seconds = 5) {
            try {
                var result = yield Command.run_capture_with_timeout (
                    { "ping", "-c", "1", "-W", timeout_seconds.to_string (), hostname },
                    timeout_seconds * 1000
                );

                return result.status == 0;

            } catch (Error e) {
                return false;
            }
        }

        /**
         * Detect stale entries (unreachable hosts)
         */
        public async void detect_stale_entries () {
            foreach (var entry in entries.data) {
                // Skip hashed entries (can't resolve hostname)
                if (entry.is_hashed) {
                    continue;
                }

                var hostnames = entry.get_hostname_list ();
                bool any_reachable = false;

                foreach (var hostname in hostnames) {
                    var clean_host = hostname.strip ();

                    // Skip wildcard patterns
                    if (clean_host.contains ("*") || clean_host.contains ("?")) {
                        any_reachable = true;  // Assume valid
                        break;
                    }

                    if (yield check_host_reachable (clean_host, 3)) {
                        any_reachable = true;
                        break;
                    }
                }

                if (!any_reachable) {
                    entry.status = HostEntryStatus.STALE;
                } else if (entry.status == HostEntryStatus.STALE) {
                    entry.status = HostEntryStatus.NORMAL;
                }
            }

            entries_changed ();
        }

        /**
         * Get stale entries
         */
        public GenericArray<KnownHostEntry> get_stale_entries () {
            var stale = new GenericArray<KnownHostEntry> ();

            foreach (var entry in entries.data) {
                if (entry.status == HostEntryStatus.STALE) {
                    stale.add (entry);
                }
            }

            return stale;
        }

        /**
         * Verify a fingerprint against trusted sources
         */
        public string? verify_fingerprint (string hostname, string fingerprint) {
            if (trusted_fingerprints == null) {
                return null;
            }

            var fps = trusted_fingerprints.get (hostname);
            if (fps == null) {
                return null;
            }

            foreach (var trusted_fp in fps.data) {
                if (trusted_fp == fingerprint) {
                    return "verified";
                }
            }

            return "mismatch";
        }

        /**
         * Import known_hosts file
         */
        public async ImportResult import_from_file (File import_file) throws KeyMakerError {
            var result = new ImportResult ();

            try {
                uint8[] contents;
                yield import_file.load_contents_async (null, out contents, null);
                var content = (string) contents;
                var lines = content.split ("\n");

                foreach (var line in lines) {
                    var trimmed = line.strip ();

                    if (trimmed.length == 0 || trimmed.has_prefix ("#")) {
                        continue;
                    }

                    var entry = parse_line (trimmed);
                    if (entry == null) {
                        result.skipped++;
                        continue;
                    }

                    // Check for duplicates
                    bool is_duplicate = false;
                    foreach (var existing in entries.data) {
                        if (existing.is_duplicate_of (entry)) {
                            is_duplicate = true;
                            result.duplicates++;
                            break;
                        }
                    }

                    if (!is_duplicate) {
                        entries.add (entry);
                        result.imported++;
                    }
                }

                if (result.imported > 0) {
                    yield save ();
                }

            } catch (Error e) {
                throw new KeyMakerError.FILE_READ_ERROR ("Failed to import: %s", e.message);
            }

            return result;
        }

        /**
         * Export known_hosts file
         */
        public async void export_to_file (File export_file) throws KeyMakerError {
            try {
                yield known_hosts_file.copy_async (
                    export_file,
                    FileCopyFlags.OVERWRITE,
                    Priority.DEFAULT,
                    null,
                    null
                );

            } catch (Error e) {
                throw new KeyMakerError.FILE_WRITE_ERROR ("Failed to export: %s", e.message);
            }
        }

        /**
         * Add a new entry
         */
        public async void add_entry (KnownHostEntry entry) throws KeyMakerError {
            entries.add (entry);
            yield save ();
        }
    }

    /**
     * Result of import operation
     */
    public class ImportResult : GLib.Object {
        public int imported { get; set; default = 0; }
        public int duplicates { get; set; default = 0; }
        public int skipped { get; set; default = 0; }

        public int get_total () {
            return imported + duplicates + skipped;
        }
    }
}
