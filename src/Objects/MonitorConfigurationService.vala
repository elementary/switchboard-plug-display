public class MonitorConfigurationService : GLib.Object {
    public bool mirroring_supported { get; private set; }
    public bool global_scale_required { get; private set; }
    public int32 max_width { get; private set; }
    public int32 max_height { get; private set; }
    MutterReadMonitor[] mutter_monitors = {};
    MutterReadLogicalMonitor[] mutter_logical_monitors = {};
    private uint current_serial;

    private MutterDisplayConfigInterface iface;

    public MonitorConfigurationService (MutterDisplayConfigInterface iface) {
        this.iface = iface;
    }

    public void read_config () {
        GLib.HashTable<string, GLib.Variant> properties;
        try {
            iface.get_current_state (out current_serial, out mutter_monitors, out mutter_logical_monitors, out properties);
        } catch (Error e) {
            critical (e.message);
        }

        //TODO: make use of the "global-scale-required" property to differenciate between X and Wayland
        // Absence of "supports-mirroring" means true according to the documentation.
        var supports_mirroring_variant = properties.lookup ("supports-mirroring");
        mirroring_supported = supports_mirroring_variant != null
                            ? supports_mirroring_variant.get_boolean () : true;

        // Absence of "global-scale-required" means false according to the documentation.
        var global_scale_required_variant = properties.lookup ("global-scale-required");
        global_scale_required = global_scale_required_variant != null
                              ? global_scale_required_variant.get_boolean () : false;

        // Absence of "supports-mirroring" means true according to the documentation.
        var max_screen_size_variant = properties.lookup ("max-screen-size");
        if (max_screen_size_variant != null) {
            max_width = max_screen_size_variant.get_child_value (0).get_int32 ();
            max_height = max_screen_size_variant.get_child_value (1).get_int32 ();
        } else {
            max_width = int.MAX;
            max_height = int.MAX;
        }
    }

    public void write_config (MutterWriteLogicalMonitor[] logical_monitors) {
        var properties = new GLib.HashTable<string, GLib.Variant> (str_hash, str_equal);
        try {
            iface.apply_monitors_config (current_serial, MutterApplyMethod.PERSISTENT, logical_monitors, properties);
        } catch (Error e) {
            critical (e.message);
        }
    }

    public MutterReadMonitor[] get_monitors () {
        return mutter_monitors;
    }

    public MutterReadLogicalMonitor[] get_logical_monitors () {
        return mutter_logical_monitors;
    }
}