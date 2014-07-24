
public class DisplayPlug : Object
{
	Gtk.Box main_box;
	OutputList output_list;

	Gnome.RRScreen screen;
	Gnome.RRConfig current_config;
	unowned Gnome.RROutputInfo? selected_info = null;
	unowned Gnome.RROutput? selected_output = null;

	Gtk.Button apply_button;

	int enabled_monitors = 0;

	public DisplayPlug ()
	{
		main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
		main_box.margin = 12;

		try {
			screen = new Gnome.RRScreen (Gdk.Screen.get_default ());
			screen.changed.connect (screen_changed);
		} catch (Error e) {
			report_error (e.message);
		}

		output_list = new OutputList ();
		main_box.pack_start (output_list);

		var buttons = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
		var detect_displays = new Gtk.Button.with_label (_("Detect Displays"));
		apply_button = new Gtk.Button.with_label (_("Apply"));
		apply_button.sensitive = false;
		apply_button.clicked.connect (apply);
		buttons.layout_style = Gtk.ButtonBoxStyle.END;
		buttons.add (detect_displays);
		buttons.add (apply_button);

		main_box.pack_start (buttons, false);
	}

	void update_config ()
	{
		try {
			var existing_config = new Gnome.RRConfig.current (screen);

		// TODO check if clone or primary state changed too
			apply_button.sensitive = current_config.applicable (screen)
				&& !existing_config.equal (current_config);
		} catch (Error e) {
			report_error (e.message);
		}
	}

	void apply ()
	{
		apply_button.sensitive = false;

		current_config.sanitize ();
		current_config.ensure_primary ();

		try {
			current_config.apply_persistent (screen);
		} catch (Error e) {
			report_error (e.message);
		}

		screen_changed ();
	}

	void screen_changed ()
	{
		try {
			screen.refresh ();

			current_config = new Gnome.RRConfig.current (screen);
		} catch (Error e) {
			report_error (e.message);
		}

		enabled_monitors = 0;
		output_list.remove_all ();
		foreach (unowned Gnome.RROutputInfo output in current_config.get_outputs ()) {
			if (output.is_active ())
				enabled_monitors++;

			output_list.add_output (output);
		}

		output_list.select_path (new Gtk.TreePath.first ());
	}

	// TODO show an infobar
	void report_error (string message)
	{
		warning (message);
	}

	public Gtk.Widget get_widget ()
	{
		return main_box;
	}
}

/*
		primary_display = new Gtk.CheckButton ();
		primary_display.notify["active"].connect (() => {
			if (ui_update)
				return;

			// TODO do we need to take care that there's always a primary one selected?
			selected_info.set_primary (primary_display.active);

			update_config ();
		});
*/

void main (string[] args)
{
	Gtk.init (ref args);

	var p = new DisplayPlug ();
	var w = new Gtk.Window ();
	w.set_default_size (800, 400);
	w.add (p.get_widget ());
	w.show_all ();
	w.destroy.connect (Gtk.main_quit);

	Gtk.main ();
}


