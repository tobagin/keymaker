/*
 * Copyright (C) 2025 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

public class KeyMaker.AboutDialog : GLib.Object {
    
    public static void show(Gtk.Window? parent) {
        debug("About action activated");
        
        string[] developers = { "Thiago Fernandes https://github.com/tobagin" };
        string[] designers = { "Thiago Fernandes https://github.com/tobagin" };
        string[] artists = { "Thiago Fernandes https://github.com/tobagin", "Rosabel https://github.com/oiimrosabel" };
        
        string app_name = "Keymaker";
        string comments = "A user-friendly graphical application for managing SSH keys. It provides an intuitive interface for generating, managing, and deploying SSH keys without needing to use command-line tools.";
        
        if (Config.APP_ID.contains("Devel")) {
            // app_name = "Keymaker"; // Already set default
            comments = "A user-friendly graphical application for managing SSH keys. It provides an intuitive interface for generating, managing, and deploying SSH keys without needing to use command-line tools. (Development Version)";
        }

        var about = new Adw.AboutDialog() {
            application_icon = Config.APP_ID,
            application_name = app_name,
            artists = artists,
            comments = comments,
            copyright = "© 2025 Keymaker Team",
            debug_info = "Build Profile: " + (Config.APP_ID.contains("Devel") ? "Development" : "Release") + "\nVersion: " + Config.VERSION,
            designers = designers,
            developer_name = "Keymaker Team",
            developers = developers,
            documenters = developers,
            issue_url = "https://github.com/tobagin/keymaker/issues",
            license_type = Gtk.License.GPL_3_0,
            support_url = "https://github.com/tobagin/keymaker/discussions",
            translator_credits = _("translator-credits"),
            version = Config.VERSION,
            website = "https://tobagin.github.io/apps/keymaker"
        };

        // Load and set release notes from metainfo
        load_release_notes(about);

        // Add acknowledgement section
        about.add_acknowledgement_section(
            "Special Thanks",
            {
                "The GNOME Project",
                "The OpenSSH Project",
                "LibAdwaita Contributors",
                "Vala Programming Language Team",
                "GTK Development Team"
            }
        );
        
        // Add Source link
        about.add_link("Source", "https://github.com/tobagin/keymaker");

        if (parent != null && !parent.in_destruction()) {
            about.present(parent);
        }
    }
    
    
    private static void load_release_notes(Adw.AboutDialog about) {
        // Load and set release notes from appdata
        try {
            var appdata_path = Path.build_filename(Config.DATADIR, "metainfo", "%s.metainfo.xml".printf(Config.APP_ID));
            // Fallback for flatpak dev environment where prefix might be /app
            if (!FileUtils.test(appdata_path, FileTest.EXISTS)) {
               appdata_path = Path.build_filename("/app/share/metainfo", "%s.metainfo.xml".printf(Config.APP_ID));
            }

            var file = File.new_for_path(appdata_path);
            
            if (file.query_exists()) {
                uint8[] contents;
                file.load_contents(null, out contents, null);
                string xml_content = (string) contents;
                
                // Parse the XML to find the release matching Config.VERSION
                var parser = new Regex("<release version=\"%s\"[^>]*>(.*?)</release>".printf(Regex.escape_string(Config.VERSION)), 
                                       RegexCompileFlags.DOTALL | RegexCompileFlags.MULTILINE);
                MatchInfo match_info;
                
                if (parser.match(xml_content, 0, out match_info)) {
                    string release_section = match_info.fetch(1);
                    
                    // Extract description content
                    var desc_parser = new Regex("<description>(.*?)</description>", 
                                                RegexCompileFlags.DOTALL | RegexCompileFlags.MULTILINE);
                    MatchInfo desc_match;
                    
                    if (desc_parser.match(release_section, 0, out desc_match)) {
                        string release_notes = desc_match.fetch(1).strip();
                        
                        // Strip <a> tags as Adw.AboutDialog's parser doesn't support them
                        // We keep the text content inside the tag
                        try {
                            var link_regex = new Regex("<a[^>]*>(.*?)</a>", RegexCompileFlags.DOTALL | RegexCompileFlags.MULTILINE);
                            release_notes = link_regex.replace(release_notes, -1, 0, "\\1");
                        } catch (Error e) {
                            warning("Failed to strip link tags: %s", e.message);
                        }

                        about.set_release_notes(release_notes);
                        about.set_release_notes_version(Config.VERSION);
                    }
                }
            }
        } catch (Error e) {
            // If we can't load release notes from appdata, that's okay
            warning("Could not load release notes from appdata: %s", e.message);
        }
    }
}