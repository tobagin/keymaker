/*
 * Key Maker - Diagnostic HTML Report Dialog
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/keysmith/Devel/diagnostic_html_report_dialog.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/keysmith/diagnostic_html_report_dialog.ui")]
#endif
public class KeyMaker.DiagnosticHtmlReportDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.WindowTitle report_title;
    [GtkChild]
    private unowned Gtk.ScrolledWindow webview_container;
    [GtkChild]
    private unowned Gtk.Button save_report_button;
    [GtkChild]
    private unowned Gtk.Button print_report_button;
    
#if HAS_WEBKIT
    private WebKit.WebView? webview;
#endif
    private string html_content;
    private string target_name;
    
    public DiagnosticHtmlReportDialog(string html_content, string target_name) {
        Object();
        this.html_content = html_content;
        this.target_name = target_name;
        
        // Setup WebView immediately since we have proper containment now
        setup_webview();
    }
    
    construct {
        // Setup button signals
        save_report_button.clicked.connect(on_save_report_clicked);
        print_report_button.clicked.connect(on_print_report_clicked);
    }
    
    private void setup_webview() {
#if HAS_WEBKIT
        try {
            // Create WebView
            webview = new WebKit.WebView();
            
            // Configure WebView settings for better display
            var settings = webview.get_settings();
            settings.enable_javascript = false; // We don't need JS for static HTML
            settings.default_font_family = "system-ui, -apple-system, sans-serif";
            
            // Prevent WebView from interfering with parent widget events
            webview.can_focus = false;
            webview.focusable = false;
            
            // Configure WebView sizing
            webview.hexpand = true;
            webview.vexpand = true;
            webview.halign = Gtk.Align.FILL;
            webview.valign = Gtk.Align.FILL;
            
            // Set window title
            report_title.title = _("Diagnostic Report - %s").printf(target_name);
            
            // Add WebView directly to the ScrolledWindow (defined in Blueprint)
            webview_container.child = webview;
            
            // Load HTML content
            webview.load_html(html_content, null);
            
            // Show WebView controls
            save_report_button.visible = true;
            print_report_button.visible = true;
            
        } catch (Error e) {
            warning("Failed to create WebView: %s", e.message);
            show_fallback_error();
        }
#else
        show_fallback_error();
#endif
    }
    
    private void show_fallback_error() {
        // Remove any existing WebView
        webview_container.child = null;
        
#if HAS_WEBKIT
        webview = null;
#endif
        
        // Show error message
        var error_page = new Adw.StatusPage();
        error_page.icon_name = "computer-fail-symbolic";
        error_page.title = _("WebView Unavailable");
        error_page.description = _("Could not display the HTML report. WebKitGTK may not be installed on your system.");
        
        var fallback_button = new Gtk.Button.with_label(_("Save Report to File"));
        fallback_button.add_css_class("pill");
        fallback_button.add_css_class("suggested-action");
        fallback_button.clicked.connect(on_save_report_clicked);
        
        error_page.child = fallback_button;
        webview_container.child = error_page;
        
        // Hide WebView controls
        save_report_button.visible = false;
        print_report_button.visible = false;
        
        report_title.title = _("Diagnostic Report - %s (Error)").printf(target_name);
    }
    
    private void on_save_report_clicked() {
        print("DEBUG: Save report button clicked!\n");
        var file_dialog = new Gtk.FileDialog();
        file_dialog.title = _("Save Diagnostic Report");
        
        // Set default filename
        var timestamp = new DateTime.now_local().format("%Y%m%d_%H%M%S");
        var hostname = target_name.replace(".", "_").replace(":", "_").replace("@", "_");
        var default_filename = @"diagnostic_$(hostname)_$(timestamp).html";
        file_dialog.initial_name = default_filename;
        
        // Add file filters
        var html_filter = new Gtk.FileFilter();
        html_filter.name = _("HTML Files");
        html_filter.add_mime_type("text/html");
        html_filter.add_pattern("*.html");
        
        var all_filter = new Gtk.FileFilter();
        all_filter.name = _("All Files");
        all_filter.add_pattern("*");
        
        var filter_list = new ListStore(typeof(Gtk.FileFilter));
        filter_list.append(html_filter);
        filter_list.append(all_filter);
        file_dialog.filters = filter_list;
        
        file_dialog.save.begin(get_root() as Gtk.Window, null, (obj, res) => {
            try {
                var file = file_dialog.save.end(res);
                if (file != null) {
                    save_html_to_file.begin(file);
                }
            } catch (Error e) {
                // User cancelled or error occurred
            }
        });
    }
    
    private async void save_html_to_file(File file) {
        try {
            yield file.replace_contents_async(
                html_content.data,
                null,
                false,
                FileCreateFlags.REPLACE_DESTINATION,
                null,
                null
            );
            
            // Show success toast (we need to signal this to parent)
            show_save_success_toast(file.get_path());
        } catch (Error e) {
            warning("Failed to save HTML report: %s", e.message);
            show_save_error_toast(e.message);
        }
    }
    
    private void on_print_report_clicked() {
        print("DEBUG: Print report button clicked!\n");
#if HAS_WEBKIT
        if (webview == null) {
            show_print_error_toast(_("WebView not available for printing"));
            return;
        }
        
        try {
            var print_operation = new WebKit.PrintOperation(webview);
            var response = print_operation.run_dialog(get_root() as Gtk.Window);
            
            if (response == WebKit.PrintOperationResponse.PRINT) {
                show_print_success_toast();
            }
        } catch (Error e) {
            warning("Failed to create print operation: %s", e.message);
            show_print_error_toast(e.message);
        }
#else
        show_print_error_toast(_("Print functionality requires WebKitGTK"));
#endif
    }
    
    // Signal methods for parent to connect to
    public signal void save_success_toast_requested(string file_path);
    public signal void save_error_toast_requested(string error_message);
    public signal void print_success_toast_requested(string message);
    public signal void print_error_toast_requested(string error_message);
    
    private void show_save_success_toast(string file_path) {
        save_success_toast_requested(_("Report saved to: %s").printf(file_path));
    }
    
    private void show_save_error_toast(string error_message) {
        save_error_toast_requested(_("Failed to save report: %s").printf(error_message));
    }
    
    private void show_print_success_toast() {
        print_success_toast_requested(_("Report sent to printer"));
    }
    
    private void show_print_error_toast(string error_message) {
        print_error_toast_requested(_("Failed to print report: %s").printf(error_message));
    }
    
    public void trigger_print() {
        on_print_report_clicked();
    }
}