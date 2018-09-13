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

    //      monitors_with_changed_modes = check_changed_monitors (mutter_monitors);
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


//  public void set_monitor_config () {
//
//  }

//  Gee.LinkedList<Display.Monitor> check_changed_monitors (MutterReadMonitor[] monitors) {
//      var monitors_with_changed_modes = new Gee.LinkedList<Display.Monitor> ();
//      foreach (var mutter_monitor in monitors) {
//          var monitor = get_monitor_by_serial (mutter_monitor.monitor.serial);
//          if (monitor == null) {
//              monitor = new Display.Monitor ();
//              monitors.add (monitor);
//          } else {
//              monitors_with_changed_modes.add (monitor);
//          }

//          monitor.connector = mutter_monitor.monitor.connector;
//          monitor.vendor = mutter_monitor.monitor.vendor;
//          monitor.product = mutter_monitor.monitor.product;
//          monitor.serial = mutter_monitor.monitor.serial;
//          var display_name_variant = mutter_monitor.properties.lookup ("display-name");
//          if (display_name_variant != null) {
//              monitor.display_name = display_name_variant.get_string ();
//          } else {
//              monitor.display_name = monitor.connector;
//          }

//          var is_builtin_variant = mutter_monitor.properties.lookup ("is-builtin");
//          if (is_builtin_variant != null) {
//              monitor.is_builtin = is_builtin_variant.get_boolean ();
//          } else {
//              /*
//              * Absence of "is-builtin" means it's not according to the documentation.
//              */
//              monitor.is_builtin = false;
//          }

//          foreach (var mutter_mode in mutter_monitor.modes) {
//              var mode = monitor.get_mode_by_id (mutter_mode.id);
//              if (mode == null) {
//                  mode = new Display.MonitorMode ();
//                  monitor.modes.add (mode);
//              }

//              mode.id = mutter_mode.id;
//              mode.width = mutter_mode.width;
//              mode.height = mutter_mode.height;
//              mode.frequency = mutter_mode.frequency;
//              mode.preferred_scale = mutter_mode.preferred_scale;
//              mode.supported_scales = mutter_mode.supported_scales;
//              var is_preferred_variant = mutter_mode.properties.lookup ("is-preferred");
//              if (is_preferred_variant != null) {
//                  mode.is_preferred = is_preferred_variant.get_boolean ();
//              } else {
//                  mode.is_preferred = false;
//              }

//              var is_current_variant = mutter_mode.properties.lookup ("is-current");
//              if (is_current_variant != null) {
//                  mode.is_current = is_current_variant.get_boolean ();
//              } else {
//                  mode.is_current = false;
//              }
//          }
//      }

//      return monitors_with_changed_modes;
//  }
//  public void get_monitor_config () {
//      MutterReadMonitor[] mutter_monitors;
//      MutterReadLogicalMonitor[] mutter_logical_monitors;
//      GLib.HashTable<string, GLib.Variant> properties;
//      try {
//          iface.get_current_state (out current_serial, out mutter_monitors, out mutter_logical_monitors, out properties);
//      } catch (Error e) {
//          critical (e.message);
//      }

//      //TODO: make use of the "global-scale-required" property to differenciate between X and Wayland
//      var supports_mirroring_variant = properties.lookup ("supports-mirroring");
//      if (supports_mirroring_variant != null) {
//          mirroring_supported = supports_mirroring_variant.get_boolean ();
//      } else {
//          /*
//           * Absence of "supports-mirroring" means true according to the documentation.
//           */
//          mirroring_supported = true;
//      }

//      var global_scale_required_variant = properties.lookup ("global-scale-required");
//      if (global_scale_required_variant != null) {
//          global_scale_required = global_scale_required_variant.get_boolean ();
//      } else {
//          /*
//           * Absence of "global-scale-required" means false according to the documentation.
//           */
//          global_scale_required = false;
//      }

//      var max_screen_size_variant = properties.lookup ("max-screen-size");
//      if (max_screen_size_variant != null) {
//          max_width = max_screen_size_variant.get_child_value (0).get_int32 ();
//          max_height = max_screen_size_variant.get_child_value (1).get_int32 ();
//      } else {
//          /*
//           * Absence of "supports-mirroring" means true according to the documentation.
//           */
//          max_width = int.MAX;
//          max_height = int.MAX;
//      }

//      var monitors_with_changed_modes = new Gee.LinkedList<Display.Monitor> ();
//      foreach (var mutter_monitor in mutter_monitors) {
//          var monitor = get_monitor_by_serial (mutter_monitor.monitor.serial);
//          if (monitor == null) {
//              monitor = new Display.Monitor ();
//              monitors.add (monitor);
//          } else {
//              monitors_with_changed_modes.add (monitor);
//          }

//          monitor.connector = mutter_monitor.monitor.connector;
//          monitor.vendor = mutter_monitor.monitor.vendor;
//          monitor.product = mutter_monitor.monitor.product;
//          monitor.serial = mutter_monitor.monitor.serial;
//          var display_name_variant = mutter_monitor.properties.lookup ("display-name");
//          if (display_name_variant != null) {
//              monitor.display_name = display_name_variant.get_string ();
//          } else {
//              monitor.display_name = monitor.connector;
//          }

//          var is_builtin_variant = mutter_monitor.properties.lookup ("is-builtin");
//          if (is_builtin_variant != null) {
//              monitor.is_builtin = is_builtin_variant.get_boolean ();
//          } else {
//              /*
//               * Absence of "is-builtin" means it's not according to the documentation.
//               */
//              monitor.is_builtin = false;
//          }

//          foreach (var mutter_mode in mutter_monitor.modes) {
//              var mode = monitor.get_mode_by_id (mutter_mode.id);
//              if (mode == null) {
//                  mode = new Display.MonitorMode ();
//                  monitor.modes.add (mode);
//              }

//              mode.id = mutter_mode.id;
//              mode.width = mutter_mode.width;
//              mode.height = mutter_mode.height;
//              mode.frequency = mutter_mode.frequency;
//              mode.preferred_scale = mutter_mode.preferred_scale;
//              mode.supported_scales = mutter_mode.supported_scales;
//              var is_preferred_variant = mutter_mode.properties.lookup ("is-preferred");
//              if (is_preferred_variant != null) {
//                  mode.is_preferred = is_preferred_variant.get_boolean ();
//              } else {
//                  mode.is_preferred = false;
//              }

//              var is_current_variant = mutter_mode.properties.lookup ("is-current");
//              if (is_current_variant != null) {
//                  mode.is_current = is_current_variant.get_boolean ();
//              } else {
//                  mode.is_current = false;
//              }
//          }
//      }

//      foreach (var mutter_logical_monitor in mutter_logical_monitors) {
//          string monitors_id = generate_id_from_monitors (mutter_logical_monitor.monitors);
//          var virtual_monitor = get_virtual_monitor_by_id (monitors_id);
//          if (virtual_monitor == null) {
//              virtual_monitor = new VirtualMonitor ();
//          }

//          virtual_monitor.x = mutter_logical_monitor.x;
//          virtual_monitor.y = mutter_logical_monitor.y;
//          virtual_monitor.scale = mutter_logical_monitor.scale;
//          virtual_monitor.transform = mutter_logical_monitor.transform;
//          virtual_monitor.primary = mutter_logical_monitor.primary;
//          foreach (var mutter_info in mutter_logical_monitor.monitors) {
//              foreach (var monitor in monitors) {
//                  if (compare_monitor_with_mutter_info (monitor, mutter_info) && !(monitor in virtual_monitor.monitors)) {
//                      virtual_monitor.monitors.add (monitor);
//                      if (monitor in monitors_with_changed_modes) {
//                          virtual_monitor.modes_changed ();
//                      }

//                      break;
//                  }
//              }
//          }

//          if (virtual_monitor.monitors.size > 0) {
//              add_virtual_monitor (virtual_monitor);
//          }
//      }
//  }