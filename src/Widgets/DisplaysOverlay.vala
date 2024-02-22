/*-
 * Copyright (c) 2014-2019 elementary, Inc. (https://elementary.io)
 *
 * This software is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this software; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 *              Felix Andreas <fandreas@physik.hu-berlin.de>
 */

public class Display.DisplaysOverlay : Gtk.Overlay {
    private const int SNAP_LIMIT = int.MAX - 1;
    private const int MINIMUM_WIDGET_OFFSET = 50;

    public signal void configuration_changed (bool changed);

    private bool scanning = false;
    // The ratio between the real dimensions of the virtual monitor(s) and the
    // allocated size of the overlay (min). Used for scaling movement of the
    // display widgets to changes in real monitor position and ensuring display widgets
    // fit inside overlay after dragging.
    private double current_ratio = 1.0f;

    private int current_allocated_width = 0;
    private int current_allocated_height = 0;
    private int default_x_margin = 0;
    private int default_y_margin = 0;

    private unowned Display.MonitorManager monitor_manager;
    private static GalaDBus gala_dbus = null;
    public int active_displays { get; set; default = 0; }

    private List<DisplayWidget> display_widgets;
    private DisplayWidget? dragging_display = null;
    public bool only_display {
        get {
            return active_displays <= 1;
        }
    }

    private static Gtk.CssProvider display_provider;

    private static string[] colors = {
        "@BLUEBERRY_100",
        "@STRAWBERRY_100",
        "@ORANGE_100",
        "@BANANA_100",
        "@LIME_100",
        "@GRAPE_100",
        "@COCOA_100"
    };
    private static string[] text_colors = {
        "@BLUEBERRY_900",
        "@STRAWBERRY_900",
        "@ORANGE_900",
        "@BANANA_900",
        "@LIME_900",
        "@GRAPE_900",
        "@COCOA_900"
    };

    const string COLORED_STYLE_CSS = """
        @define-color BG_COLOR %s;
        @define-color TEXT_COLOR %s;
    """;

    private Gtk.GestureDrag drag_gesture;

    construct {
        var grid = new Gtk.Grid () {
            hexpand = true,
            vexpand = true
        };
        grid.get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);
        child = grid;

        display_widgets = new List<DisplayWidget> ();

        drag_gesture = new Gtk.GestureDrag (this);
        drag_gesture.drag_begin.connect (on_drag_begin);
        drag_gesture.drag_update.connect (on_drag_update);
        drag_gesture.drag_end.connect (on_drag_end);

        monitor_manager = Display.MonitorManager.get_default ();
        monitor_manager.notify["virtual-monitor-number"].connect (() => rescan_displays ());
        rescan_displays ();
    }

    static construct {
        display_provider = new Gtk.CssProvider ();
        display_provider.load_from_resource ("io/elementary/switchboard/display/Display.css");

        GLib.Bus.get_proxy.begin<GalaDBus> (
            GLib.BusType.SESSION,
            "org.pantheon.gala.daemon",
            "/org/pantheon/gala/daemon",
            GLib.DBusProxyFlags.NONE,
            null,
            (obj, res) => {
            try {
                gala_dbus = GLib.Bus.get_proxy.end (res);
            } catch (GLib.Error e) {
                critical (e.message);
            }
        });
    }

    private double prev_dx = 0;
    private double prev_dy = 0;
    private void on_drag_begin (double x, double y) {
        if (only_display) {
            return;
        }

        Gdk.Rectangle start_rect = {(int) x, (int) y, 1, 1};
        Gtk.Allocation alloc;
        prev_dx = 0;
        prev_dy = 0;
        foreach (var display_widget in display_widgets) {
            get_child_position (display_widget, out alloc);
            if (start_rect.intersect (alloc, null)) {
                dragging_display = display_widget;
                break;
            }
        }

        reorder_overlay (dragging_display, -1);
    }

    // dx & dy are screen offsets from the start of dragging
    private void on_drag_update (double dx, double dy) {
        if (!only_display && dragging_display != null) {
            dragging_display.move_x ((int) ((dx - prev_dx) / current_ratio));
            dragging_display.move_y ((int) ((dy - prev_dy) / current_ratio));
            prev_dx = dx;
            prev_dy = dy;
        }
    }

    private void on_drag_end () {
        if (dragging_display != null) {
            verify_layout (dragging_display);
            dragging_display = null;
        }
    }

    // Determine the position in the overlay of a display widget based on its
    // virtual monitor geometry and any offsets when dragging.
    public override bool get_child_position (Gtk.Widget widget, out Gdk.Rectangle allocation) {
        allocation = Gdk.Rectangle ();
        if (current_allocated_width != get_allocated_width () ||
            current_allocated_height != get_allocated_height ()) {

            calculate_ratio ();
        }

        if (widget is DisplayWidget) {
            var display_widget = (DisplayWidget) widget;

            int x, y, width, height;
            display_widget.get_virtual_monitor_geometry (out x, out y, out width, out height);
            var x_start = (int) Math.round (x * current_ratio);
            var y_start = (int) Math.round (y * current_ratio);
            var x_end = (int) Math.round ((x + width) * current_ratio);
            var y_end = (int) Math.round ((y + height) * current_ratio);
            allocation.x = default_x_margin + x_start;
            allocation.y = default_y_margin + y_start;
            allocation.width = x_end - x_start;
            allocation.height = y_end - y_start;
            return true;
        }

        return false;
    }

    public void rescan_displays () {
        scanning = true;
        foreach (unowned var widget in display_widgets) {
            display_widgets.remove (widget);
            widget.destroy ();
        }

        active_displays = 0;
        foreach (var virtual_monitor in monitor_manager.virtual_monitors) {
            active_displays += virtual_monitor.is_active ? 1 : 0;
            add_output (virtual_monitor);
        }

        change_active_displays_sensitivity ();
        calculate_ratio ();
        scanning = false;
    }

    public void show_windows () requires (gala_dbus != null) {
        if (monitor_manager.is_mirrored) {
            return;
        }

        MonitorLabelInfo[] label_infos = {};

        foreach (unowned var widget in display_widgets) {
            if (widget.virtual_monitor.is_active) {
                label_infos += MonitorLabelInfo () {
                    monitor = label_infos.length,
                    label = widget.virtual_monitor.get_display_name (),
                    background_color = widget.bg_color,
                    text_color = widget.text_color,
                    x = widget.virtual_monitor.current_x,
                    y = widget.virtual_monitor.current_y
                };
            }
        }

        try {
            gala_dbus.show_monitor_labels (label_infos);
        } catch (Error e) {
            warning ("Couldn't show monitor labels: %s", e.message);
        }
    }

    public void hide_windows () requires (gala_dbus != null) {
        try {
            gala_dbus.hide_monitor_labels ();
        } catch (Error e) {
            warning ("Couldn't hide monitor labels: %s", e.message);
        }
    }

    private void change_active_displays_sensitivity () {
    }

    private void check_configuration_change () {
        // check if valid (connected)
        var result = true;
        foreach (unowned var dw in display_widgets) {
            dw.connected = false;
        }

        foreach (unowned var dw1 in display_widgets) {
            foreach (unowned var dw2 in display_widgets) {
                if (dw2 == dw1) {
                    warning ("Skip %s", dw2.display_name);
                    continue;
                } else if (dw1.connected) {
                    warning ("%s already connected", dw1.display_name);
                    break;
                }

                dw1.connected = is_connected (dw1, dw2);
                if (dw1.connected) {
                    dw2.connected = true;
                }
            }
        }

        foreach (unowned var dw in display_widgets) {
            if (!dw.connected) {
                result = false;
                break;
            }
        }

        configuration_changed (result);
    }

    // Determine whether two displays adjoin but do not overlap
    private bool is_connected (DisplayWidget dw1, DisplayWidget dw2) {
        int x1, y1, width1, height1;
        dw1.get_virtual_monitor_geometry (out x1, out y1, out width1, out height1);
        int x2, y2, width2, height2;
        dw2.get_virtual_monitor_geometry (out x2, out y2, out width2, out height2);
        Gdk.Rectangle rect1 = {x1, y1, width1, height1};
        Gdk.Rectangle rect2 = {x2 - 1, y2 - 1, width2 + 2, height2 + 2};
        Gdk.Rectangle intersection;
        return rect1.intersect (rect2, out intersection) &&
               (intersection.width == 1 || intersection.height == 1);
    }

    // Calculate the required scaling required to fit the current monitor
    // configuration into the overlay
    private void calculate_ratio () {
        int added_width = 0;
        int added_height = 0;
        int max_width = int.MIN;
        int max_height = int.MIN;

        foreach (unowned var display_widget in display_widgets) {
            int x, y, width, height;
            display_widget.get_virtual_monitor_geometry (out x, out y, out width, out height);

            added_width += width;
            added_height += height;
            max_width = int.max (max_width, x + width);
            max_height = int.max (max_height, y + height);
        }

        current_allocated_width = get_allocated_width ();
        current_allocated_height = get_allocated_height ();
        current_ratio = double.min (
            (double) (get_allocated_width () - 24) / (double) added_width,
            (double) (get_allocated_height () - 24) / (double) added_height
        );
        default_x_margin = (int) ((get_allocated_width () - max_width * current_ratio) / 2);
        default_y_margin = (int) ((get_allocated_height () - max_height * current_ratio) / 2);
    }

    private void add_output (Display.VirtualMonitor virtual_monitor) {
        current_allocated_width = 0;
        current_allocated_height = 0;

        var color_number = (get_children ().length () - 2) % 7;
        var display_widget = new DisplayWidget (virtual_monitor, colors[color_number], text_colors[color_number]);
        add_overlay (display_widget);
        display_widgets.append (display_widget);

        var provider = new Gtk.CssProvider ();
        try {
            var colored_css = COLORED_STYLE_CSS.printf (colors[color_number], text_colors[color_number]);
            provider.load_from_data (colored_css, colored_css.length);

            var context = display_widget.get_style_context ();
            context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            context.add_provider (display_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            context.add_class ("colored");

            context = display_widget.primary_image.get_style_context ();
            context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            context.add_provider (display_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            context.add_class ("colored");

            context = display_widget.toggle_settings.get_style_context ();
            context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            context.add_provider (display_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            context.add_class ("colored");
        } catch (GLib.Error e) {
            critical (e.message);
        }

        display_widget.show_all ();
        display_widget.set_as_primary.connect (() => set_as_primary (display_widget.virtual_monitor));

        display_widget.check_position.connect (() => {
            verify_layout (display_widget);
        });

        display_widget.configuration_changed.connect (check_configuration_change);
        display_widget.active_changed.connect (() => {
            active_displays += virtual_monitor.is_active ? 1 : -1;
            change_active_displays_sensitivity ();
            check_configuration_change ();
            calculate_ratio ();
        });

        if (!monitor_manager.is_mirrored && virtual_monitor.is_active) {
            show_windows ();
        }
    }

    private void set_as_primary (Display.VirtualMonitor new_primary) {
        foreach (unowned var widget in display_widgets) {
            var virtual_monitor = widget.virtual_monitor;
            var is_primary = virtual_monitor == new_primary;
            widget.set_primary (is_primary);
            virtual_monitor.primary = is_primary;
        }

        foreach (var virtual_monitor in monitor_manager.virtual_monitors) {
            virtual_monitor.primary = virtual_monitor == new_primary;
        }

        check_configuration_change ();
    }

    private void verify_layout (DisplayWidget changed_widget) {
        bool success = false;
        uint iteration = 0;
        // Continues iterating while at least one widget gets moved (or too many iterations)
        while (iteration < 10 &&
              (check_intersects (changed_widget) ||
              align_edges (changed_widget))
        ) {
            iteration++;
        }

        set_origin_zero ();
        calculate_ratio ();

        check_configuration_change ();
    }

    // Return true if a display moved
    private bool align_edges (
        DisplayWidget changed_widget,
        bool moved = false,
        uint level = 0
    ) {
        int x, y, width, height;
        Gdk.Rectangle overlap;
        foreach (unowned var other_display_widget in display_widgets) {
            if (other_display_widget == changed_widget) {
                continue;
            }

            changed_widget.get_virtual_monitor_geometry (
                out x,
                out y,
                out width,
                out height
            );
            Gdk.Rectangle source_rect = {x, y, width, height};
            int dx = 0, dy = 0;
            int other_x, other_y, other_width, other_height;
            other_display_widget.get_virtual_monitor_geometry (
                out other_x,
                out other_y,
                out other_width,
                out other_height
            );

            int dx_left = x - other_x;
            int dx_right = (x + width) - (other_x + other_width);
            int dy_top = y - other_y;
            int dy_bottom = (y + height) - (other_y + other_height);

            Gdk.Rectangle rect_top = {other_x, other_y - other_height, other_width, height};
            Gdk.Rectangle rect_bottom = {other_x, other_y + other_height, other_width, height};
            Gdk.Rectangle rect_left = {other_x - width, other_y, width, other_height};
            Gdk.Rectangle rect_right = {other_x + other_width, other_y, width, other_height};
            if (source_rect.intersect (rect_top, out overlap)) { // Move down
                dy = other_y - (y + height);
                if (dx_left.abs () < MINIMUM_WIDGET_OFFSET) {
                    dx = -dx_left;
                } else if (dx_right.abs () < MINIMUM_WIDGET_OFFSET) {
                    dx = -dx_right;
                }
            } else if (source_rect.intersect (rect_bottom, out overlap)) {
                dy = other_y + other_height - y;
                if (dx_left.abs () < MINIMUM_WIDGET_OFFSET) {
                    dx = -dx_left;
                } else if (dx_right.abs () < MINIMUM_WIDGET_OFFSET) {
                    dx = -dx_right;
                }
            } else if (source_rect.intersect (rect_left, out overlap)) {
                dx = other_x - (x + width);
                if (dy_top.abs () < MINIMUM_WIDGET_OFFSET) {
                    dy = -dy_top;
                } else if (dy_bottom.abs () < MINIMUM_WIDGET_OFFSET) {
                    dy = -dy_bottom;
                }
            } else if (source_rect.intersect (rect_right, out overlap)) {
                dx = (other_x + other_width) - x;
                if (dy_top.abs () < MINIMUM_WIDGET_OFFSET) {
                    dy = -dy_top;
                } else if (dy_bottom.abs () < MINIMUM_WIDGET_OFFSET) {
                    dy = -dy_bottom;
                }
            }

            other_display_widget.move_x (-dx);
            other_display_widget.move_y (-dy);
            moved = moved || dx != 0 || dy != 0;
            if (dx != 0 || dy != 0) {
                align_edges (other_display_widget, moved, ++level);
            }
        }

        return moved;
    }

    // Ensure real monitor coords have origin of {0, 0}
    private void set_origin_zero () {
        int min_x = int.MAX;
        int min_y = int.MAX;

        foreach (unowned var display_widget in display_widgets) {
            int x, y, width, height;
            // assert (display_widget.delta_x == 0 && display_widget.delta_y == 0);
            display_widget.get_virtual_monitor_geometry (
                out x,
                out y,
                out width,
                out height
            );
            min_x = int.min (min_x, x);
            min_y = int.min (min_y, y);
        }

        if (min_x == 0 && min_y == 0) {
            return;
        }

        foreach (unowned var display_widget in display_widgets) {
            int x, y, width, height;
            display_widget.get_virtual_monitor_geometry (
                out x,
                out y,
                out width,
                out height
            );
            display_widget.set_virtual_monitor_geometry (
                x - min_x,
                y - min_y,
                width,
                height
            );
        }

        return;
    }

    // If widget is not contiguous with any other widgets -> move other widgets to fix
    // Return true if a display moved
    private bool check_intersects (
        DisplayWidget changed_widget,
        bool moved = false,
        uint level = 0
    ) {
        if (only_display) {
            return false;
        }

        if (level > 10) {
            warning ("Depth of recursion exceeds limit (10)");
            return moved;
        }

        int x, y, width, height;
        changed_widget.get_virtual_monitor_geometry (
            out x,
            out y,
            out width,
            out height
        );

        Gdk.Rectangle src_rect = { x, y, width, height };
        foreach (unowned var other_display_widget in display_widgets) {
            int distance_x = 0;
            int distance_y = 0;
            if (other_display_widget == changed_widget) {
                continue;
            }

            int other_x, other_y, other_width, other_height;
            other_display_widget.get_virtual_monitor_geometry (
                out other_x,
                out other_y,
                out other_width,
                out other_height
            );
            Gdk.Rectangle overlap;
            Gdk.Rectangle other_rect = { other_x, other_y, other_width, other_height };
            if (src_rect.intersect (other_rect, out overlap)) {
                // delta to align on left of other
                var dx_left = ((x + width) - other_x).abs ();
                //delta to align on right of other
                var dx_right = ((other_x + other_width) - x).abs ();
                // delta to align on top of other
                var dy_top = ((y + height) - other_y).abs ();
                //delta to align on bottom of other
                int dy_bottom = ((other_y + other_height) - y).abs ();
                if (x < other_x) {
                    if (y < other_y) {
                        //Align on top/left of other
                        distance_x = overlap.width > overlap.height ? 0 : dx_left;
                        distance_y = overlap.width > overlap.height ? dy_top : 0;
                    } else {
                        //Align on bottom/left of other
                        distance_x = overlap.width > overlap.height ? 0 : dx_left;
                        distance_y = overlap.width > overlap.height ? -dy_bottom : 0;
                    }
                } else {
                   if (y < other_y) {
                       //Align on top/right of other
                        distance_x = overlap.width > overlap.height ? 0 : -dx_right;
                        distance_y = overlap.width > overlap.height ? dy_top : 0;
                   } else {
                       //Align on bottom/right of other
                        distance_x = overlap.width > overlap.height ? 0 : -dx_right;
                        distance_y = overlap.width > overlap.height ? -dy_bottom : 0;
                   }
                }

                other_display_widget.move_x (distance_x);
                other_display_widget.move_y (distance_y);
                check_intersects (other_display_widget, moved, ++level);
            }

            moved = moved || distance_x != 0 || distance_y != 0;
        }

        return moved;
    }
}
