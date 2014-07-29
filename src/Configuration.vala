
public class Configuration : GLib.Object {
    private static Configuration? configuration = null;

    public static Configuration get_default () {
        if (configuration == null)
            configuration = new Configuration ();
        return configuration;
    }

    public signal void report_error (string error);
    public signal void apply_state_changed (bool can_apply);
    public signal void update_outputs (Gnome.RRConfig current_config);

    public Gnome.RRScreen screen { get; private set; }
    public Gnome.RRConfig current_config { get; private set; }

    SettingsDaemon? settings_daemon = null;
    private Configuration () {
        try {
            screen = new Gnome.RRScreen (Gdk.Screen.get_default ());
            screen.changed.connect (screen_changed);
        } catch (Error e) {
            report_error (e.message);
        }

        try {
            settings_daemon = get_settings_daemon ();
        } catch (Error e) {
            report_error (_("Settings cannot be applied: %s").printf (e.message));
        }
    }

    public void update_config () {
        try {
            var existing_config = new Gnome.RRConfig.current (screen);

            // TODO check if clone or primary state changed too
            bool applicable = current_config.applicable (screen);
            bool changed = !existing_config.equal (current_config);
            bool clone_changed = existing_config.get_clone () != current_config.get_clone ();
            foreach (var existing_output in existing_config.get_outputs ()) {
                unowned string name = existing_output.get_name ();
                foreach (var current_output in current_config.get_outputs ()) {
                    if (name == current_output.get_name ()) {
                        if (existing_output.get_primary () != current_output.get_primary ()) {
                            changed = true;
                            break;
                        }
                    }
                }
            }

            apply_state_changed (applicable && (changed || clone_changed));

            if (clone_changed && !current_config.get_clone ())
                lay_out_outputs_horizontally ();

        } catch (Error e) {
            critical (e.message);
        }
    }

    public DisplayPopover get_popover (Gnome.RROutputInfo output) {
        var display_popover = new DisplayPopover (screen, output, current_config);
        display_popover.update_config.connect (update_config);
        return display_popover;
    }

    public void apply () {
        apply_state_changed (false);
        current_config.sanitize ();
        current_config.ensure_primary ();

#if !HAS_GNOME312
        try {
            var other_screen = new Gnome.RRScreen (Gdk.Screen.get_default ());
            var other_config = new Gnome.RRConfig.current (other_screen);
            other_config.ensure_primary ();
            other_config.save ();
        } catch (Error e) {}
#endif

        try {
#if HAS_GNOME312
            current_config.apply_persistent (screen);
#else
            current_config.save ();
#endif
        } catch (Error e) {
            report_error (e.message);
            return;
        }

        var window = ((Gtk.Application)Application.get_default ()).active_window.get_window ();
        if (window is Gdk.X11.Window) {
            var xid = ((Gdk.X11.Window)window).get_xid ();
            var timestamp = Gtk.get_current_event_time ();
            try {
                settings_daemon.apply_configuration (xid, timestamp);
            } catch (Error e) {
                critical (e.message);
            }
        } else {
            critical ("Only X11 is supported.");
        }

        screen_changed ();
    }

    public bool active_clone_mode () {
        unowned Gnome.RRMode highest_mode = null;
        foreach (unowned Gnome.RRMode mode in screen.list_clone_modes ()) {
            if (highest_mode == null) {
                highest_mode = mode;
            } else if (mode.get_width () > highest_mode.get_width ()) {
                highest_mode = mode;
            }
        }

        if (highest_mode == null)
            return false;

        foreach (unowned Gnome.RROutputInfo output in current_config.get_outputs ()) {
            if (output.is_active ())
                output.set_geometry (0, 0, (int)highest_mode.get_width (), (int)highest_mode.get_height ());
        }

        current_config.set_clone (true);

        update_outputs (current_config);
        return true;
    }

    public void screen_changed () {
        try {
            screen.refresh ();
            current_config = new Gnome.RRConfig.current (screen);
        } catch (Error e) {
            report_error (e.message);
        }

        update_outputs (current_config);
    }

    // ported from GCC panel
    public void lay_out_outputs_horizontally () {
        int width, height, x = 0;
        unowned Gnome.RROutputInfo[] outputs = current_config.get_outputs ();

        foreach (unowned Gnome.RROutputInfo output in outputs) {
            if (output.is_connected () && output.is_active ()) {
                output.get_geometry (null, null, out width, out height);
                output.set_geometry (x, 0, width, height);

                x += width;
            }
        }

        foreach (unowned Gnome.RROutputInfo output in outputs) {
            if (!(output.is_connected () && output.is_active ())) {
                output.get_geometry (null, null, out width, out height);
                output.set_geometry (x, 0, width, height);

                x += width;
            }
        }

        update_outputs (current_config);
    }
}