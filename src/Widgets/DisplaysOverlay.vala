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
    private static string[] colors = {"#3892e0", "#da4d45", "#f37329", "#fbd25d", "#93d844", "#8a4ebf", "#333333"};

    const string COLORED_STYLE_CSS = """
        .colored {
            background-color: %s;
            color: %s;
        }

        .colored.disabled {
            background-color: #aaa;
        }
    """;

    public DisplaysOverlay () {
        var grid = new Gtk.Grid ();
        grid.get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);
        grid.expand = true;
        add (grid);

        monitor_manager = Display.MonitorManager.get_default ();
        rescan_displays ();

        /*rr_screen.output_connected.connect (() => rescan_displays ());
        rr_screen.output_disconnected.connect (() => rescan_displays ());
        rr_screen.changed.connect (() => rescan_displays ());*/
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
            allocation.x = default_x_margin + (int)(x * current_ratio) + display_widget.delta_x;
            allocation.y = default_y_margin + (int)(y * current_ratio) + display_widget.delta_y;
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
        /*if (rr_config.get_clone ()) {
            return;
        }*/

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
                width = display_widget.virtual_monitor.monitor.current_mode.width;
                height = display_widget.virtual_monitor.monitor.current_mode.height;

                added_width += width;
                added_height += height;
                max_width = int.max (max_width, x + width);
                max_height = int.max (max_height, y + height);
            }
        });

        current_allocated_width = get_allocated_width ();
        current_allocated_height = get_allocated_height ();
        current_ratio = double.min ((double)(get_allocated_width () -24) / (double) added_width, (double)(get_allocated_height ()-24) / (double) added_height);
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
            var font_color = "#ffffff";
            if (color_number == 3 || color_number == 4) {
                font_color = "#333333";
            }

            var colored_css = COLORED_STYLE_CSS.printf (colors[color_number], font_color);
            provider.load_from_data (colored_css, colored_css.length);
            var context = display_widget.get_style_context ();
            context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            context.add_class ("colored");
            context = display_widget.display_window.get_style_context ();
            context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            context.add_class ("colored");
        } catch (GLib.Error e) {
            critical (e.message);
        }

        display_widget.show_all ();
        display_widget.set_as_primary.connect (() => set_as_primary (display_widget.virtual_monitor));
        display_widget.check_position.connect (() => check_intersects (display_widget));
        display_widget.configuration_changed.connect (() => check_configuration_changed ());
        display_widget.active_changed.connect (() => {
            active_displays += virtual_monitor.is_active ? 1 : -1;
            change_active_displays_sensitivity ();
            check_configuration_changed ();
            calculate_ratio ();
        });

        if (/*!rr_config.get_clone () && */virtual_monitor.is_active) {
            display_widget.display_window.show_all ();
        }

        display_widget.move_display.connect ((delta_x, delta_y) => {
            if (delta_x == 0 && delta_y == 0) {
                return;
            }

            int x, y, width, height;
            display_widget.get_geometry (out x, out y, out width, out height);
            display_widget.set_geometry ((int)(delta_x / current_ratio) + x, (int)(delta_y / current_ratio) + y, width, height);
            display_widget.queue_resize_no_redraw ();
            check_configuration_changed ();
            snap_edges (display_widget);
            verify_global_positions ();
            calculate_ratio ();
        });

        check_intersects (display_widget);
        var old_delta_x = display_widget.delta_x;
        var old_delta_y = display_widget.delta_y;
        display_widget.delta_x = 0;
        display_widget.delta_y = 0;
        display_widget.move_display (old_delta_x, old_delta_y);
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

    public void check_intersects (DisplayWidget source_display_widget) {
        int orig_x, orig_y, src_x, src_y, src_width, src_height;
        source_display_widget.get_geometry (out orig_x, out orig_y, out src_width, out src_height);
        src_x = orig_x + (int)(source_display_widget.delta_x/current_ratio);
        src_y = orig_y + (int)(source_display_widget.delta_y/current_ratio);
        Gdk.Rectangle src_rect = {src_x, src_y, src_width, src_height};
        get_children ().foreach ((child) => {
            if (child is DisplayWidget) {
                var display_widget = (DisplayWidget) child;
                if (display_widget == source_display_widget) {
                    return;
                }

                int x, y, width, height;
                display_widget.get_geometry (out x, out y, out width, out height);
                Gdk.Rectangle test_rect = {x, y, width, height};
                Gdk.Rectangle intersection;
                if (src_rect.intersect (test_rect, out intersection)) {
                    if (intersection.height == src_height) {
                        // on the left side
                        if (intersection.x <= x + width/2) {
                            source_display_widget.delta_x = (int) ((x - (orig_x + src_width)) * current_ratio);
                        // on the right side
                        } else {
                            source_display_widget.delta_x = (int) ((x - orig_x + width) * current_ratio);
                        }
                    } else if (intersection.width == src_width) {
                        // on the bottom side
                        if (intersection.y <= y + height/2) {
                            source_display_widget.delta_y = (int) ((y - (orig_y + src_height)) * current_ratio);
                        } else {
                        // on the upper side
                            source_display_widget.delta_y = (int) ((y - orig_y + height) * current_ratio);
                        }
                    } else {
                        if (intersection.width < intersection.height) {
                            // on the left side
                            if (intersection.x <= x + width/2) {
                                source_display_widget.delta_x = (int) ((x - (orig_x + src_width)) * current_ratio);
                            // on the right side
                            } else {
                                source_display_widget.delta_x = (int) ((x - orig_x + width) * current_ratio);
                            }
                        } else {
                            // on the bottom side
                            if (intersection.y <= y + height/2) {
                                source_display_widget.delta_y = (int) ((y - (orig_y + src_height)) * current_ratio);
                            } else {
                            // on the upper side
                                source_display_widget.delta_y = (int) ((y - orig_y + height) * current_ratio);
                            }
                        }
                    }
                }
            }
        });

        source_display_widget.queue_resize_no_redraw ();
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
    *   Widget snaping is done by trying to snap a child to other widgets called Anchors.    *
    *   It first calculates the distance between each anchor and the child, and afterwards   *
    *   snaps the child to the closest edge                                                  *
    *                                                                                        *
    *   Cases:          C = child, A = current anchor                                        *
    *                                                                                        *
    *   1.        2.        3.        4.                                                     *
    *     A C       C A        A         C                                                   *
    *                          C         A                                                   *
    *                                                                                        *
    ******************************************************************************************/
    private void snap_widget (Display.DisplayWidget child, List<Display.DisplayWidget> anchors) {
        if (anchors.length () == 0) return;
        int child_x, child_y, child_width, child_height;
        child.get_geometry (out child_x, out child_y, out child_width, out child_height);
        debug ("Child: %d %d %d %d\n", child_x, child_y, child_width, child_height);

        bool snap_y = false, snap_x = false, move = false, diagonally = false;
        int case_1 = int.MAX, case_2 = int.MAX, case_3 = int.MAX, case_4 = int.MAX;

        foreach (var anchor in anchors) {
            if (child.equals (anchor)) continue;

            int anchor_x, anchor_y, anchor_width, anchor_height;
            anchor.get_geometry (out anchor_x, out anchor_y, out anchor_width, out anchor_height);
            debug ("Anchor: %d %d %d %d\n", anchor_x, anchor_y, anchor_width, anchor_height);

            int case_1_t = child_x - anchor_x - anchor_width;
            int case_2_t = child_x - anchor_x + child_width;
            int case_3_t = child_y - anchor_y - anchor_height;
            int case_4_t = child_height + child_y - anchor_y;

            // Check projections
            if (is_projected (child_y, child_height, anchor_y, anchor_height)) {
                debug ("Child is on the X axis of Anchor %s\n", anchor.virtual_monitor.monitor.display_name);
                case_1 = is_x_smaller_absolute (case_1, case_1_t) && !diagonally ? case_1 : case_1_t;
                case_2 = is_x_smaller_absolute (case_2, case_2_t) && !diagonally ? case_2 : case_2_t;
                snap_x = true;
                move = true;
            } else if (is_projected (child_x, child_width, anchor_x, anchor_width)) {
                debug ("Child is on the Y axis of Anchor %s\n", anchor.virtual_monitor.monitor.display_name);
                case_3 = is_x_smaller_absolute (case_3, case_3_t) && !diagonally ? case_3 : case_3_t;
                case_4 = is_x_smaller_absolute (case_4, case_4_t) && !diagonally ? case_4 : case_4_t;
                snap_y = true;
                move = true;
            } else {
                debug ("Child is diagonally of Anchor %s\n", anchor.virtual_monitor.monitor.display_name);
                if (!move) {
                    diagonally = true;
                    case_1 = is_x_smaller_absolute (case_1, case_1_t) ? case_1 : case_1_t;
                    case_2 = is_x_smaller_absolute (case_2, case_2_t) ? case_2 : case_2_t;
                    case_3 = is_x_smaller_absolute (case_3, case_3_t) ? case_3 : case_3_t;
                    case_4 = is_x_smaller_absolute (case_4, case_4_t) ? case_4 : case_4_t;
                }
            }
        }

        int shortest_x = is_x_smaller_absolute (case_1, case_2) ? case_1 : case_2;
        int shortest_y = is_x_smaller_absolute (case_3, case_4) ? case_3 : case_4;

        // X Snapping
        if (!snap_y || is_x_smaller_absolute (shortest_x, shortest_y)) {
            if (snap_x & move) {
                debug ("moving child %d on X\n", shortest_x);
                if (shortest_x < SNAP_LIMIT) ((DisplayWidget) child).set_geometry (child_x - shortest_x, child_y , child_width, child_height);
            }
        }

        // Y Snapping
        if (!snap_x || is_x_smaller_absolute (shortest_y, shortest_x)) {
            if (snap_y & move) {
                debug ("moving child %d on Y\n", shortest_y);
                if (shortest_y < SNAP_LIMIT) ((DisplayWidget) child).set_geometry (child_x , child_y - shortest_y, child_width, child_height);
            }
        }

        // X & Y Snapping
        if (!snap_x && !snap_y) {
            if (shortest_x < SNAP_LIMIT && shortest_y < SNAP_LIMIT) {
                ((DisplayWidget) child).set_geometry (child_x - shortest_x, child_y - shortest_y , child_width, child_height);
                debug ("moving child %d on X & %d on Y\n", shortest_x, shortest_y);
            } else {
                debug ("too large");
            }
        }
    }

    static bool equals = false;
    private bool is_projected (int child_x, int child_length, int anchor_x, int anchor_length) {
        var numberline = new List<int> ();

        equals = false;
        CompareFunc<int> intcmp = (a, b) => {
            if (a == b) equals = true;
            return (int) (a > b) - (int) (a < b);
        };

        var child_x2 = child_x + child_length;
        var anchor_x2 = anchor_x + anchor_length;

        numberline.insert_sorted (child_x, intcmp);
        numberline.insert_sorted (child_x2, intcmp);
        numberline.insert_sorted (anchor_x, intcmp);
        numberline.insert_sorted (anchor_x2, intcmp);

        if (equals) return false;
        return !((numberline.index (child_x) - numberline.index (child_x2)).abs () == 1 && (numberline.index (anchor_x) - numberline.index (anchor_x2)).abs () == 1);
    }

    private bool is_x_smaller_absolute (int x, int y) {
        return x.abs () < y.abs ();
    }
}
