/*
 * SSHer - Host Key Verification Dialog
 *
 * Copyright (C) 2025 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/host_key_verification_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/host_key_verification_dialog.ui")]
#endif
public class KeyMaker.HostKeyVerificationDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.ActionRow hostname_row;
    [GtkChild]
    private unowned Adw.ActionRow key_type_row;
    [GtkChild]
    private unowned Adw.ActionRow sha256_row;
    [GtkChild]
    private unowned Adw.ActionRow md5_row;
    [GtkChild]
    private unowned Adw.ActionRow status_row;
    [GtkChild]
    private unowned Adw.ActionRow docs_row;
    [GtkChild]
    private unowned Gtk.Image status_icon;
    [GtkChild]
    private unowned Gtk.Button copy_sha256_button;
    [GtkChild]
    private unowned Gtk.Button copy_md5_button;
    [GtkChild]
    private unowned Adw.EntryRow manual_verification_entry;
    [GtkChild]
    private unowned Gtk.Button verify_button;
    [GtkChild]
    private unowned Adw.PreferencesGroup docs_group;

    private KnownHostEntry entry;
    private KnownHostsManager manager;

    // Documentation URLs for known services
    private static HashTable<string, string>? docs_urls = null;

    public HostKeyVerificationDialog (Gtk.Window parent, KnownHostEntry entry) {
        Object ();
        this.entry = entry;
        this.manager = new KnownHostsManager ();

        init_docs_urls ();
        setup_ui ();
        setup_signals ();
        check_automatic_verification ();
    }

    private static void init_docs_urls () {
        if (docs_urls != null) {
            return;
        }

        docs_urls = new HashTable<string, string> (str_hash, str_equal);
        docs_urls.set ("github.com", "https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints");
        docs_urls.set ("gitlab.com", "https://docs.gitlab.com/ee/user/gitlab_com/");
    }

    private void setup_ui () {
        // Set hostname
        hostname_row.subtitle = entry.get_display_name ();

        // Set key type
        key_type_row.subtitle = entry.key_type;

        // Set fingerprints
        sha256_row.subtitle = entry.fingerprint_sha256;
        md5_row.subtitle = entry.fingerprint_md5;

        // Set initial status
        status_row.subtitle = _("Not verified");
        status_icon.icon_name = "dialog-question-symbolic";

        // Check if we have docs for this host
        var hostname = get_clean_hostname ();
        if (hostname != null && docs_urls.contains (hostname)) {
            docs_row.subtitle = docs_urls.get (hostname);
            docs_group.visible = true;
        } else {
            docs_group.visible = false;
        }
    }

    private void setup_signals () {
        copy_sha256_button.clicked.connect (() => {
            copy_to_clipboard (entry.fingerprint_sha256);
        });

        copy_md5_button.clicked.connect (() => {
            copy_to_clipboard (entry.fingerprint_md5);
        });

        verify_button.clicked.connect (on_verify_clicked);

        docs_row.activated.connect (() => {
            var hostname = get_clean_hostname ();
            if (hostname != null && docs_urls.contains (hostname)) {
                var url = docs_urls.get (hostname);
                try {
                    Gtk.show_uri (this.get_root () as Gtk.Window, url, Gdk.CURRENT_TIME);
                } catch (Error e) {
                    warning ("Failed to open URL: %s", e.message);
                }
            }
        });
    }

    private void check_automatic_verification () {
        var hostname = get_clean_hostname ();
        if (hostname == null) {
            return;
        }

        var result = manager.verify_fingerprint (hostname, entry.fingerprint_sha256);

        if (result == "verified") {
            status_row.subtitle = _("✓ Verified against trusted source");
            status_icon.icon_name = "emblem-ok-symbolic";
            status_icon.add_css_class ("success");
            entry.status = HostEntryStatus.VERIFIED;
        } else if (result == "mismatch") {
            status_row.subtitle = _("⚠ Does not match trusted fingerprint!");
            status_icon.icon_name = "dialog-warning-symbolic";
            status_icon.add_css_class ("warning");
        }
    }

    private string? get_clean_hostname () {
        if (entry.is_hashed) {
            return null;
        }

        var hostnames = entry.get_hostname_list ();
        if (hostnames.length == 0) {
            return null;
        }

        // Get first hostname and clean it
        var hostname = hostnames[0].strip ();

        // Remove port if present
        if (hostname.contains (":")) {
            var parts = hostname.split (":");
            hostname = parts[0];
        }

        // Remove brackets if present (IPv6)
        hostname = hostname.replace ("[", "").replace ("]", "");

        return hostname;
    }

    private void copy_to_clipboard (string text) {
        var display = Gdk.Display.get_default ();
        if (display == null) {
            return;
        }

        var clipboard = display.get_clipboard ();
        clipboard.set_text (text);

        // We can't show a toast from here, but the button feedback is enough
    }

    private void on_verify_clicked () {
        var input = manual_verification_entry.text.strip ();

        if (input.length == 0) {
            status_row.subtitle = _("Please enter a fingerprint to verify");
            status_icon.icon_name = "dialog-information-symbolic";
            return;
        }

        // Normalize input (remove spaces, colons)
        var normalized_input = input.replace (" ", "").replace (":", "").up ();
        var normalized_sha256 = entry.fingerprint_sha256.replace ("SHA256:", "").replace (" ", "").up ();
        var normalized_md5 = entry.fingerprint_md5.replace (":", "").up ();

        if (normalized_input == normalized_sha256 || input == entry.fingerprint_sha256) {
            status_row.subtitle = _("✓ SHA256 fingerprint matches!");
            status_icon.icon_name = "emblem-ok-symbolic";
            status_icon.add_css_class ("success");
        } else if (normalized_input == normalized_md5 || input == entry.fingerprint_md5) {
            status_row.subtitle = _("✓ MD5 fingerprint matches!");
            status_icon.icon_name = "emblem-ok-symbolic";
            status_icon.add_css_class ("success");
        } else {
            status_row.subtitle = _("✗ Fingerprint does not match!");
            status_icon.icon_name = "dialog-error-symbolic";
            status_icon.add_css_class ("error");
        }
    }
}
