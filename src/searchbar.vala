// This file is part of GNOME Boxes. License: LGPLv2+

[GtkTemplate (ui = "/org/gnome/Boxes/ui/searchbar.ui")]
private class Boxes.Searchbar: Gtk.SearchBar {
    public bool enable_key_handler {
        set {
            if (value)
                GLib.SignalHandler.unblock (window, key_handler_id);
            else
                GLib.SignalHandler.block (window, key_handler_id);
        }
    }
    [GtkChild]
    private Gtk.SearchEntry entry;

    private AppWindow window;

    private ulong key_handler_id;

    construct {
        search_mode_enabled = false;
    }

    public void setup_ui (AppWindow window) {
        this.window = window;

        key_handler_id = window.key_press_event.connect (on_app_key_pressed);
    }

    [GtkCallback]
    private void on_search_changed () {
        window.filter (text);
    }

    [GtkCallback]
    private void on_search_activated () {
        window.view.activate_first_item ();
    }

    [GtkCallback]
    private void on_search_mode_notify () {
        if (!search_mode_enabled)
            text = "";
    }

    public string text {
        get { return entry.text; }
        set { entry.set_text (value); }
    }

    private bool on_app_key_pressed (Gtk.Widget widget, Gdk.EventKey event) {
        if (window.ui_state != UIState.COLLECTION)
            return false;

        return handle_event ((Gdk.Event) event);
    }
}
