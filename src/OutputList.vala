
public class OutputList : GtkClutter.Embed {
    const int PADDING = 48;
    public const string BLUE = "#4b91dd";
    public const string ORANGE = "#eb713f";
    public const string GREEN = "#408549";
    public const string PURPLE = "#a64067";
    public const string RED = "#ba393e";
    public const string GREY = "#d5d3d1";

    public bool clone_mode { get; set; default = false; }
    private float scale_xy { get; set; default = 0; }

    public OutputList () {
        size_allocate.connect (reposition);
    }

    public void add_output (Gnome.RROutputInfo output) {
        var monitor = new Monitor (output);
        var rgba = Gdk.RGBA ();
        rgba.alpha = 1;
        switch ((get_stage ().get_n_children () + 1)%6) {
            case 1:
                rgba.parse (BLUE);
                break;
            case 2:
                rgba.parse (ORANGE);
                break;
            case 3:
                rgba.parse (GREEN);
                break;
            case 4:
                rgba.parse (PURPLE);
                break;
            case 5:
                rgba.parse (RED);
                break;
            default:
                rgba.parse (GREY);
                break;
        }

        if (output.is_active () == false) {
            monitor.disable ();
        } else {
            monitor.set_rgba (rgba);
        }

        if (clone_mode == true && monitor.output.get_primary () == true) {
            monitor.set_main_clone ();
        }

        monitor.is_primary.connect (() => {
            foreach (var child in get_stage ().get_children ()) {
                unowned Monitor mon = (Monitor)child;
                if (mon != monitor) {
                    mon.unset_primary ();
                }
            }

            Configuration.get_default ().update_config ();
        });

        monitor.reposition.connect (() => {
            reposition ();
        });

        monitor.drag_action.drag_progress.connect (drag_progress);
        monitor.drag_action.drag_motion.connect ((actor, delta_x, delta_y) => {
            int monitor_x, monitor_y;
            monitor.output.get_geometry (out monitor_x, out monitor_y, null, null);
            int monitor_width = monitor.get_real_width ();
            int monitor_height = monitor.get_real_height ();
            int offset_x = (int)(delta_x/scale_xy);
            int offset_y = (int)(delta_y/scale_xy);
            monitor.output.set_geometry (monitor_x + offset_x, monitor_y + offset_y, monitor_width, monitor_height);
            Configuration.get_default ().update_config ();
        });

        monitor.drag_action.drag_end.connect ((actor, delta_x, delta_y, modifiers) => {
            reposition ();
        });

        get_stage ().add_child (monitor);

        reposition ();
    }

    public void reposition () {
        var left = int.MAX;
        var top = int.MAX;
        var right = int.MIN;
        var bottom = int.MIN;

        int x, y, width, height;

        foreach (var child in get_stage ().get_children ()) {
            unowned Monitor monitor = (Monitor) child;

            if (clone_mode == true) {
                if (monitor.output.get_primary () == false) {
                    monitor.hide ();
                    continue;
                } else {
                    x = 0;
                    y = 0;
                }
            } else {
                monitor.output.get_geometry (out x, out y, null, null);
            }

            width = monitor.get_real_width ();
            height = monitor.get_real_height ();
            left = int.min (x, left);
            top = int.min (y, top);
            right = int.max (x + width, right);
            bottom = int.max (y + height, bottom);
        }

        if (left != 0 || top != 0) {
            move_workspace (left, top);
            right -= left;
            bottom -= top;
            left = 0;
            top = 0;
        }

        var layout_width = right - left;
        var layout_height = bottom - top;
        var container_width = get_allocated_width ();
        var container_height = get_allocated_height ();
        var inner_width = container_width - PADDING * 2;
        var inner_height = container_height - PADDING * 2;

        scale_xy = (float) inner_height / layout_height;

        if (layout_width * scale_xy > inner_width)
            scale_xy = (float) inner_width / layout_width;

        var offset_x = (container_width - layout_width * scale_xy) / 2.0f;
        var offset_y = (container_height - layout_height * scale_xy) / 2.0f;

        foreach (var child in get_stage ().get_children ()) {
            unowned Monitor monitor = (Monitor) child;
            if (clone_mode == true && monitor.output.get_primary () == false) {
                continue;
            }

            monitor.update_position (scale_xy, offset_x, offset_y);
        }
    }

    public void remove_all () {
        get_stage ().destroy_all_children ();
    }

    private void move_workspace (int left, int top) {
        foreach (var child in get_stage ().get_children ()) {
            unowned Monitor monitor = (Monitor) child;
            int x, y;
            monitor.output.get_geometry (out x, out y, null, null);
            int width = monitor.get_real_width ();
            int height = monitor.get_real_height ();
            monitor.output.set_geometry (x - left, y - top, width, height);
        }
    }

    private bool drag_progress (Clutter.Actor actor, float delta_x, float delta_y) {
        if (clone_mode == true) {
            return false;
        }

        unowned Monitor monitor = (Monitor) actor;
        int src_x , src_y, src_width, src_height;
        monitor.output.get_geometry (out src_x, out src_y, null, null);
        src_width = monitor.get_real_width ();
        src_height = monitor.get_real_height ();
        int offset_x = (int)Math.floorf (delta_x/scale_xy);
        int offset_y = (int)Math.floorf (delta_y/scale_xy);
        var src_rect = Clutter.Rect.alloc ();
        src_rect.init (src_x + offset_x, src_y + offset_y, src_width, src_height);

        foreach (var child in get_stage ().get_children ()) {
            unowned Monitor mon = (Monitor) child;
            if (mon == monitor)
                continue;

            int test_x , test_y, test_width, test_height;
            mon.output.get_geometry (out test_x, out test_y, null, null);
            test_width = mon.get_real_width ();
            test_height = mon.get_real_height ();
            var test_rect = Clutter.Rect.alloc ();
            test_rect.init (test_x, test_y, test_width, test_height);

            // If it's not possible to move, check for the blocking side.
            if (src_rect.intersection (test_rect, null) == true) {
                src_rect.init (src_x + offset_x, src_y, src_width, src_height);
                if (src_rect.intersection (test_rect, null) == false) {
                    // Try to fill the gap between them
                    int min_y = calculate_gap (src_y, src_height, test_y, test_height);
                    monitor.drag_action.drag_motion (actor, delta_x, min_y*scale_xy);
                    return false;
                }

                src_rect.init (src_x, src_y + offset_y, src_width, src_height);
                if (src_rect.intersection (test_rect, null) == false) {
                    // Try to fill the gap between them
                    int min_x = calculate_gap (src_x, src_width, test_x, test_width);
                    monitor.drag_action.drag_motion (actor, min_x*scale_xy, delta_y);
                    return false;
                }

                return false;
            }
        }

        return true;
    }

    private int calculate_gap (int src_origin, int src_size, int test_origin, int test_size) {
        if (src_origin + src_size < test_origin)
            return test_origin - (src_origin + src_size);
        else if (test_origin + test_size < src_origin)
            return test_origin + test_size - src_origin;
        return 0;
    }
}