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
        current_ratio = 0.75 * double.min ((double) (get_allocated_width () - 24) / (double) added_width, (double) (get_allocated_height () - 24) / (double) added_height);
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
        display_widget.move_display.connect ((diff_x, diff_y, align_widgets) => move_display (display_widget, diff_x, diff_y, align_widgets));
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
            snap_edges (display_widget);
            check_intersects (display_widget);
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

    private void move_display (DisplayWidget display_widget, double diff_x, double diff_y, bool align_widgets) {
        reorder_overlay (display_widget, -1);
        display_widget.delta_x = (int) (diff_x / current_ratio);
        display_widget.delta_y = (int) (diff_y / current_ratio);
        if (align_widgets) {
            align_edges (display_widget);
        }
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

                for (var u = 0; u < 2; u++) {
                    for (var i = 0; i < 3; i++) {
                        for (var j = 0; j < 3; j++) {
                            var distance = (anchor [i + 3 * u] - source_anchors [j + 3 * u] - diff [u]).abs ();
                            if (threshold > distance) {
                                // dont snap to opposite edge 
                                //  if ((i - j).abs () == 2) { 
                                //      continue;
                                //  }

                                // snap to closest edge
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
            if (display_widget == other_display_widget) {
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
    Gee.HashSet<DisplayWidget> checked_display_widgets = new Gee.HashSet<DisplayWidget> ();
    public void check_intersects (DisplayWidget source_display_widget, int level = 0) {
        if (level > 20) {
            debug ("MAX level of recursion! Could not fix intersects!");
            return;
        }

        checked_display_widgets.add (source_display_widget);
        
        int orig_x, orig_y, src_x, src_y, src_width, src_height;
        source_display_widget.get_geometry (out orig_x, out orig_y, out src_width, out src_height);
        src_x = orig_x + source_display_widget.delta_x;
        src_y = orig_y + source_display_widget.delta_y;
        Gdk.Rectangle src_rect = {src_x, src_y, src_width, src_height};
        Gdk.Rectangle intersection;

        foreach (var child in get_children ()) {
            if (child is DisplayWidget) {
                var display_widget = (DisplayWidget) child;
                if (!checked_display_widgets.contains (display_widget)) {
                    int x, y, width, height;
                    display_widget.get_geometry (out x, out y, out width, out height);
                    Gdk.Rectangle test_rect = {x + display_widget.delta_x, y + display_widget.delta_y, width, height};
                    if (src_rect.intersect (test_rect, out intersection)) {
                        var distance_x = 0;
                        var distance_y = 0;
                        if ((intersection.width < intersection.height || intersection.height == src_height) && !(intersection.width == src_width)) {
                            distance_x = intersection.x <= x ? -intersection.width : intersection.width;
                        } else {
                            distance_y = intersection.y <= y ? -intersection.height : intersection.height;
                        }

                        display_widget.set_geometry (x - distance_x, y - distance_y, width, height);
                        display_widget.queue_resize_no_redraw ();
                        check_intersects (display_widget, level + 1);
                    }
                }
            }
        }

        if (level == 0) {
            checked_display_widgets.clear ();
        }
    }

    public void snap_edges (DisplayWidget display_widget) {
        if (scanning) {
            return;
        }

        var anchors = new List<DisplayWidget>();
        get_children ().foreach ((child) => {
            if (!(child is DisplayWidget) || display_widget.equals ((DisplayWidget) child)) return;
            anchors.append ((DisplayWidget) child);
        });

        snap_widget (display_widget, anchors);
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

    private void snap_widget (Display.DisplayWidget child, List<Display.DisplayWidget> anchors) {
        if (anchors.length () == 0) {
            return;
        }

        int child_x, child_y, child_width, child_height;
        child.get_geometry (out child_x, out child_y, out child_width, out child_height);
        child_x += child.delta_x; 
        child_y += child.delta_y; 

        int distance = int.MAX;
        int test_distance;

        // Try to snap horizontally or vertically
        // -1: could not snap to edge, 0: snap left , 1: snap right, 2: snap top, 3: snap bottom
        var snap_mode = -1; 
        Gdk.Rectangle anchor_rect, test_rect, intersection;

        foreach (var anchor in anchors) {
            int anchor_x, anchor_y, anchor_width, anchor_height;
            anchor.get_geometry (out anchor_x, out anchor_y, out anchor_width, out anchor_height);
            anchor_rect = {anchor_x, anchor_y, anchor_width, anchor_height};

            // check if possible to snap left
            test_rect = {0, child_y, child_x, child_height};
            if (test_rect.intersect (anchor_rect, out intersection)) {
                test_distance = intersection.x + intersection.width - child_x;
                if (test_distance.abs () < distance.abs ()) {
                    distance = test_distance;
                    snap_mode = 0;
                }
            }

            // check if possible to snap right
            test_rect = {child_x + child_width, child_y, int.MAX - (child_x + child_width + 1), child_height};
            if (test_rect.intersect (anchor_rect, out intersection)) {
                test_distance = intersection.x - 1 - (child_x + child_width - 1);
                if (test_distance.abs () < distance.abs ()) {
                    distance = test_distance;
                    snap_mode = 1;
                }
            }

            // check if possible to snap top
            test_rect = {child_x, 0, child_width, child_y};
            if (test_rect.intersect (anchor_rect, out intersection)) {
                test_distance = intersection.y + intersection.height - child_y;
                if (test_distance.abs () < distance.abs ()) {
                    distance = test_distance;
                    snap_mode = 2;
                }
            }

            // check if possible to snap bottom
            test_rect = {child_x, child_y + child_height, child_width, int.MAX - (child_y + child_height + 1)};
            if (test_rect.intersect (anchor_rect, out intersection)) {
                test_distance = intersection.y - 1 - (child_y + child_height - 1);
                if (test_distance.abs () < distance.abs ()) {
                    distance = test_distance;
                    snap_mode = 3;
                }
            }

        }

        var distance_x = 0;
        var distance_y = 0;

        switch (snap_mode) {
            case -1:
                debug ("Snap to corner!");
                break;
            case 0:
                debug ("Snap to Left!");
                distance_x = distance;
                break;
            case 1:
                debug ("Snap to Right!");
                distance_x = distance;
                break;
            case 2:
                debug ("Snap to Top!");
                distance_y = distance;
                break;
            case 3:
                debug ("Snap to Bottom!");
                distance_y = distance;
                break;
        }

        if (snap_mode != -1) {
            if (child.holding) {
                child.delta_x += distance_x;
                child.delta_y += distance_y;
            } else {
                child.set_geometry (child_x + distance_x, child_y + distance_y, child_width, child_height);
            }

            return;
        }

        // Could not snap widget to any edge
        // --> snap widget to corner
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

        var margin = int.min (child_width, child_height) / 20;
        if (child.holding) {
            child.delta_x += distance_x + multiplier_x * margin;
            child.delta_y += distance_y + multiplier_y * margin;
        } else {
            var new_x = child_x + child.delta_x + distance_x + multiplier_x * margin;
            var new_y = child_y + child.delta_y + distance_y + multiplier_y * margin;
            child.set_geometry (new_x, new_y, child_width, child_height);
        }
    }
}
