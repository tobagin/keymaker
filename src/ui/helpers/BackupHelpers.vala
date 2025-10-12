/*
 * Key Maker - Backup Management Helper Utilities
 *
 * Shared utility functions for backup management UI components.
 * Provides consistent formatting, dialog creation, and error handling
 * across BackupPage and BackupCenterDialog.
 *
 * Copyright (C) 2025 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker.BackupHelpers {

    /**
     * Format file size in human-readable format
     */
    public string format_file_size (int64 size) {
        const double KB = 1024.0;
        const double MB = KB * 1024.0;
        const double GB = MB * 1024.0;

        if (size >= GB) {
            return "%.2f GB".printf (size / GB);
        } else if (size >= MB) {
            return "%.2f MB".printf (size / MB);
        } else if (size >= KB) {
            return "%.2f KB".printf (size / KB);
        } else {
            return "%lld B".printf (size);
        }
    }

    /**
     * Format DateTime in user-friendly format
     */
    public string format_datetime (DateTime? dt) {
        if (dt == null) {
            return "Unknown";
        }

        return dt.format ("%B %e, %Y at %l:%M %p");
    }

    /**
     * Format relative time (e.g., "2 days ago", "in 3 hours")
     */
    public string format_relative_time (DateTime dt) {
        var now = new DateTime.now_local ();
        var diff = now.difference (dt);

        if (diff < 0) {
            // Future time
            diff = -diff;
            if (diff < TimeSpan.MINUTE) {
                return "in moments";
            } else if (diff < TimeSpan.HOUR) {
                int64 minutes = diff / TimeSpan.MINUTE;
                return "in %lld %s".printf (minutes, minutes == 1 ? "minute" : "minutes");
            } else if (diff < TimeSpan.DAY) {
                int64 hours = diff / TimeSpan.HOUR;
                return "in %lld %s".printf (hours, hours == 1 ? "hour" : "hours");
            } else {
                int64 days = diff / TimeSpan.DAY;
                return "in %lld %s".printf (days, days == 1 ? "day" : "days");
            }
        } else {
            // Past time
            if (diff < TimeSpan.MINUTE) {
                return "just now";
            } else if (diff < TimeSpan.HOUR) {
                int64 minutes = diff / TimeSpan.MINUTE;
                return "%lld %s ago".printf (minutes, minutes == 1 ? "minute" : "minutes");
            } else if (diff < TimeSpan.DAY) {
                int64 hours = diff / TimeSpan.HOUR;
                return "%lld %s ago".printf (hours, hours == 1 ? "hour" : "hours");
            } else if (diff < TimeSpan.DAY * 7) {
                int64 days = diff / TimeSpan.DAY;
                return "%lld %s ago".printf (days, days == 1 ? "day" : "days");
            } else {
                return format_datetime (dt);
            }
        }
    }

    /**
     * Format time remaining for time-locked backups
     */
    public string format_time_remaining (TimeSpan remaining) {
        if (remaining <= 0) {
            return "UNLOCKED";
        }

        int64 days = remaining / TimeSpan.DAY;
        int64 hours = (remaining % TimeSpan.DAY) / TimeSpan.HOUR;
        int64 minutes = (remaining % TimeSpan.HOUR) / TimeSpan.MINUTE;
        int64 seconds = (remaining % TimeSpan.MINUTE) / TimeSpan.SECOND;

        if (days > 0) {
            return "%lld %s, %lld %s".printf (days, days == 1 ? "day" : "days",
                                               hours, hours == 1 ? "hour" : "hours");
        } else if (hours > 0) {
            return "%lld %s, %lld %s".printf (hours, hours == 1 ? "hour" : "hours",
                                               minutes, minutes == 1 ? "minute" : "minutes");
        } else if (minutes > 0) {
            return "%lld %s, %lld %s".printf (minutes, minutes == 1 ? "minute" : "minutes",
                                               seconds, seconds == 1 ? "second" : "seconds");
        } else {
            return "%lld %s".printf (seconds, seconds == 1 ? "second" : "seconds");
        }
    }

    /**
     * Format fingerprint with spacing for readability
     */
    public string format_fingerprint (string fingerprint) {
        if (fingerprint.length == 0) {
            return "Unknown";
        }

        // Add spaces every 2 or 4 characters depending on format
        var formatted = new StringBuilder ();
        for (int i = 0; i < fingerprint.length; i++) {
            if (i > 0 && i % 2 == 0 && fingerprint[i-1] != ':') {
                formatted.append_c (' ');
            }
            formatted.append_c (fingerprint[i]);
        }

        return formatted.str;
    }

    /**
     * Get human-readable backup type name
     */
    public string get_backup_type_name (RegularBackupType type) {
        switch (type) {
            case RegularBackupType.ENCRYPTED_ARCHIVE:
                return "Encrypted Archive";
            case RegularBackupType.EXPORT_BUNDLE:
                return "Export Bundle";
            case RegularBackupType.CLOUD_SYNC:
                return "Cloud Sync";
            default:
                return "Unknown";
        }
    }

    /**
     * Get human-readable emergency backup type name
     */
    public string get_emergency_backup_type_name (EmergencyBackupType type) {
        switch (type) {
            case EmergencyBackupType.ENCRYPTED_ARCHIVE:
                return "Encrypted Archive";
            case EmergencyBackupType.TIME_LOCKED:
                return "Time-Locked";
            case EmergencyBackupType.QR_CODE:
                return "QR Code";
            case EmergencyBackupType.SHAMIR_SECRET_SHARING:
                return "Shamir Secret Sharing";
            case EmergencyBackupType.TOTP_PROTECTED:
                return "TOTP Protected";
            case EmergencyBackupType.MULTI_FACTOR:
                return "Multi-Factor";
            default:
                return "Unknown";
        }
    }

    /**
     * Get icon name for backup type
     */
    public string get_backup_type_icon (RegularBackupType type) {
        switch (type) {
            case RegularBackupType.ENCRYPTED_ARCHIVE:
                return "folder-documents-symbolic";
            case RegularBackupType.EXPORT_BUNDLE:
                return "document-save-symbolic";
            case RegularBackupType.CLOUD_SYNC:
                return "folder-remote-symbolic";
            default:
                return "folder-symbolic";
        }
    }

    /**
     * Get icon name for emergency backup type
     */
    public string get_emergency_backup_type_icon (EmergencyBackupType type) {
        switch (type) {
            case EmergencyBackupType.ENCRYPTED_ARCHIVE:
                return "security-high-symbolic";
            case EmergencyBackupType.TIME_LOCKED:
                return "alarm-symbolic";
            case EmergencyBackupType.QR_CODE:
                return "qr-code-symbolic";
            case EmergencyBackupType.SHAMIR_SECRET_SHARING:
                return "view-grid-symbolic";
            case EmergencyBackupType.TOTP_PROTECTED:
                return "security-medium-symbolic";
            case EmergencyBackupType.MULTI_FACTOR:
                return "emblem-system-symbolic";
            default:
                return "folder-symbolic";
        }
    }

    /**
     * Create error dialog with consistent styling
     */
    public void show_error_dialog (Gtk.Window parent, string title, string message) {
        var dialog = new Adw.AlertDialog (title, message);
        dialog.add_response ("ok", "OK");
        dialog.set_default_response ("ok");
        dialog.present (parent);
    }

    /**
     * Show bulk delete result dialog
     */
    public void show_bulk_delete_result (Gtk.Window parent, BulkDeleteResult result, string operation_name) {
        if (result.all_succeeded ()) {
            var dialog = new Adw.AlertDialog (
                "Success",
                @"Successfully deleted all $(result.success_count) $(operation_name)."
            );
            dialog.add_response ("ok", "OK");
            dialog.set_default_response ("ok");
            dialog.present (parent);

        } else if (result.has_errors ()) {
            var error_list = new StringBuilder ();
            error_list.append (@"Deleted $(result.success_count) of $(result.total_count) $(operation_name).\n\n");
            error_list.append ("Failed to delete:\n");

            for (int i = 0; i < result.errors.length; i++) {
                error_list.append (@"• $(result.errors[i])\n");
            }

            var dialog = new Adw.AlertDialog (
                "Partial Failure",
                error_list.str
            );
            dialog.add_response ("ok", "OK");
            dialog.set_default_response ("ok");
            dialog.present (parent);
        }
    }

    /**
     * Calculate time remaining until DateTime
     */
    public TimeSpan calculate_time_remaining (DateTime unlock_time) {
        var now = new DateTime.now_local ();
        return unlock_time.difference (now);
    }
}
