
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
    Gnome.RRScreen screen;
    Gnome.RRConfig current_config;

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
            apply_state_changed (current_config.applicable (screen)
                && !existing_config.equal (current_config));
        } catch (Error e) {
            report_error (e.message);
        }

        update_outputs (current_config);
    }

    public DisplayPopover get_popover (Gnome.RROutputInfo output) {
        var display_popover = new DisplayPopover (screen, output, current_config);
        display_popover.update_config.connect (update_config);
        return display_popover;
    }

    public void apply () {
        var timestamp = Gtk.get_current_event_time ();

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

    public void screen_changed () {
        try {
            screen.refresh ();
            current_config = new Gnome.RRConfig.current (screen);
        } catch (Error e) {
            report_error (e.message);
        }

        update_outputs (current_config);
    }
}