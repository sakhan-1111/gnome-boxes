// This file is part of GNOME Boxes. License: LGPLv2+
using Gtk;

private class Boxes.Property: GLib.Object {
    public string description { get; construct set; }
    public Gtk.Widget widget { get; construct set; }
    public bool changes_pending { get; set; }

    public Property (string description, Gtk.Widget widget) {
        base (description: description, widget: widget);
    }
}

private delegate void PropertyStringChanged (Boxes.Property property, string value) throws Boxes.Error;
private delegate void PropertySizeChanged (Boxes.Property property, uint64 value) throws Boxes.Error;

private interface Boxes.IPropertiesProvider: GLib.Object {
    public abstract List<Boxes.Property> get_properties (Boxes.PropertiesPage page);

    protected Boxes.Property add_property (ref List<Boxes.Property> list, string name, Widget widget) {
        var property = new Property (name, widget);
        list.append (property);
        return property;
    }

    protected Boxes.Property add_string_property (ref List<Boxes.Property>       list,
                                                  string                         name,
                                                  string                         value,
                                                  PropertyStringChanged?         changed = null) {
        var entry = new Boxes.EditableEntry ();

        entry.text = value;
        entry.selectable = true;
        entry.editable = changed != null;

        var property = add_property (ref list, name, entry);
        entry.editing_done.connect (() => {
            try {
                changed (property, entry.text);
            } catch (Boxes.Error.INVALID error) {
                entry.start_editing ();
            } catch (Boxes.Error error) {
                warning (error.message);
            }
        });

        return property;
    }

    protected Boxes.Property add_size_property (ref List<Boxes.Property>       list,
                                                string                         name,
                                                uint64                         size,
                                                uint64                         min,
                                                uint64                         max,
                                                uint64                         step,
                                                PropertySizeChanged?           changed = null) {
        var scale = new Gtk.HScale.with_range (min, max, step);

        scale.format_value.connect ((scale, value) => {
            return format_size (((uint64) value) * Osinfo.KIBIBYTES, FormatSizeFlags.IEC_UNITS);
        });

        scale.set_value (size);
        scale.hexpand = true;
        scale.margin_bottom = 20;

        var property = add_property (ref list, name, scale);
        if (changed != null)
            scale.value_changed.connect (() => {
                try {
                    changed (property, (uint64) scale.get_value ());
                } catch (Boxes.Error error) {
                    warning (error.message);
                }
            });

        return property;
    }
}

