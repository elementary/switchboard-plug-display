
public class DisplayPopover : Gtk.Popover {
    public signal void update_config ();

    unowned Gnome.RROutputInfo? info = null;
    unowned Gnome.RROutput? output = null;
    Gnome.RRConfig current_config;
    Gnome.RRScreen current_screen;

    Gtk.Switch use_display;
    Gtk.ComboBox resolution;
    Gtk.ComboBoxText rotation;
    Gtk.Grid grid;
    Gtk.Grid use_display_grid;

    Gtk.ListStore resolution_list;

    bool ui_update = false;

    public DisplayPopover (Gnome.RRScreen screen, Gnome.RROutputInfo output_info, Gnome.RRConfig config) {
        position = Gtk.PositionType.BOTTOM;

        current_screen = screen;
        current_config = config;
        info = output_info;
        output = screen.get_output_by_name (info.get_name ());

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

        grid = new Gtk.Grid ();
        grid.margin = 6;
        grid.row_spacing = 6;
        grid.column_spacing = 12;

        use_display = new Gtk.Switch ();
        use_display.margin_end = 12;
        use_display.halign = Gtk.Align.END;
        use_display.notify["active"].connect (() => {
            if (ui_update)
                return;

            int x, y, monitor_width, monitor_height;
            info.get_geometry (out x, out y, out monitor_width, out monitor_height);
            if (monitor_width == 0) {
                monitor_width = info.get_preferred_width ();
            }

            if (monitor_height == 0) {
                monitor_height = info.get_preferred_height ();
            }
            unowned Gnome.RRMode[] modes;
            unowned Gnome.RRMode current_mode = output.get_current_mode ();
            if (current_mode == null) {
                if (current_config.get_clone ())
                    modes = current_screen.list_clone_modes ();
                else
                    modes = output.list_modes ();
                foreach (unowned Gnome.RRMode mode in modes) {
                    if (current_mode == null) {
                        current_mode = mode;
                    }

                    if (current_mode.get_width () < mode.get_width ())
                        current_mode = mode;

                    if (mode.get_width () == monitor_width && mode.get_height () == monitor_height) {
                        current_mode = mode;
                        break;
                    }
                }
            }

            if (current_mode != null) {
                info.set_geometry (x, y, (int)current_mode.get_width (), (int)current_mode.get_height ());
                info.set_refresh_rate (current_mode.get_freq ());
            } else {
                info.set_geometry (x, y, (int)current_mode.get_width (), (int)current_mode.get_height ());
            }

            info.set_active (use_display.active);

            try {
                if (current_config.applicable (screen) == false) {
                    ui_update = true;
                    use_display.active = false;
                    info.set_active (false);
                    ui_update = false;
                }
            } catch (Error e) {
                ui_update = true;
                use_display.active = false;
                info.set_active (false);
                critical (e.message);
                ui_update = false;
            }

            update_config ();
            update_settings ();
        });

        var use_display_label = new Utils.RLabel.right (_("Use This Display"));
        use_display_label.hexpand = true;
        use_display.margin_start = 12;

        use_display_grid = new Gtk.Grid ();
        use_display_grid.margin_top = 6;
        use_display_grid.row_spacing = 6;
        use_display_grid.attach (use_display_label, 0, 0, 1, 1);
        use_display_grid.attach (use_display, 1, 0, 1, 1);
        use_display_grid.attach (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), 0, 1, 2, 1);

        box.pack_start (use_display_grid, false);
        box.pack_start (grid);

        var text_renderer = new Gtk.CellRendererText ();
        resolution = new Gtk.ComboBoxText ();
        resolution_list = new Gtk.ListStore (2, typeof (string), typeof (Gnome.RRMode));
        resolution = new Gtk.ComboBox.with_model (resolution_list);
        resolution.pack_start (text_renderer, true);
        resolution.add_attribute (text_renderer, "text", 0);
        resolution.expand = true;
        resolution.valign = Gtk.Align.CENTER;
        resolution.notify["active"].connect (() => {
            if (ui_update)
                return;

            Gtk.TreeIter iter;
            unowned Gnome.RRMode mode;
            int x, y;

            if (!resolution.get_active_iter (out iter))
                return;

            resolution_list.@get (iter, 1, out mode);

            var width = (int) mode.get_width ();
            var height = (int) mode.get_height ();

            if (config.get_clone ()) {
                foreach (unowned Gnome.RROutputInfo output in current_config.get_outputs ()) {
                    if (output.is_active ())
                        output.set_geometry (0, 0, width, height);
                }
            } else {
                info.get_geometry (out x, out y, null, null);
                info.set_geometry (x, y, width, height);
            }

            update_config ();
        });

        grid.attach (new Utils.RLabel.right (_("Resolution:")), 0, 2, 1, 1);
        grid.attach (resolution, 1, 2, 1, 1);

        rotation = new Gtk.ComboBoxText ();
        rotation.valign = Gtk.Align.CENTER;
        rotation.changed.connect (() => {
            if (ui_update)
                return;

            int rot = int.parse (rotation.active_id);
            info.set_rotation ((Gnome.RRRotation) rot);

            update_config ();
        });

        grid.attach (new Utils.RLabel.right (_("Rotation:")), 0, 4, 1, 1);
        grid.attach (rotation, 1, 4, 1, 1);
        add (box);
    }

    public void update_settings () {
        ui_update = true;

        var enabled_monitors = 0;
        bool is_multi_monitor = false;
        foreach (unowned Gnome.RROutputInfo output in current_config.get_outputs ()) {
            if (output.is_connected ()) {
                enabled_monitors++;
            }

            if (enabled_monitors > 1) {
                is_multi_monitor = true;
                break;
            }
        }

        use_display.active = info.is_active ();
        use_display_grid.no_show_all = !is_multi_monitor || current_config.get_clone ();
        use_display_grid.visible = is_multi_monitor || !current_config.get_clone ();
        grid.sensitive = info.is_active ();

        update_modes ();
        update_rotation ();

        ui_update = false;
    }

    void update_modes () {
        unowned Gnome.RRMode[] modes;

        if (current_config.get_clone ())
            modes = current_screen.list_clone_modes ();
        else
            modes = output.list_modes ();

        unowned Gnome.RRMode current_mode = output.get_current_mode ();
        int current_width = 0;
        int current_height = 0;
        
        if (current_mode != null) {
            resolution.active_id = current_mode.get_id ().to_string ();
            current_width = (int)current_mode.get_width ();
            current_height = (int)current_mode.get_height ();
        } else {
            resolution.active = 0;
        }

        foreach (unowned Gnome.RRMode mode in modes) {
            var mode_width = mode.get_width ();
            var mode_height = mode.get_height ();
            var aspect = Utils.make_aspect_string (mode_width, mode_height);

            string label;
            if (aspect != null)
                label = "%u × %u (%s)".printf (mode_width, mode_height, aspect);
            else
                label = "%u × %u".printf (mode_width, mode_height);

            Gtk.TreeIter iter;
            bool present = false;
            for (var valid = resolution_list.get_iter_first (out iter); valid;
                valid = resolution_list.iter_next (ref iter)) {

                string output_label;
                resolution_list.@get (iter, 0, out output_label);

                if (output_label == label) {
                    present = true;
                    break;
                }
            }

            if (present)
                continue;

            resolution_list.insert_with_values (out iter, -1, 0, label, 1, mode);

            if (mode_width == current_width && mode_height == current_height)
                resolution.set_active_iter (iter);
        }
    }

    void update_rotation () {
        rotation.remove_all ();

        var n_rotations = 0;

        Gnome.RRRotation[] rotations = {
            Gnome.RRRotation.ROTATION_0,
            Gnome.RRRotation.ROTATION_90,
            Gnome.RRRotation.ROTATION_270,
            Gnome.RRRotation.ROTATION_180
        };

        string[] desc = {
            _("Normal"),
            _("Counterclockwise"),
            _("Clockwise"),
            _("180 Degrees")
        };

#if HAS_GNOME312
        for (var i = 0; i < rotations.length; i++) {
            if (info.supports_rotation (rotations[i])) {
                rotation.append (((int) rotations[i]).to_string (), desc[i]);
                n_rotations++;
            }
        }
#else
        var current_rotation = info.get_rotation ();
        for (var i = 0; i < rotations.length; i++) {
            info.set_rotation (rotations[i]);
            try {
                if (current_config.applicable (current_screen)) {
                    rotation.append (((int) rotations[i]).to_string (), desc[i]);
                    n_rotations++;
                }
            } catch (Error e) {
                critical (e.message);
            }
        }

        info.set_rotation (current_rotation);
#endif

        rotation.sensitive = n_rotations > 0;
        rotation.active_id = ((int) info.get_rotation ()).to_string ();
    }
}