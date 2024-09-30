/*
 * Copyright 2024 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

public class Display.MonitorLabel : Gtk.Window, PantheonWayland.ExtendedBehavior {
    private const int SPACING = 12;
    private const string COLORED_STYLE_CSS = """
    .label-%d {
        background-color: alpha(%s, 0.8);
        color: %s;
    }
    """;

    public int index { get; construct; }
    public string label { get; construct; }
    public string bg_color { get; construct; }
    public string text_color { get; construct; }

    public MonitorLabel (int index, string label, string bg_color, string text_color) {
        Object (
            index: index,
            label: label,
            bg_color: bg_color,
            text_color: text_color
        );
    }

    construct {
        child = new Gtk.Label (label);

        decorated = false;
        resizable = false;
        deletable = false;
        can_focus = false;
        titlebar = new Gtk.Grid ();

        var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_string (COLORED_STYLE_CSS.printf (index, bg_color, text_color));
            get_style_context ().add_class ("label-%d".printf (index));
            get_style_context ().add_class ("monitor-label");

            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        } catch (Error e) {
            warning ("Failed to load CSS: %s", e.message);
        }

        var display = Gdk.Display.get_default ();
        if (display is Gdk.X11.Display) {
            unowned var xdisplay = ((Gdk.X11.Display) display).get_xdisplay ();

            var window = ((Gdk.X11.Surface) get_surface ()).get_xid ();

            var prop = xdisplay.intern_atom ("_MUTTER_HINTS", false);

            var value = "monitor-label=%d".printf (index);

            xdisplay.change_property (window, prop, X.XA_STRING, 8, 0, (uchar[]) value, value.length);
        } else {
            child.realize.connect (() => {
                connect_to_shell ();
                make_monitor_label (index);
            });
        }

        present ();
    }
}
