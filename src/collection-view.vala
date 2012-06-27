// This file is part of GNOME Boxes. License: LGPLv2+
using Clutter;

public enum Boxes.SelectionCriteria {
    ALL,
    NONE,
    RUNNING
}

private class Boxes.CollectionView: Boxes.UI {
    public override Clutter.Actor actor { get { return gtkactor; } }

    private GtkClutter.Actor gtkactor;

    private Category _category;
    public Category category {
        get { return _category; }
        set {
            _category = value;
            // FIXME: update view
        }
    }

    private enum ModelColumns {
        SCREENSHOT = Gd.MainColumns.ICON,
        TITLE = Gd.MainColumns.PRIMARY_TEXT,
        INFO = Gd.MainColumns.SECONDARY_TEXT,
        SELECTED = Gd.MainColumns.SELECTED,
        ITEM = Gd.MainColumns.LAST,

        LAST
    }

    public Gd.MainIconView icon_view;
    private Gtk.ListStore model;
    private Gtk.TreeModelFilter model_filter;

    private string button_press_item_path;

    public bool visible {
        set { icon_view.visible = value; }
    }

    public CollectionView () {
        category = new Category (_("New and Recent"), Category.Kind.NEW);
        setup_view ();
        App.app.notify["selection-mode"].connect (() => {
            icon_view.set_selection_mode (App.app.selection_mode);
            if (!App.app.selection_mode)
                icon_view.unselect_all (); // Reset selection on exiting selection mode
        });
    }

    public void get_item_pos (CollectionItem item, out float x, out float y) {
        Gdk.Rectangle rect;
        var path = get_path_for_item (item);
        if (path != null) {
            icon_view.get_cell_rect (path, null, out rect);
            x = rect.x;
            y = rect.y;
        } else {
            x = 0.0f;
            y = 0.0f;
        }
    }

    public override void ui_state_changed () {
        if (ui_state == UIState.COLLECTION)
            icon_view.unselect_all ();
        fade_actor (actor, ui_state == UIState.COLLECTION ? 255 : 0);
    }

    private void update_item_visible (CollectionItem item) {
        var visible = false;

        // FIXME
        if (item is Machine) {
            var machine = item as Machine;

            switch (category.kind) {
            case Category.Kind.USER:
                visible = category.name in machine.config.categories;
                break;
            case Category.Kind.NEW:
                visible = true;
                break;
            }
        }

        item.actor.visible = visible;
    }

    private void update_screenshot (Gtk.TreeIter iter) {
        CollectionItem item;
        GLib.Icon[] emblem_icons = {};

        model.get (iter, ModelColumns.ITEM, out item);
        Machine machine = item as Machine;
        return_if_fail (machine != null);
        var pixbuf = machine.pixbuf;

        if ("favorite" in machine.config.categories)
            emblem_icons += create_symbolic_emblem ("emblem-favorite");

        if (emblem_icons.length > 0) {
            var emblemed_icon = new GLib.EmblemedIcon (pixbuf, null);
            foreach (var emblem_icon in emblem_icons)
                emblemed_icon.add_emblem (new GLib.Emblem (emblem_icon));

            var theme = Gtk.IconTheme.get_default ();

            try {
                var size = int.max (pixbuf.width, pixbuf.height);
                var icon_info = theme.lookup_by_gicon (emblemed_icon, size,
                                                       Gtk.IconLookupFlags.FORCE_SIZE);
                pixbuf = icon_info.load_icon ();
            } catch (GLib.Error error) {
                warning ("Unable to render the emblem: " + error.message);
            }
        }

        model.set (iter, ModelColumns.SCREENSHOT, pixbuf);
        icon_view.queue_draw ();
    }

    private Gtk.TreeIter append (string title,
                                 string? info,
                                 CollectionItem item) {
        Gtk.TreeIter iter;

        model.append (out iter);
        model.set (iter, ModelColumns.TITLE, title);
        if (info != null)
            model.set (iter, ModelColumns.INFO, info);
        model.set (iter, ModelColumns.SELECTED, false);
        model.set (iter, ModelColumns.ITEM, item);
        update_screenshot (iter);

        item.set_data<Gtk.TreeIter?> ("iter", iter);

        return iter;
    }

    public void add_item (CollectionItem item) {
        var machine = item as Machine;

        if (machine == null) {
            warning ("Cannot add item %p".printf (&item));
            return;
        }

        var iter = append (machine.name, machine.info, item);
        var pixbuf_id = machine.notify["pixbuf"].connect (() => {
            // apparently iter is stable after insertion/removal/sort
            update_screenshot (iter);
        });
        item.set_data<ulong> ("pixbuf_id", pixbuf_id);

        var categories_id = machine.config.notify["categories"].connect (() => {
            // apparently iter is stable after insertion/removal/sort
            update_screenshot (iter);
        });
        item.set_data<ulong> ("categories_id", categories_id);

        var name_id = item.notify["name"].connect (() => {
            // apparently iter is stable after insertion/removal/sort
            model.set (iter, ModelColumns.TITLE, item.name);
            icon_view.queue_draw ();
        });
        item.set_data<ulong> ("name_id", name_id);

        var info_id = machine.notify["info"].connect (() => {
            // apparently iter is stable after insertion/removal/sort
            model.set (iter, ModelColumns.INFO, machine.info);
            icon_view.queue_draw ();
        });
        item.set_data<ulong> ("info_id", info_id);

        item.ui_state = App.app.ui_state;
        actor_remove (item.actor);

        update_item_visible (item);
    }

    public List<CollectionItem> get_selected_items () {
        var selected = new List<CollectionItem> ();

        model.foreach ((model, path, iter) => {
            CollectionItem item;
            bool is_selected;

            model.get (iter,
                       ModelColumns.SELECTED, out is_selected,
                       ModelColumns.ITEM, out item);
            if (is_selected && item != null)
                selected.append (item);

            return false;
        });

        return (owned) selected;
    }

    public void remove_item (CollectionItem item) {
        var iter = item.get_data<Gtk.TreeIter?> ("iter");
        if (iter == null) {
            debug ("item not in view or already removed");
            return;
        }

        model.remove (iter);
        item.set_data<Gtk.TreeIter?> ("iter", null);

        var pixbuf_id = item.get_data<ulong> ("pixbuf_id");
        item.disconnect (pixbuf_id);
        var name_id = item.get_data<ulong> ("name_id");
        item.disconnect (name_id);
        var info_id = item.get_data<ulong> ("info_id");
        item.disconnect (info_id);

        if (item as Machine != null) {
            var machine = item as Machine;
            var categories_id = item.get_data<ulong> ("categories_id");
            machine.config.disconnect (categories_id);
        }
    }

    private Gtk.TreePath? get_path_for_item (CollectionItem item) {
        var iter = item.get_data<Gtk.TreeIter?> ("iter");
        if (iter == null)
            return null;

        Gtk.TreeIter filter_iter;
        if (!model_filter.convert_child_iter_to_iter (out filter_iter, iter))
            return null;

        return model_filter.get_path (filter_iter);
    }

    private CollectionItem get_item_for_iter (Gtk.TreeIter iter) {
        GLib.Value value;

        model.get_value (iter, ModelColumns.ITEM, out value);

        return (CollectionItem) value;
    }


    private CollectionItem get_item_for_path (Gtk.TreePath path) {
        Gtk.TreeIter filter_iter, iter;

        model_filter.get_iter (out filter_iter, path);
        model_filter.convert_iter_to_child_iter (out iter, filter_iter);

        return get_item_for_iter (iter);
    }

    private bool model_visible (Gtk.TreeModel model, Gtk.TreeIter iter) {
        var item = get_item_for_iter (iter);
        if (item  == null)
            return false;

        return App.app.filter.filter (item);
    }

    public void refilter () {
        model_filter.refilter ();
    }

    public void activate () {
        if (model_filter.iter_n_children (null) == 1) {
            Gtk.TreePath path = new Gtk.TreePath.from_string ("0");
            icon_view.item_activated (path);
        }
    }

    private void setup_view () {
        model = new Gtk.ListStore (ModelColumns.LAST,
                                   typeof (string),
                                   typeof (string),
                                   typeof (string),
                                   typeof (string),
                                   typeof (Gdk.Pixbuf),
                                   typeof (long),
                                   typeof (bool),
                                   typeof (CollectionItem));
        model.set_default_sort_func ((model, a, b) => {
            CollectionItem item_a, item_b;

            model.get (a, ModelColumns.ITEM, out item_a);
            model.get (b, ModelColumns.ITEM, out item_b);

            if (item_a == null || item_b == null) // FIXME?!
                return 0;

            return item_a.name.collate (item_b.name);
        });
        model.set_sort_column_id (Gtk.SortColumn.DEFAULT, Gtk.SortType.ASCENDING);
        model.row_deleted.connect (() => {
            App.app.notify_property ("selected-items");
        });
        model.row_inserted.connect (() => {
            App.app.notify_property ("selected-items");
        });

        model_filter = new Gtk.TreeModelFilter (model, null);
        model_filter.set_visible_func (model_visible);

        icon_view = new Gd.MainIconView ();
        icon_view.set_model (model_filter);
        icon_view.get_style_context ().add_class ("boxes-icon-view");
        icon_view.button_press_event.connect (on_button_press_event);
        icon_view.button_release_event.connect (on_button_release_event);
        icon_view_activate_on_single_click (icon_view, true);
        icon_view.item_activated.connect ((view, path) => {
            var item = get_item_for_path (path);
            App.app.select_item (item);
        });

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        // TODO: this should be set, but doesn't resize correctly the gtkactor..
        //        scrolled_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scrolled_window.add (icon_view);
        scrolled_window.show_all ();
        scrolled_window.set_shadow_type (Gtk.ShadowType.IN);
        scrolled_window.get_style_context ().add_class ("documents-scrolledwin");

        gtkactor = new GtkClutter.Actor.with_contents (scrolled_window);
        gtkactor.get_widget ().get_style_context ().add_class ("boxes-bg");
        gtkactor.name = "collection-view";
        gtkactor.x_align = Clutter.ActorAlign.FILL;
        gtkactor.y_align = Clutter.ActorAlign.FILL;
        gtkactor.x_expand = true;
        gtkactor.y_expand = true;
    }

    private bool on_button_press_event (Gtk.Widget view, Gdk.EventButton event) {
        Gtk.TreePath path = icon_view.get_path_at_pos ((int) event.x, (int) event.y);
        if (path == null)
            return false;

        button_press_item_path = path.to_string ();
        CollectionItem item = get_item_for_path (path);
        bool found = item != null;

        return !found; // if we did not find the item, block drag and drop
    }

    private bool on_button_release_event (Gtk.Widget view, Gdk.EventButton event) {
        /* eat double/triple click events */
        if (event.type != Gdk.EventType.BUTTON_RELEASE)
            return true;

        Gtk.TreePath path = icon_view.get_path_at_pos ((int) event.x, (int) event.y);

        var same_item = false;
        if (path != null) {
            string button_release_item_path = path.to_string ();

            same_item = button_press_item_path == button_release_item_path;
        }

        button_press_item_path = null;

        if (!same_item)
            return false;

        var entered_mode = false;
        if (!App.app.selection_mode)
            if (event.button == 3 || (event.button == 1 &&  Gdk.ModifierType.CONTROL_MASK in event.state)) {
                App.app.selection_mode = true;
                entered_mode = true;
            }

        if (App.app.selection_mode)
            return on_button_release_selection_mode (event, entered_mode, path);

        return false;
    }

    private bool on_button_release_selection_mode (Gdk.EventButton event, bool entered_mode, Gtk.TreePath path) {
        Gtk.TreeIter filter_iter, iter;

        if (!model_filter.get_iter (out filter_iter, path))
            return false;

        model_filter.convert_iter_to_child_iter (out iter, filter_iter);

        bool selected;
        model.get (iter, ModelColumns.SELECTED, out selected);

        if (selected && !entered_mode)
            model.set (iter, ModelColumns.SELECTED, false);
        else if (!selected)
            model.set (iter, ModelColumns.SELECTED, true);
        icon_view.queue_draw ();

        App.app.notify_property ("selected-items");

        return false;
    }

    public void select (SelectionCriteria selection) {
        App.app.selection_mode = true;

        model_filter.foreach ( (filter_model, filter_path, filter_iter) => {
            Gtk.TreeIter iter;
            model_filter.convert_iter_to_child_iter (out iter, filter_iter);
            bool selected;
            switch (selection) {
            default:
            case SelectionCriteria.ALL:
                selected = true;
                break;
            case SelectionCriteria.NONE:
                selected = false;
                break;
            case SelectionCriteria.RUNNING:
                CollectionItem item;
                model.get (iter, ModelColumns.ITEM, out item);
                selected = item != null && item is Machine &&
                    (item as Machine).is_running ();
                break;
            }
            model.set (iter, ModelColumns.SELECTED, selected);
            return false;
        });
        icon_view.queue_draw ();
        App.app.notify_property ("selected-items");
    }

}
