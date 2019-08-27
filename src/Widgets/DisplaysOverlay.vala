/*-
 * Copyright (c) 2014-2018 elementary LLC.
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
 */

public class Display.DisplaysOverlay : Gtk.Overlay {
    private const int SNAP_LIMIT = int.MAX - 1;

    public signal void configuration_changed (bool changed);

    private bool scanning = false;
    private double current_ratio = 1.0f;
    private int current_allocated_width = 0;
    private int current_allocated_height = 0;
    private int default_x_margin = 0;
    private int default_y_margin = 0;

    private unowned Display.MonitorManager monitor_manager;
    public int active_displays { get; set; default = 0; }
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

    public DisplaysOverlay () {
        var grid = new Gtk.Grid ();
        grid.get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);
        grid.expand = true;
        add (grid);

        monitor_manager = Display.MonitorManager.get_default ();
        monitor_manager.notify["virtual-monitor-number"].connect (() => rescan_displays ());
        rescan_displays ();
    }

    public override bool get_child_position (Gtk.Widget widget, out Gdk.Rectangle allocation) {
        if (current_allocated_width != get_allocated_width () || current_allocated_height != get_allocated_height ()) {
            calculate_ratio ();
        }

        if (widget is DisplayWidget) {
            var display_widget = (DisplayWidget) widget;

            int x, y, width, height;
            display_widget.get_geometry (out x, out y, out width, out height);
            allocation = Gdk.Rectangle ();
            allocation.width = (int)(width * current_ratio);
            allocation.height = (int)(height * current_ratio);
            allocation.x = default_x_margin + (int) ((x +  display_widget.delta_x) * current_ratio);
            allocation.y = default_y_margin + (int) ((y +  display_widget.delta_y) * current_ratio);
            return true;
        }

        return false;
    }

    public void rescan_displays () {
        scanning = true;
        get_children ().foreach ((child) => {
            if (child is DisplayWidget) {
                child.destroy ();
            }
        });

        active_displays = 0;
        foreach (var virtual_monitor in monitor_manager.virtual_monitors) {
            active_displays += virtual_monitor.is_active ? 1 : 0;
            add_output (virtual_monitor);
        }

        change_active_displays_sensitivity ();
        calculate_ratio ();
        scanning = false;
    }

    public void show_windows () {
        if (monitor_manager.is_mirrored) {
            return;
        }

        get_children ().foreach ((child) => {
            if (child is DisplayWidget) {
                if (((DisplayWidget) child).virtual_monitor.is_active) {
                    ((DisplayWidget) child).display_window.show_all ();
                }
            }
        });
    }

    public void hide_windows () {
        get_children ().foreach ((child) => {
            if (child is DisplayWidget) {
                ((DisplayWidget) child).display_window.hide ();
            }
        });
    }

    private void change_active_displays_sensitivity () {
        get_children ().foreach ((child) => {
            if (child is DisplayWidget) {
                if (((DisplayWidget) child).virtual_monitor.is_active) {
                    ((DisplayWidget) child).only_display = (active_displays == 1);
                }
            }
        });
    }

    private void check_configuration_changed () {
        // TODO check if it actually has changed
        configuration_changed (true);
    }

    private void calculate_ratio () {
        int added_width = 0;
        int added_height = 0;
        int max_width = int.MIN;
        int max_height = int.MIN;

        get_children ().foreach ((child) => {
            if (child is DisplayWidget) {
                var display_widget = (DisplayWidget) child;
                int x, y, width, height;
                x = display_widget.virtual_monitor.x;
                y = display_widget.virtual_monitor.y;
                display_widget.virtual_monitor.get_current_mode_size (out width, out height);

                added_width += width;
                added_height += height;
                max_width = int.max (max_width, x + width);
                max_height = int.max (max_height, y + height);
            }
        });

        current_allocated_width = get_allocated_width ();
        current_allocated_height = get_allocated_height ();
        current_ratio = double.min ((double) (get_allocated_width () - 24) / (double) added_width, (double) (get_allocated_height () - 24) / (double) added_height);
        default_x_margin = (int) ((get_allocated_width () - max_width * current_ratio) / 2);
        default_y_margin = (int) ((get_allocated_height () - max_height * current_ratio) / 2);
    }

    private void add_output (Display.VirtualMonitor virtual_monitor) {
        var display_widget = new DisplayWidget (virtual_monitor);
        current_allocated_width = 0;
        current_allocated_height = 0;
        add_overlay (display_widget);
        var provider = new Gtk.CssProvider ();
        try {
            var color_number = (get_children ().length ()-2)%7;

            var colored_css = COLORED_STYLE_CSS.printf (colors[color_number], text_colors[color_number]);
            provider.load_from_data (colored_css, colored_css.length);

            var display_provider = new Gtk.CssProvider ();
            display_provider.load_from_resource ("io/elementary/switchboard/display/Display.css");

            var context = display_widget.get_style_context ();
            context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            context.add_provider (display_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            context.add_class ("colored");

            context = display_widget.display_window.get_style_context ();
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
            check_intersects (display_widget);
            close_gaps ();
        });
        display_widget.move_display.connect ((diff_x, diff_y, event) => move_display (display_widget, diff_x, diff_y, event));
        display_widget.configuration_changed.connect (() => check_configuration_changed ());
        display_widget.active_changed.connect (() => {
            active_displays += virtual_monitor.is_active ? 1 : -1;
            change_active_displays_sensitivity ();
            check_configuration_changed ();
            calculate_ratio ();
        });

        if (!monitor_manager.is_mirrored && virtual_monitor.is_active) {
            display_widget.display_window.show_all ();
        }

        display_widget.end_grab.connect ((delta_x, delta_y) => {
            if (delta_x == 0 && delta_y == 0) {
                return;
            }

            int x, y, width, height;
            display_widget.get_geometry (out x, out y, out width, out height);
            display_widget.set_geometry (delta_x + x, delta_y + y, width, height);
            display_widget.queue_resize_no_redraw ();
            check_configuration_changed ();
            check_intersects (display_widget);
            snap_edges (display_widget);
            close_gaps ();
            verify_global_positions ();
            calculate_ratio ();
        });

        check_intersects (display_widget);
        var old_delta_x = display_widget.delta_x;
        var old_delta_y = display_widget.delta_y;
        display_widget.delta_x = 0;
        display_widget.delta_y = 0;
        display_widget.end_grab (old_delta_x, old_delta_y);
    }

    private void set_as_primary (Display.VirtualMonitor new_primary) {
        get_children ().foreach ((child) => {
            if (child is DisplayWidget) {
                var display_widget = child as DisplayWidget;
                var virtual_monitor = display_widget.virtual_monitor;
                var is_primary = virtual_monitor == new_primary;
                display_widget.set_primary (is_primary);
                virtual_monitor.primary = is_primary;
            }
        });
        foreach (var virtual_monitor in monitor_manager.virtual_monitors) {
            virtual_monitor.primary = virtual_monitor == new_primary;
        }

        check_configuration_changed ();
    }

    private void move_display (DisplayWidget display_widget, double diff_x, double diff_y, Gdk.EventMotion event) {
        reorder_overlay (display_widget, -1);
        display_widget.delta_x = (int) (diff_x / current_ratio);
        display_widget.delta_y = (int) (diff_y / current_ratio);
        display_widget.queue_resize_no_redraw ();
    }

    private void close_gaps () {
        var display_widgets = new List<DisplayWidget>();
        foreach (var child in get_children ()) {
            if (child is DisplayWidget) {
                display_widgets.append ((DisplayWidget) child);
            }
        }

        foreach (var display_widget in display_widgets) {
            if (!is_connected (display_widget, display_widgets)) {
                snap_edges (display_widget);
            }
        }
    }

    // to check if a display_widget is connected (has no gaps) one can check if
    // a 1px larger rectangle intersects with any of other display_widgets
    private bool is_connected (DisplayWidget display_widget, List<DisplayWidget> other_display_widgets) {
        int x, y, width, height;
        display_widget.get_geometry (out x, out y, out width, out height);
        Gdk.Rectangle rect = {x - 1, y - 1, width + 2, height + 2};

        foreach (var other_display_widget in other_display_widgets) {
            if (other_display_widget == display_widget) {
                continue;
            }

            int other_x, other_y, other_width, other_height;
            other_display_widget.get_geometry (out other_x, out other_y, out other_width, out other_height);

            Gdk.Rectangle other_rect = {other_x, other_y, other_width, other_height};
            Gdk.Rectangle intersection;
            var is_connected = rect.intersect (other_rect, out intersection);
            var is_diagonal = intersection.height == 1 && intersection.width == 1;
            if (is_connected && !is_diagonal) {
                return true;
            }
        }
        return false;
    }

    private void verify_global_positions () {
        int min_x = int.MAX;
        int min_y = int.MAX;
        get_children ().foreach ((child) => {
            if (child is DisplayWidget) {
                var display_widget = (DisplayWidget) child;
                int x, y, width, height;
                display_widget.get_geometry (out x, out y, out width, out height);
                min_x = int.min (min_x, x);
                min_y = int.min (min_y, y);
            }
        });

        if (min_x == 0 && min_y == 0)
          return;

        get_children ().foreach ((child) => {
            if (child is DisplayWidget) {
                var display_widget = (DisplayWidget) child;
                int x, y, width, height;
                display_widget.get_geometry (out x, out y, out width, out height);
                display_widget.set_geometry (x - min_x, y - min_y, width, height);
            }
        });
    }

    // If widget is intersects with any other widgets -> move other widgets to fix intersection
    public void check_intersects (DisplayWidget source_display_widget, int level = 0, int distance_x = 0, int distance_y = 0) {
        if (level > 10) {
            warning ("Maximum level of recursion reached! Could not fix intersects!");
            return;
        }

        int source_x, source_y, source_width, source_height;
        source_display_widget.get_geometry (out source_x, out source_y, out source_width, out source_height);
        Gdk.Rectangle src_rect = { source_x, source_y, source_width, source_height };

        foreach (var child in get_children ()) {
            if (!(child is DisplayWidget) || (DisplayWidget) child == source_display_widget) {
                continue;
            }

            var other_display_widget = (DisplayWidget) child;
            int other_x, other_y, other_width, other_height;
            other_display_widget.get_geometry (out other_x, out other_y, out other_width, out other_height);
            Gdk.Rectangle test_rect = { other_x, other_y, other_width, other_height };
            if (src_rect.intersect (test_rect, null)) {
                if (level == 0) {
                    var distance_left   = source_x - other_x - other_width;
                    var distance_right  = source_x - other_x + source_width;
                    var distance_top    = source_y - other_y - other_height;
                    var distance_bottom = source_y - other_y + source_height;
                    var test_distance_x = distance_right  < -distance_left ? distance_right : distance_left;
                    var test_distance_y = distance_bottom < -distance_top ? distance_bottom : distance_top;

                    // if distance to upper egde == distance lower edge, move horizontally
                    if (test_distance_x.abs () <= test_distance_y.abs () || distance_top == -distance_bottom) {
                        distance_x = test_distance_x;
                    } else {
                        distance_y = test_distance_y;
                    }
                }

                other_display_widget.set_geometry (other_x + distance_x, other_y + distance_y, other_width, other_height);
                other_display_widget.queue_resize_no_redraw ();
                check_intersects (other_display_widget, level + 1, distance_x, distance_y);
            }
        }
    }

    public void snap_edges (DisplayWidget last_moved) {
        if (scanning) return;
        // Snap last_moved
        debug ("Snapping displays");
        var anchors = new List<DisplayWidget>();
        get_children ().foreach ((child) => {
            if (!(child is DisplayWidget) || last_moved.equals ((DisplayWidget)child)) return;
            anchors.append ((DisplayWidget) child);
        });

        snap_widget (last_moved, anchors);

        /*/ FIXME: Re-Snaping with 3 or more displays is broken
        // This is used to make sure all displays are connected
        anchors = new List<DisplayWidget>();
        get_children ().foreach ((child) => {
            if (!(child is DisplayWidget)) return;
            snap_widget ((DisplayWidget) child, anchors);
            anchors.append ((DisplayWidget) child);
        });*/
    }

   /******************************************************************************************
    *   Widget snaping is done by trying to snap a widget to other widgets called Anchors.   *
    *   It first calculates the distance between each anchor and the widget, and afterwards  *
    *   snaps the widget to the closest edge/corner                                          *
    *                                                                                        *
    *   Cases:          W = widget, A = current anchor                                       *
    *                                                                                        *
    *   1.        2.        3.        4.        5.        6.        7.         8.            *
    *     A W       W A        A         W         W          W         A         A          *
    *                          W         A          A        A           W       W           *
    *                                                                                        *
    ******************************************************************************************/

    private void snap_widget (Display.DisplayWidget widget, List<Display.DisplayWidget> anchors) {
        if (anchors.length () == 0) {
            return;
        }

        int widget_x, widget_y, widget_width, widget_height;
        widget.get_geometry (out widget_x, out widget_y, out widget_width, out widget_height);
        widget_x += widget.delta_x;
        widget_y += widget.delta_y;

        int distance = int.MAX, distance_x = 0, distance_y = 0;
        foreach (var anchor in anchors) {
            int anchor_x, anchor_y, anchor_width, anchor_height;
            anchor.get_geometry (out anchor_x, out anchor_y, out anchor_width, out anchor_height);

            var diff_x = anchor_x - widget_x;
            var diff_y = anchor_y - widget_y;
            var distance_left   = diff_x + anchor_width;
            var distance_right  = diff_x - widget_width;
            var distance_top    = diff_y + anchor_height;
            var distance_bottom = diff_y - widget_height;
            var test_distance_x = distance_right > -distance_left ? distance_right : distance_left;
            var test_distance_y = distance_bottom > -distance_top ? distance_bottom : distance_top;

            if (distance_left > 0 && distance_right < 0) {
                test_distance_x = 0;
            } else if (distance_top > 0 && distance_bottom < 0) {
                test_distance_y = 0;
            } else { // As diagonal monitors are not allowed, offset by 50px
                if (test_distance_x.abs () >= test_distance_y.abs ()) {
                    test_distance_x += diff_x > 0 ? 50 : -50;
                } else {
                    test_distance_y += diff_y > 0 ? 50 : -50;
                }
            }

            var test_distance = test_distance_x * test_distance_x + test_distance_y * test_distance_y;
            if (test_distance < distance) {
                distance_x = test_distance_x;
                distance_y = test_distance_y;
                distance = test_distance;
            }
        }

        widget.set_geometry (widget_x + distance_x, widget_y + distance_y, widget_width, widget_height);
    }
}
