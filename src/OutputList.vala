
public class OutputList : GtkClutter.Embed
{
	class Monitor : Clutter.Actor
	{
		const int MARGIN = 6;

		public signal void show_settings (Gnome.RROutputInfo output, Gdk.Rectangle position);

		public unowned Gnome.RROutputInfo output { get; construct; }

		public Monitor (Gnome.RROutputInfo output)
		{
			Object (output: output);

			var align = new Clutter.BinLayout ();
			layout_manager = align;

			var primary = new GtkClutter.Texture ();
			primary.margin_left = primary.margin_top = MARGIN;
			primary.set_from_pixbuf (Gtk.IconTheme.get_default ()
				.lookup_icon ("gtk-about-symbolic", 16, 0).load_symbolic ({ 0, 0, 0, 1 }));

			var settings = new GtkClutter.Texture ();
			settings.reactive = true;
			settings.button_release_event.connect (() => {
				float x, y;
				settings.get_transformed_position (out x, out y);

				show_settings (output, { (int) x, (int) y, (int) width, (int) height });

				return false;
			});
			settings.margin_right = settings.margin_top = MARGIN;
			settings.set_from_pixbuf (Gtk.IconTheme.get_default ()
				.lookup_icon ("document-properties-symbolic", 16, 0).load_symbolic ({ 1, 1, 1, 1 }));

			var label = new Clutter.Text.with_text (null, output.get_display_name ());
			label.color = { 255, 255, 255, 255 };

			var canvas = new Clutter.Canvas ();
			canvas.draw.connect (draw_background);
			notify["allocation"].connect (() => {
				canvas.set_size ((int) width, (int) height);
			});

			content = canvas;

			add_child (primary);
			add_child (settings);
			add_child (label);

			align.set_alignment (settings, Clutter.BinAlignment.END, Clutter.BinAlignment.START);
			align.set_alignment (label, Clutter.BinAlignment.CENTER, Clutter.BinAlignment.CENTER);
		}

		public void update_position (float scale_factor, float offset_x, float offset_y)
		{
			int monitor_x, monitor_y, monitor_width, monitor_height;
			output.get_geometry (out monitor_x, out monitor_y, out monitor_width, out monitor_height);

			set_position (Math.floorf (offset_x + monitor_x * scale_factor),
			              Math.floorf (offset_y + monitor_y * scale_factor));

			set_size (Math.floorf (monitor_width * scale_factor),
			          Math.floorf (monitor_height * scale_factor));
		}

		bool draw_background (Cairo.Context cr)
		{
			// TODO draw shadow, inner highlight and use correct color
			cr.rectangle (0, 0, (int) width, (int) height);
			cr.set_source_rgb (0.2, 0.2, 0.2);
			cr.fill ();

			return false;
		}
	}

	const int PADDING = 48;

	public signal void show_settings (Gnome.RROutputInfo output, Gdk.Rectangle position);

	public OutputList ()
	{
		size_allocate.connect (reposition);
	}

	public void add_output (Gnome.RROutputInfo output)
	{
		var monitor = new Monitor (output);
		monitor.show_settings.connect ((output, rect) => {
			Gtk.Allocation alloc;
			get_allocation (out alloc);

			rect.x += alloc.x;
			rect.y += alloc.y;

			show_settings (output, rect);
		});
		get_stage ().add_child (monitor);

		reposition ();
	}

	public void reposition ()
	{
		var left = int.MAX;
		var right = 0;
		var top = int.MAX;
		var bottom = 0;

		// TODO respect rotation

		int x, y, width, height;

		foreach (var child in get_stage ().get_children ()) {
			unowned Monitor monitor = (Monitor) child;

			monitor.output.get_geometry (out x, out y, out width, out height);

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

	public void remove_all ()
	{
	}
}

