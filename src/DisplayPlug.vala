
public class DisplayPlug : Gtk.Application {
    Gtk.Box main_box;
    Gtk.Button apply_button;
    OutputList output_list;
    int enabled_monitors = 0;

    public DisplayPlug () {
        main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        main_box.margin = 12;

        output_list = new OutputList ();
        output_list.set_size_request (700, 350);

        var output_frame = new Gtk.Frame (null);
        output_frame.add (output_list);
        main_box.pack_start (output_frame);

        var buttons = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
        var detect_displays = new Gtk.Button.with_label (_("Detect Displays"));
        apply_button = new Gtk.Button.with_label (_("Apply"));
        apply_button.sensitive = false;
        apply_button.clicked.connect (() => {Configuration.get_default ().apply ();});
        buttons.layout_style = Gtk.ButtonBoxStyle.END;
        buttons.add (detect_displays);
        buttons.add (apply_button);

        main_box.pack_start (buttons, false);
        var config = Configuration.get_default ();
        config.report_error.connect (report_error);
        config.update_outputs.connect (update_outputs);
        config.apply_state_changed.connect ((can_apply) => {
            apply_button.sensitive = can_apply;
        });

        config.screen_changed ();
    }

    void update_outputs (Gnome.RRConfig current_config) {
        enabled_monitors = 0;
        output_list.remove_all ();
        foreach (unowned Gnome.RROutputInfo output in current_config.get_outputs ()) {
            if (output.is_connected ()) {
                if (output.is_active ())
                    enabled_monitors++;

                output_list.add_output (output);
            }
        }
    }

    // TODO show an infobar
    void report_error (string message) {
        warning (message);
    }

    public Gtk.Widget get_widget () {
        return main_box;
    }

    protected override void activate () {
        // Create the window of this application and show it
        Gtk.ApplicationWindow window = new Gtk.ApplicationWindow (this);
        window.set_default_size (800, 400);

        window.add (get_widget ());
        window.show_all ();
    }

    public static int main (string[] args) {
        GtkClutter.init (ref args);
        DisplayPlug app = new DisplayPlug ();
        return app.run (args);
    }
}
