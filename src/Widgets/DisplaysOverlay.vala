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
            allocation.x = default_x_margin + (int)((x +  display_widget.delta_x) * current_ratio);
            allocation.y = default_y_margin + (int)((y +  display_widget.delta_y) * current_ratio);
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
        current_ratio = 0.75 * double.min ((double)(get_allocated_width () -24) / (double) added_width, (double)(get_allocated_height ()-24) / (double) added_height);
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
        display_widget.check_position.connect (() => check_intersects (display_widget));
        display_widget.check_constraints.connect((diff_x, diff_y) => check_constraints (display_widget, diff_x, diff_y));
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

        display_widget.move_display.connect ((delta_x, delta_y) => {
            if (delta_x == 0 && delta_y == 0) {
                return;
            }

            int x, y, width, height;
            display_widget.get_geometry (out x, out y, out width, out height);
            display_widget.set_geometry (delta_x + x, delta_y + y, width, height);
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

    private void check_constraints (DisplayWidget display_widget, double diff_x, double diff_y) {
        display_widget.delta_x = (int) (diff_x / current_ratio);
        display_widget.delta_y = (int) (diff_y / current_ratio);
        check_intersects (display_widget);
        align_edges (display_widget);
        snap_edges (display_widget);
        if (check_for_gaps (display_widget)) {
            display_widget.last_valid_delta_x = display_widget.delta_x;
            display_widget.last_valid_delta_y = display_widget.delta_y;
        }
        else {
            display_widget.delta_x = display_widget.last_valid_delta_x;
            display_widget.delta_y = display_widget.last_valid_delta_y;
        }
        display_widget.queue_resize_no_redraw ();
    }

    private void align_edges (DisplayWidget source_display_widget) {
        bool[2] aligned = { false, false };
        int[2] delta_aligned = { int.MAX, int.MAX };
        int[2] diff = { source_display_widget.delta_x, source_display_widget.delta_y };

        var anchor = new int[6];
        var source_anchors = new int[6];

        int sdw_x, sdw_y, sdw_width, sdw_height; 
        source_display_widget.get_geometry (out sdw_x, out sdw_y, out sdw_width, out sdw_height);
        source_anchors [0] = sdw_x;
        source_anchors [1] = sdw_x + sdw_width / 2 - 1;
        source_anchors [2] = sdw_x + sdw_width - 1; 
        source_anchors [3] = sdw_y;
        source_anchors [4] = sdw_y + sdw_height / 2 - 1;
        source_anchors [5] = sdw_y + sdw_height - 1;

        var threshold = int.min (sdw_width / 10, sdw_height / 10);

        foreach (var child in get_children ()) {
            if (child is DisplayWidget && child != source_display_widget) {
                var display_widget = (DisplayWidget) child;

                int x, y, width, height; 
                display_widget.get_geometry (out x, out y, out width, out height);
                anchor [0] = x;
                anchor [1] = x + width / 2 - 1;
                anchor [2] = x + width - 1;
                anchor [3] = y;
                anchor [4] = y + height / 2 - 1;
                anchor [5] = y + height - 1;

                var align_diagonal = false;
                var align_diagonal_distance = 0;
                for (var u = 0; u < 2; u++) {
                    for (var i = 0; i < 3; i++) {
                        for (var j = 0; j < 3; j++) {
                            var distance = (anchor [i + 3 * u] - source_anchors [j + 3 * u] - diff [u]).abs ();
                            if (threshold > distance) {
                                if ((i - j).abs () == 2) {
                                    continue;
                                }
                                var test_delta = anchor [i + 3 * u] - source_anchors [j + 3 * u];
                                if (test_delta.abs () < delta_aligned [u].abs ()) {
                                    delta_aligned [u] = test_delta;
                                    if (i == 0 && j != i) {
                                        delta_aligned [u] -= 1;
                                    } else if (j == 0 && i != j) {
                                        delta_aligned [u] += 1;
                                    }

                                    aligned [u] = true;
                                }
                            }
                        }
                    }
                }
            }
        }
        
        if (aligned [0]) {
            source_display_widget.delta_x = delta_aligned [0];
        }
        if (aligned [1]) {
            source_display_widget.delta_y = delta_aligned [1];
        }
    }

    private bool check_for_gaps (DisplayWidget source_display_widget) {
        var other_display_widgets = new List<DisplayWidget>();
        foreach (var child in get_children ()) {
            if (child is DisplayWidget) other_display_widgets.append ((DisplayWidget) child);
        } 
        var delta_x = source_display_widget.delta_x;
        var delta_y = source_display_widget.delta_y;

        var i = -1;
        foreach (var dw_1 in other_display_widgets) {
            i++;
            int x_1, y_1, width_1, height_1;
            dw_1.get_geometry (out x_1, out y_1, out width_1, out height_1);

            if (dw_1 == source_display_widget) {
                x_1 += delta_x;
                y_1 += delta_y;
            }
            Gdk.Rectangle rect_1 = {x_1 - 1, y_1 - 1, width_1 + 2, height_1 + 2};
            //  debug ("MONITOR %d: left %d top %d right %d bottom %d", i, left_1, top_1, right_1, bottom_1);

            bool no_gaps = false;
            var j = -1;
            foreach (var dw_2 in other_display_widgets) {
                j ++;
                if (dw_1 == dw_2) continue;
                int x_2, y_2, width_2, height_2;
                dw_2.get_geometry (out x_2, out y_2, out width_2, out height_2);

                if (dw_2 == source_display_widget) {
                    x_2 += delta_x;
                    y_2 += delta_y;
                }
                Gdk.Rectangle rect_2 = {x_2, y_2, width_2, height_2};
                Gdk.Rectangle intersection;
                var con = rect_1.intersect (rect_2, out intersection);
                var con2 = intersection.height != 1 || intersection.width != 1;
                no_gaps = con && con2;
                if (no_gaps) {
                    break;
                }
            }

            if (!no_gaps) {
                debug ("found gaps");
                return false;
            }
        }
        debug ("no gaps");
        return true;
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
        src_x = orig_x + source_display_widget.delta_x;
        src_y = orig_y + source_display_widget.delta_y;
        Gdk.Rectangle src_rect = {src_x, src_y, src_width, src_height};
        foreach (var child in get_children ()) {
            if (child is DisplayWidget) {
                var display_widget = (DisplayWidget) child;
                if (display_widget == source_display_widget) {
                    continue;
                }

                int x, y, width, height;
                display_widget.get_geometry (out x, out y, out width, out height);
                Gdk.Rectangle test_rect = {x, y, width, height};
                Gdk.Rectangle intersection;
                if (src_rect.intersect (test_rect, out intersection)) {
                    if (intersection.height == src_height) {
                        // on the left side
                        if (intersection.x <= x) {
                            source_display_widget.delta_x =  x - (orig_x + src_width);
                        // on the right side
                        } else {
                            source_display_widget.delta_x = x - orig_x + width;
                        }
                    } else if (intersection.width == src_width) {
                        // on the bottom side
                        if (intersection.y <= y) {
                            source_display_widget.delta_y = y - (orig_y + src_height);
                        } else {
                        // on the upper side
                            source_display_widget.delta_y = y - orig_y + height;
                        }
                    } else {
                        if (intersection.width < intersection.height) {
                            // on the left side
                            if (intersection.x <= x) {
                                source_display_widget.delta_x = x - (orig_x + src_width);
                            // on the right side
                            } else {
                                source_display_widget.delta_x = x - orig_x + width;
                            }
                        } else {
                            // on the bottom side
                            if (intersection.y <= y) {
                                source_display_widget.delta_y = y - (orig_y + src_height);
                            } else {
                            // on the upper side
                                source_display_widget.delta_y = y - orig_y + height;
                            }
                        }
                    }
                    check_intersects (source_display_widget); // start recursion
                }
            }
        }

        source_display_widget.queue_resize_no_redraw ();
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
    *   If the widget cannot be snaped to an edge it is snaped diagonally                    *
    *   to the nearest corner.                                                               *
    ******************************************************************************************/

    private void snap_edges (Display.DisplayWidget child) {
        var anchors = new List<DisplayWidget>();
        get_children ().foreach ((c) => {
            if (!(c is DisplayWidget) || child.equals ((DisplayWidget)c)) return;
            anchors.append ((DisplayWidget) c);
        });

        if (anchors.length () == 0) return;
        int child_x, child_y, child_width, child_height;
        child.get_geometry (out child_x, out child_y, out child_width, out child_height);
        child_x += child.delta_x; 
        child_y += child.delta_y; 

        int distance = int.MAX;
        int test_distance;
        var snap_mode = -1; // -1: could not snap to edge, 0: snap , 1: vertical snap
        Gdk.Rectangle anchor_rect, test_rect, intersection;

        // Try to snap horizontally or vertically
        foreach (var anchor in anchors) {
            int anchor_x, anchor_y, anchor_width, anchor_height;
            anchor.get_geometry (out anchor_x, out anchor_y, out anchor_width, out anchor_height);
            anchor_rect = {anchor_x, anchor_y, anchor_width, anchor_height};

            // check if can possible to snap left
            test_rect = {0, child_y, child_x, child_height};
            if (test_rect.intersect (anchor_rect, out intersection)) {
                test_distance = ((intersection.x + intersection.width) - child_x).abs ();
                if (test_distance < distance) {
                    distance = test_distance;
                    snap_mode = 0;
                }
            }
            // check if can possible to snap right
            test_rect = {child_x + child_width, child_y, int.MAX - (child_x + child_width + 1), child_height};
            if (test_rect.intersect (anchor_rect, out intersection)) {
                test_distance = ((intersection.x - 1) - (child_x + child_width - 1)).abs ();
                if (test_distance < distance) {
                    distance = test_distance;
                    snap_mode = 1;
                }
            }

            // check if can possible to snap top
            test_rect = {child_x, 0, child_width, child_y};
            if (test_rect.intersect (anchor_rect, out intersection)) {
                test_distance = ((intersection.y + intersection.height) - child_y).abs ();
                if (test_distance < distance) {
                    distance = test_distance;
                    snap_mode = 2;
                }
            }
            // check if can possible to snap bottom
            test_rect = {child_x, child_y + child_height, child_width, int.MAX - (child_y + child_height + 1)};
            if (test_rect.intersect (anchor_rect, out intersection)) {
                test_distance = ((intersection.y - 1) - (child_y + child_height - 1)).abs ();
                if (test_distance < distance) {
                    distance = test_distance;
                    snap_mode = 3;
                }
            }

        }

        switch (snap_mode) {
            case 0:
                debug ("snap to left;");
                child.delta_x -= distance; 
                return;
            case 1:
                debug ("snap to right;");
                child.delta_x += distance; 
                return;
            case 2:
                debug ("snap to top;");
                child.delta_y -= distance; 
                return;
            case 3:
                debug ("snap to bottom;");
                child.delta_y += distance; 
                return;
        }

        debug ("snap to corner!");

        // widget counld not snap to any edge -> snap to corner
        var distance_x = 0;
        var distance_y = 0;
        distance = int.MAX;

        int[4] child_points = {child_x, child_x + child_width, child_y, child_y + child_height};
        int[4] anchor_points;
        int i_snapped = 0;
        int j_snapped = 0;

        foreach (var anchor in anchors) {
            int anchor_x, anchor_y, anchor_width, anchor_height;
            anchor.get_geometry (out anchor_x, out anchor_y, out anchor_width, out anchor_height);
            anchor_points = {anchor_x, anchor_x + anchor_width, anchor_y, anchor_y + anchor_height};

            for (var i = 0; i < 2; i++) {
                for (var j = 0; j < 2; j++) {
                    var diff_x = anchor_points [i] - child_points [1 - i];
                    var diff_y = anchor_points [2 + j] - child_points [3 - j];
                    test_distance = (int) Math.sqrt (Math.pow (diff_x, 2) + Math.pow (diff_y, 2));
                    if (test_distance < distance) {
                        distance = test_distance;
                        distance_x = diff_x;
                        distance_y = diff_y;
                        i_snapped = i;
                        j_snapped = j;
                    }
                }
            }
        }
        int multiplier_x = 0;
        int multiplier_y = 0;
        if (distance_x.abs () >= distance_y.abs ()) {
            multiplier_y = j_snapped == 0 ? 1 : -1;
        } else {
            multiplier_x = i_snapped == 0 ? 1 : -1;
        }

        var margin = 1; // int.min (child_width, child_height) / 10;
        child.delta_x += distance_x + multiplier_x * margin;
        child.delta_y += distance_y + multiplier_y * margin;
    }
}
