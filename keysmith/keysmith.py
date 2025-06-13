import sys
import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Gtk, Adw, Gio, GLib

class KeySmithWindow(Adw.ApplicationWindow):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.set_default_size(600, 400)
        self.set_title("KeySmith")

        self.main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_content(self.main_box)

        header_bar = Adw.HeaderBar()
        self.main_box.append(header_bar)

        label = Gtk.Label(label="Welcome to KeySmith!")
        label.set_halign(Gtk.Align.CENTER)
        label.set_valign(Gtk.Align.CENTER)
        label.set_vexpand(True)
        self.main_box.append(label)


class KeySmithApplication(Adw.Application):
    def __init__(self, **kwargs):
        super().__init__(application_id="io.github.tobagin.KeySmith",
                         flags=Gio.ApplicationFlags.FLAGS_NONE,
                         **kwargs)

    def do_activate(self):
        win = KeySmithWindow(application=self)
        win.present()

    def do_startup(self):
        Gtk.Application.do_startup(self)

    def do_shutdown(self):
        Gtk.Application.do_shutdown(self)


def main():
    app = KeySmithApplication()
    return app.run(sys.argv)

if __name__ == "__main__":
    sys.exit(main())
