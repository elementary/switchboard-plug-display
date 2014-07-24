
public class OutputList : Gtk.IconView
{
	const int MONITOR_MAX_HEIGHT = 150;

	public signal void select_output (Gnome.RROutputInfo? output);

	Gtk.ListStore list;
	double highest;

	public OutputList ()
	{
		activate_on_single_click = true;
		model = list = new Gtk.ListStore (2, typeof (Gnome.RROutputInfo), typeof (Gdk.Pixbuf));
		set_reorderable (true);
		set_pixbuf_column (1);

		cell_area.get_cells ().data.xalign = 0.5f;
		cell_area.get_cells ().data.yalign = 0.5f;

		selection_changed.connect_after (() => {
			Gtk.TreeIter iter;
			unowned Gnome.RROutputInfo info;

			var selected = get_selected_items ();
			if (selected.length () < 1) {
				select_output (null);
				return;
			}
			var path = selected.data;

			list.get_iter (out iter, path);
			list.@get (iter, 0, out info);

			select_output (info);
		});
	}

	public void add_output (Gnome.RROutputInfo output)
	{
		Gtk.TreeIter iter, new_iter;
		int x1, x2, height;
		Gnome.RROutputInfo other_output;

		output.get_geometry (out x1, null, null, out height);

		highest = double.max (highest, height);

		if (list.iter_n_children (null) > 0) {
			list.get_iter_first (out iter);

			do {
				list.@get (iter, 0, out other_output);
				other_output.get_geometry (out x2, null, null, null);

				if (x1 < x2)
					break;
			} while (list.iter_next (ref iter));

			list.insert_before (out new_iter, iter);
		} else
			list.append (out new_iter);

		list.@set (new_iter, 0, output, 1, get_monitor_pixbuf (output));
	}

	public void remove_all ()
	{
		bool valid;
		Gtk.TreeIter iter;

		for (valid = list.get_iter_first (out iter); valid; valid = list.remove (iter));
	}

	Gdk.Pixbuf get_monitor_pixbuf (Gnome.RROutputInfo output)
	{
		int monitor_width, monitor_height;
		output.get_geometry (null, null, out monitor_width, out monitor_height);

		var scale_factor = MONITOR_MAX_HEIGHT / highest;
		var width = (int) Math.floor (monitor_width * scale_factor);
		var height = (int) Math.floor (monitor_height * scale_factor);

		var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, width, height);
		var cr = new Cairo.Context (surface);

		cr.rectangle (0, 0, width, height);
		cr.set_source_rgb (1, 0, 0);
		cr.fill ();

		return Gdk.pixbuf_get_from_surface (surface, 0, 0, width, height);
	}
}

