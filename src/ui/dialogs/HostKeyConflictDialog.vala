/*
 * Key Maker - Host Key Conflict Dialog
 *
 * Copyright (C) 2025 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/host_key_conflict_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/host_key_conflict_dialog.ui")]
#endif
public class KeyMaker.HostKeyConflictDialog : Adw.AlertDialog {
    [GtkChild]
    private unowned Adw.ActionRow hostname_row;
    [GtkChild]
    private unowned Adw.ActionRow old_fingerprint_row;
    [GtkChild]
    private unowned Adw.ActionRow new_fingerprint_row;
    [GtkChild]
    private unowned Gtk.Label warning_label;

    private KnownHostEntry old_entry;
    private string new_fingerprint;
    private string hostname;

    public signal void key_updated (KnownHostEntry new_entry);
    public signal void connection_cancelled ();

    public HostKeyConflictDialog (
        Gtk.Window parent,
        string hostname,
        KnownHostEntry old_entry,
        string new_fingerprint
    ) {
        Object ();

        this.hostname = hostname;
        this.old_entry = old_entry;
        this.new_fingerprint = new_fingerprint;

        // Add responses
        add_response ("cancel", _("Cancel Connection"));
        add_response ("update", _("Update Key"));
        set_response_appearance ("cancel", Adw.ResponseAppearance.DESTRUCTIVE);
        set_response_appearance ("update", Adw.ResponseAppearance.SUGGESTED);

        setup_ui ();
        setup_signals ();
    }

    private void setup_ui () {
        // Set hostname
        hostname_row.subtitle = hostname;

        // Set old fingerprint
        old_fingerprint_row.subtitle = old_entry.fingerprint_sha256;

        // Set new fingerprint
        new_fingerprint_row.subtitle = new_fingerprint;
    }

    private void setup_signals () {
        this.response.connect ((response_id) => {
            if (response_id == "update") {
                handle_update_key ();
            } else {
                connection_cancelled ();
            }
        });
    }

    private void handle_update_key () {
        // Log the key change for audit purposes
        var timestamp = new DateTime.now_local ().format ("%Y-%m-%d %H:%M:%S");
        message ("Host key updated for %s at %s - Old: %s, New: %s",
            hostname,
            timestamp,
            old_entry.fingerprint_sha256,
            new_fingerprint
        );

        // Create a new entry with the updated key
        // Note: In a real implementation, this would need the full key data,
        // not just the fingerprint. This is a placeholder for the conflict
        // resolution workflow.

        // For now, just emit the signal. The actual implementation would
        // need to be integrated with the SSH connection flow to get the
        // full key data.
        warning ("HostKeyConflictDialog: Update key functionality needs full SSH integration");

        // Placeholder: Create updated entry (would need actual key data from SSH)
        // var new_entry = new KnownHostEntry (
        //     old_entry.hostnames,
        //     old_entry.key_type,
        //     new_key_data,  // Would come from SSH
        //     old_entry.comment
        // );
        // key_updated (new_entry);
    }

    /**
     * Static helper to show conflict dialog and handle response
     */
    public static async bool show_conflict (
        Gtk.Window parent,
        string hostname,
        KnownHostEntry old_entry,
        string new_fingerprint
    ) {
        var dialog = new HostKeyConflictDialog (parent, hostname, old_entry, new_fingerprint);

        var promise = new GLib.MainLoop ();
        bool should_update = false;

        dialog.response.connect ((response_id) => {
            should_update = (response_id == "update");
            promise.quit ();
        });

        dialog.present (parent);
        promise.run ();

        return should_update;
    }
}
