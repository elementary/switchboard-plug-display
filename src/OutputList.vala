
public class OutputList : GtkClutter.Embed {
    const int PADDING = 48;
    public const string BLUE = "#4b91dd";
    public const string ORANGE = "#eb713f";
    public const string GREEN = "#408549";
    public const string PURPLE = "#a64067";
    public const string RED = "#ba393e";
    public const string GREY = "#d5d3d1";

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

        get_stage ().add_child (monitor);

        reposition ();
    }

    public void reposition () {
        var left = int.MAX;
        var right = 0;
        var top = int.MAX;
        var bottom = 0;

        int x, y, width, height;

        foreach (var child in get_stage ().get_children ()) {
            unowned Monitor monitor = (Monitor) child;

            monitor.output.get_geometry (out x, out y, out width, out height);
            if (width == 0) {
                width = monitor.output.get_preferred_width ();
            }

            if (height == 0) {
                height = monitor.output.get_preferred_height ();
            }

            var rotation = monitor.output.get_rotation ();
            switch (rotation) {
                case Gnome.RRRotation.ROTATION_90:
                case Gnome.RRRotation.ROTATION_270:
                    var tmp = width;
                    width = height;
                    height = tmp;
                    break;
                default:
                    break;
            }
            if (x < left)
                left = x;
            if (y < top)
                top = y;
            if (x + width > right)
                right = x + width;
            if (y + height > bottom)
                bottom = y + height;
        }

        var layout_width = right - left;
        var layout_height = bottom - top;
        var container_width = get_allocated_width ();
        var container_height = get_allocated_height ();
        var inner_width = container_width - PADDING * 2;
        var inner_height = container_height - PADDING * 2;

        var scale_factor = (float) inner_height / layout_height;

        if (layout_width * scale_factor > inner_width)
            scale_factor = (float) inner_width / layout_width;

        var offset_x = (container_width - layout_width * scale_factor) / 2.0f;
        var offset_y = (container_height - layout_height * scale_factor) / 2.0f;

        foreach (var child in get_stage ().get_children ()) {
            ((Monitor) child).update_position (scale_factor, offset_x, offset_y);
        }
    }

    public void remove_all () {
        get_stage ().destroy_all_children ();
    }
}