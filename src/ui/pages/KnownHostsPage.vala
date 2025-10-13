/*
 * Key Maker - Known Hosts Page
 *
 * Copyright (C) 2025 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/known_hosts_page.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/known_hosts_page.ui")]
#endif
public class KeyMaker.KnownHostsPage : Adw.Bin {
    [GtkChild]
    private unowned Gtk.SearchEntry search_entry;
    [GtkChild]
    private unowned Gtk.Button refresh_button;
    [GtkChild]
    private unowned Gtk.Button import_button;
    [GtkChild]
    private unowned Gtk.Button export_button;
    [GtkChild]
    private unowned Gtk.Button remove_stale_button;
    [GtkChild]
    private unowned Gtk.ListBox known_hosts_list;

    private KnownHostsManager manager;
    private GenericArray<KnownHostEntry> entries;
    private GenericArray<KnownHostEntry> filtered_entries;
    private string current_filter = "";

    // Signals for window integration
    public signal void show_toast_requested (string message);

    construct {
        manager = new KnownHostsManager ();
        entries = new GenericArray<KnownHostEntry> ();
        filtered_entries = new GenericArray<KnownHostEntry> ();

        // Setup button signals
        if (refresh_button != null) {
            refresh_button.clicked.connect (on_refresh_clicked);
        }
        if (import_button != null) {
            import_button.clicked.connect (on_import_clicked);
        }
        if (export_button != null) {
            export_button.clicked.connect (on_export_clicked);
        }
        if (remove_stale_button != null) {
            remove_stale_button.clicked.connect (on_remove_stale_clicked);
        }

        // Setup search
        if (search_entry != null) {
            search_entry.search_changed.connect (on_search_changed);
        }

        // Listen to manager changes
        manager.entries_changed.connect (refresh_display);

        // Load entries
        load_entries ();
    }

    private void load_entries () {
        load_entries_async.begin ();
    }

    private async void load_entries_async () {
        try {
            yield manager.load ();
            var loaded = manager.get_entries ();

            entries.remove_range (0, entries.length);
            for (int i = 0; i < loaded.length; i++) {
                entries.add (loaded[i]);
            }

            refresh_display ();

            // Start stale detection in background
            detect_stale_entries_async.begin ();

        } catch (Error e) {
            warning ("Failed to load known hosts: %s", e.message);
            show_toast_requested (_("Failed to load known hosts: %s").printf (e.message));
        }
    }

    private async void detect_stale_entries_async () {
        try {
            yield manager.detect_stale_entries ();
            refresh_display ();
        } catch (Error e) {
            warning ("Failed to detect stale entries: %s", e.message);
        }
    }

    private void refresh_display () {
        // Apply search filter
        filtered_entries.remove_range (0, filtered_entries.length);

        foreach (var entry in entries.data) {
            if (matches_filter (entry)) {
                filtered_entries.add (entry);
            }
        }

        // Clear current display
        var child = known_hosts_list.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            known_hosts_list.remove (child);
            child = next;
        }

        // Show empty state if no entries
        if (filtered_entries.length == 0) {
            var empty_row = new Adw.ActionRow ();
            if (entries.length == 0) {
                empty_row.title = _("No Known Hosts");
                empty_row.subtitle = _("Known hosts will be added automatically when you connect to SSH servers");
            } else {
                empty_row.title = _("No Matching Hosts");
                empty_row.subtitle = _("Try a different search term");
            }
            empty_row.sensitive = false;

            var icon = new Gtk.Image ();
            icon.icon_name = "security-high-symbolic";
            icon.opacity = 0.5;
            empty_row.add_prefix (icon);

            known_hosts_list.append (empty_row);
            return;
        }

        // Add entries to display
        for (int i = 0; i < filtered_entries.length; i++) {
            var row = create_entry_row (filtered_entries[i]);
            known_hosts_list.append (row);
        }
    }

    private bool matches_filter (KnownHostEntry entry) {
        if (current_filter.length == 0) {
            return true;
        }

        var filter_lower = current_filter.down ();

        // Search in hostname
        if (entry.get_display_name ().down ().contains (filter_lower)) {
            return true;
        }

        // Search in key type
        if (entry.key_type.down ().contains (filter_lower)) {
            return true;
        }

        // Search in fingerprint
        if (entry.fingerprint_sha256.down ().contains (filter_lower)) {
            return true;
        }

        return false;
    }

    private Gtk.Widget create_entry_row (KnownHostEntry entry) {
        var row = new Adw.ActionRow ();
        row.title = entry.get_display_name ();

        // Build subtitle with key type and status
        var subtitle_parts = new GenericArray<string> ();
        subtitle_parts.add (entry.key_type);
        subtitle_parts.add (entry.fingerprint_sha256);

        if (entry.status == HostEntryStatus.STALE) {
            subtitle_parts.add (_("unreachable"));
        } else if (entry.status == HostEntryStatus.VERIFIED) {
            subtitle_parts.add (_("verified"));
        }

        row.subtitle = string.joinv (" • ", subtitle_parts.data);
        row.activatable = false;

        // Add status icon
        var icon = new Gtk.Image ();
        if (entry.status == HostEntryStatus.STALE) {
            icon.icon_name = "dialog-warning-symbolic";
            icon.add_css_class ("warning");
        } else if (entry.status == HostEntryStatus.VERIFIED) {
            icon.icon_name = "emblem-ok-symbolic";
            icon.add_css_class ("success");
        } else if (entry.is_hashed) {
            icon.icon_name = "view-conceal-symbolic";
        } else {
            icon.icon_name = "security-high-symbolic";
        }
        row.add_prefix (icon);

        // Create button box
        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        button_box.valign = Gtk.Align.CENTER;

        // Add verify button
        var verify_button = new Gtk.Button ();
        verify_button.icon_name = "security-medium-symbolic";
        verify_button.tooltip_text = _("Verify Fingerprint");
        verify_button.add_css_class ("flat");
        verify_button.valign = Gtk.Align.CENTER;
        verify_button.clicked.connect (() => {
            on_verify_clicked (entry);
        });
        button_box.append (verify_button);

        // Add delete button
        var delete_button = new Gtk.Button ();
        delete_button.icon_name = "io.github.tobagin.keysmith-remove-symbolic";
        delete_button.tooltip_text = _("Remove Entry");
        delete_button.add_css_class ("flat");
        delete_button.add_css_class ("destructive-action");
        delete_button.valign = Gtk.Align.CENTER;
        delete_button.clicked.connect (() => {
            on_remove_entry_clicked (entry);
        });
        button_box.append (delete_button);

        row.add_suffix (button_box);
        row.set_data ("entry", entry);

        return row;
    }

    private void on_search_changed () {
        current_filter = search_entry.text.strip ();
        refresh_display ();
    }

    private void on_refresh_clicked () {
        load_entries ();
    }

    private void on_verify_clicked (KnownHostEntry entry) {
        var dialog = new KeyMaker.HostKeyVerificationDialog (
            get_root () as Gtk.Window,
            entry
        );
        dialog.present (get_root () as Gtk.Window);
    }

    private void on_remove_entry_clicked (KnownHostEntry entry) {
        var dialog = new Adw.AlertDialog (
            _("Remove Known Host Entry?"),
            _("This will remove the host key for '%s' from your known hosts file.").printf (entry.get_display_name ())
        );
        dialog.add_response ("cancel", _("Cancel"));
        dialog.add_response ("remove", _("Remove"));
        dialog.set_response_appearance ("remove", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response ("cancel");

        dialog.response.connect ((response) => {
            if (response == "remove") {
                remove_entry_async.begin (entry);
            }
        });

        dialog.present (get_root () as Gtk.Window);
    }

    private async void remove_entry_async (KnownHostEntry entry) {
        try {
            yield manager.remove_entry (entry);

            // Remove from local list
            for (int i = 0; i < entries.length; i++) {
                if (entries[i] == entry) {
                    entries.remove_index (i);
                    break;
                }
            }

            refresh_display ();
            show_toast_requested (_("Host entry removed successfully"));

        } catch (Error e) {
            warning ("Failed to remove entry: %s", e.message);
            show_toast_requested (_("Failed to remove entry: %s").printf (e.message));
        }
    }

    private void on_remove_stale_clicked () {
        var stale = manager.get_stale_entries ();

        if (stale.length == 0) {
            show_toast_requested (_("No stale entries found"));
            return;
        }

        var dialog = new Adw.AlertDialog (
            _("Remove Stale Entries?"),
            ngettext (
                "This will remove %d unreachable host entry from your known hosts file.",
                "This will remove %d unreachable host entries from your known hosts file.",
                stale.length
            ).printf (stale.length)
        );
        dialog.add_response ("cancel", _("Cancel"));
        dialog.add_response ("remove", _("Remove All"));
        dialog.set_response_appearance ("remove", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response ("cancel");

        dialog.response.connect ((response) => {
            if (response == "remove") {
                remove_stale_entries_async.begin (stale);
            }
        });

        dialog.present (get_root () as Gtk.Window);
    }

    private async void remove_stale_entries_async (GenericArray<KnownHostEntry> stale) {
        try {
            yield manager.remove_entries (stale);

            // Remove from local list
            foreach (var entry in stale.data) {
                for (int i = 0; i < entries.length; i++) {
                    if (entries[i] == entry) {
                        entries.remove_index (i);
                        break;
                    }
                }
            }

            refresh_display ();
            show_toast_requested (
                ngettext (
                    "%d stale entry removed",
                    "%d stale entries removed",
                    stale.length
                ).printf (stale.length)
            );

        } catch (Error e) {
            warning ("Failed to remove stale entries: %s", e.message);
            show_toast_requested (_("Failed to remove stale entries: %s").printf (e.message));
        }
    }

    private void on_import_clicked () {
        var file_chooser = new Gtk.FileDialog ();
        file_chooser.title = _("Import Known Hosts");

        var filter = new Gtk.FileFilter ();
        filter.set_filter_name (_("Known Hosts Files"));
        filter.add_pattern ("known_hosts*");
        filter.add_pattern ("*.txt");

        var filters = new ListStore (typeof (Gtk.FileFilter));
        filters.append (filter);
        file_chooser.filters = filters;

        file_chooser.open.begin (get_root () as Gtk.Window, null, (obj, res) => {
            try {
                var file = file_chooser.open.end (res);
                import_file_async.begin (file);
            } catch (Error e) {
                // User cancelled
            }
        });
    }

    private async void import_file_async (File file) {
        try {
            var result = yield manager.import_from_file (file);

            // Reload entries
            var loaded = manager.get_entries ();
            entries.remove_range (0, entries.length);
            for (int i = 0; i < loaded.length; i++) {
                entries.add (loaded[i]);
            }

            refresh_display ();

            // Show summary dialog
            var message = _("Import completed:\n• %d entries imported\n• %d duplicates skipped\n• %d invalid entries skipped")
                .printf (result.imported, result.duplicates, result.skipped);

            var dialog = new Adw.AlertDialog (_("Import Complete"), message);
            dialog.add_response ("ok", _("OK"));
            dialog.set_default_response ("ok");
            dialog.present (get_root () as Gtk.Window);

        } catch (Error e) {
            warning ("Failed to import: %s", e.message);
            show_toast_requested (_("Failed to import: %s").printf (e.message));
        }
    }

    private void on_export_clicked () {
        var file_chooser = new Gtk.FileDialog ();
        file_chooser.title = _("Export Known Hosts");
        file_chooser.initial_name = "known_hosts";

        file_chooser.save.begin (get_root () as Gtk.Window, null, (obj, res) => {
            try {
                var file = file_chooser.save.end (res);
                export_file_async.begin (file);
            } catch (Error e) {
                // User cancelled
            }
        });
    }

    private async void export_file_async (File file) {
        try {
            yield manager.export_to_file (file);
            show_toast_requested (_("Known hosts exported successfully"));

        } catch (Error e) {
            warning ("Failed to export: %s", e.message);
            show_toast_requested (_("Failed to export: %s").printf (e.message));
        }
    }

    public void refresh () {
        load_entries ();
    }
}
