/*-
 * Copyright (c) 2018 elementary LLC.
 *
 * This software is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this software; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Display.MonitorManager : GLib.Object {
    public Gee.LinkedList<Display.VirtualMonitor> virtual_monitors { get; construct; }
    public Gee.LinkedList<Display.Monitor> monitors { get; construct; }

    public bool global_scale_required { get; private set; }
    public bool mirroring_supported { get; private set; }
    public int max_width { get; private set; }
    public int max_height { get; private set; }
    public int monitor_number {
        get {
            return monitors.size;
        }
    }

    public int virtual_monitor_number {
        get {
            return virtual_monitors.size;
        }
    }

    public bool is_mirrored {
        get {
            return virtual_monitors.size == 1 && monitors.size > 1;
        }
    }

    private MutterDisplayConfigInterface iface;

    private static MonitorManager monitor_manager;
    public static unowned MonitorManager get_default () {
        if (monitor_manager == null) {
            monitor_manager = new MonitorManager ();
        }

        return monitor_manager;
    }

    private MonitorManager () {
        get_monitor_config ();
    }

    private MonitorConfigurationService monitor_configuration_service;

    construct {
        monitors = new Gee.LinkedList<Display.Monitor> ();
        virtual_monitors = new Gee.LinkedList<Display.VirtualMonitor> ();
        try {
            iface = Bus.get_proxy_sync (BusType.SESSION, "org.gnome.Mutter.DisplayConfig", "/org/gnome/Mutter/DisplayConfig");
            iface.monitors_changed.connect (get_monitor_config);
        } catch (Error e) {
            critical (e.message);
        }
        monitor_configuration_service = new MonitorConfigurationService (iface);
    }

    public void get_monitor_config () {
        monitor_configuration_service.read_config ();
        mirroring_supported = monitor_configuration_service.mirroring_supported;
        global_scale_required = monitor_configuration_service.global_scale_required;
        max_width = monitor_configuration_service.max_width;
        max_height = monitor_configuration_service.max_height;

        var monitors_with_changed_modes = new Gee.LinkedList<Display.Monitor> ();
        foreach (var mutter_monitor in monitor_configuration_service.get_monitors ()) {
            var monitor = get_monitor_by_serial (mutter_monitor.monitor.serial);
            if (monitor != null) {
                monitors_with_changed_modes.add (monitor);
            }
            add_or_update_monitor (mutter_monitor);
        }

        foreach (var mutter_logical_monitor in monitor_configuration_service.get_logical_monitors ()) {
            add_or_update_virtual_monitor (mutter_logical_monitor, monitors_with_changed_modes);
        }
    }

    public void set_monitor_config () {
        MutterWriteLogicalMonitor[] logical_monitors = {};
        foreach (var virtual_monitor in virtual_monitors) {
            logical_monitors += get_mutter_logical_monitor (virtual_monitor);
        }
        
        monitor_configuration_service.write_config (logical_monitors);
    }

    public static MutterWriteLogicalMonitor get_mutter_logical_monitor (Display.VirtualMonitor virtual_monitor) {
        var logical_monitor = MutterWriteLogicalMonitor () {
            x = virtual_monitor.x,
            y = virtual_monitor.y,
            scale = virtual_monitor.scale,
            transform = virtual_monitor.transform,
            primary = virtual_monitor.primary
        };

        MutterWriteMonitor[] mutter_monitors = {};
        foreach (var monitor in virtual_monitor.monitors) {
            var properties = new GLib.HashTable<string, GLib.Variant> (str_hash, str_equal);
            var mutter_monitor = MutterWriteMonitor () {
                connector = monitor.connector,
                monitor_mode = monitor.current_mode.id,
                properties = properties
            };

            mutter_monitors += mutter_monitor;
        }

        logical_monitor.monitors = mutter_monitors;
        return logical_monitor;
    }

    //TODO: check for compatibility of displays in the same virtualmonitor.
    public void enable_clone_mode () {
        var clone_virtual_monitor = new Display.VirtualMonitor ();
        clone_virtual_monitor.primary = true;
        clone_virtual_monitor.scale = Utils.get_min_compatible_scale (monitors);
        clone_virtual_monitor.monitors.add_all (monitors);
        var modes = clone_virtual_monitor.get_available_modes ();
        /*
         * Two choices here:
         *  - Use the largest resolution already in use.
         *  - Fallback to the largest resultion available.
         */

        Display.MonitorMode? largest_mode_in_use = null;
        Display.MonitorMode largest_mode = modes.get (0);
        foreach (var mode in modes) {
            if (mode.is_current) {
                if (largest_mode_in_use == null) {
                    largest_mode_in_use = mode;
                } else if (largest_mode_in_use.width < mode.width) {
                    largest_mode_in_use = mode;
                }
            }

            // If there is one compatible setting, stop computing the fallback
            if (largest_mode_in_use == null) {
                if (largest_mode == null) {
                    largest_mode = mode;
                } else if (largest_mode.width < mode.width) {
                    largest_mode = mode;
                }
            }
        }

        if (largest_mode_in_use != null) {
            clone_virtual_monitor.set_current_mode (largest_mode_in_use);
        } else {
            clone_virtual_monitor.set_current_mode (largest_mode);
        }

        virtual_monitors.clear ();
        virtual_monitors.add (clone_virtual_monitor);

        notify_property ("virtual-monitor-number");
        notify_property ("is-mirrored");
    }

    public void disable_clone_mode () {
        double max_scale = Utils.get_min_compatible_scale (monitors);
        var new_virtual_monitors = new Gee.LinkedList<Display.VirtualMonitor> ();
        foreach (var monitor in monitors) {
            var single_virtual_monitor = new Display.VirtualMonitor ();
            var preferred_mode = monitor.preferred_mode;
            var current_mode = monitor.current_mode;
            if (global_scale_required) {
                single_virtual_monitor.scale = max_scale;
                if (max_scale in preferred_mode.supported_scales) {
                    current_mode.is_current = false;
                    preferred_mode.is_current = true;
                } else if (!(max_scale in current_mode.supported_scales)) {
                    Display.MonitorMode? largest_mode = null;
                    foreach (var mode in monitor.modes) {
                        if (max_scale in mode.supported_scales) {
                            if (largest_mode == null || mode.width > largest_mode.width) {
                                largest_mode = mode;
                            }
                        }
                    }

                    current_mode.is_current = false;
                    largest_mode.is_current = true;
                }
            } else {
                current_mode.is_current = false;
                preferred_mode.is_current = true;
                single_virtual_monitor.scale = preferred_mode.preferred_scale;
            }

            single_virtual_monitor.monitors.add (monitor);
            new_virtual_monitors.add (single_virtual_monitor);
        }

        new_virtual_monitors.get(0).primary = true;
        virtual_monitors.clear ();
        virtual_monitors.add_all (new_virtual_monitors);

        notify_property ("virtual-monitor-number");
        notify_property ("is-mirrored");
    }


    private void add_or_update_monitor (MutterReadMonitor mutter_monitor) {
        var monitor = get_monitor_by_serial (mutter_monitor.monitor.serial);
        if (monitor == null) {
            monitor = new Display.Monitor ();
            monitors.add (monitor);
        }

        monitor.connector = mutter_monitor.monitor.connector;
        monitor.vendor = mutter_monitor.monitor.vendor;
        monitor.product = mutter_monitor.monitor.product;
        monitor.serial = mutter_monitor.monitor.serial;
        var display_name_variant = mutter_monitor.properties.lookup ("display-name");
        if (display_name_variant != null) {
            monitor.display_name = display_name_variant.get_string ();
        } else {
            monitor.display_name = monitor.connector;
        }

        var is_builtin_variant = mutter_monitor.properties.lookup ("is-builtin");
        if (is_builtin_variant != null) {
            monitor.is_builtin = is_builtin_variant.get_boolean ();
        } else {
            /*
             * Absence of "is-builtin" means it's not according to the documentation.
             */
            monitor.is_builtin = false;
        }

        foreach (var mutter_mode in mutter_monitor.modes) {
            var mode = monitor.get_mode_by_id (mutter_mode.id);
            if (mode == null) {
                mode = new Display.MonitorMode ();
                monitor.modes.add (mode);
            }

            mode.id = mutter_mode.id;
            mode.width = mutter_mode.width;
            mode.height = mutter_mode.height;
            mode.frequency = mutter_mode.frequency;
            mode.preferred_scale = mutter_mode.preferred_scale;
            mode.supported_scales = mutter_mode.supported_scales;
            var is_preferred_variant = mutter_mode.properties.lookup ("is-preferred");
            if (is_preferred_variant != null) {
                mode.is_preferred = is_preferred_variant.get_boolean ();
            } else {
                mode.is_preferred = false;
            }

            var is_current_variant = mutter_mode.properties.lookup ("is-current");
            if (is_current_variant != null) {
                mode.is_current = is_current_variant.get_boolean ();
            } else {
                mode.is_current = false;
            }
        }
    }

    private void add_or_update_virtual_monitor (MutterReadLogicalMonitor mutter_logical_monitor, Gee.LinkedList<Display.Monitor>? monitors_with_changed_modes = null) {
        string monitors_id = generate_id_from_monitors (mutter_logical_monitor.monitors);
        var virtual_monitor = get_virtual_monitor_by_id (monitors_id);
        if (virtual_monitor == null) {
            virtual_monitor = new VirtualMonitor ();
            virtual_monitors.add (virtual_monitor);
            notify_property ("virtual-monitor-number");
        }

        virtual_monitor.x = mutter_logical_monitor.x;
        virtual_monitor.y = mutter_logical_monitor.y;
        virtual_monitor.scale = mutter_logical_monitor.scale;
        virtual_monitor.transform = mutter_logical_monitor.transform;
        virtual_monitor.primary = mutter_logical_monitor.primary;
        foreach (var mutter_info in mutter_logical_monitor.monitors) {
            foreach (var monitor in monitors) {
                if (compare_monitor_with_mutter_info (monitor, mutter_info) && !(monitor in virtual_monitor.monitors)) {
                    virtual_monitor.monitors.add (monitor);
                    virtual_monitor.modes_changed ();
                    if (monitors_with_changed_modes != null && monitor in monitors_with_changed_modes) {
                        virtual_monitor.modes_changed ();
                    }

                    break;
                }
            }
        }
    }

    private VirtualMonitor? get_virtual_monitor_by_id (string id) {
        foreach (var vm in virtual_monitors) {
            if (vm.id == id) {
                return vm;
            }
        }

        return null;
    }

    private static string generate_id_from_monitors (MutterReadMonitorInfo[] infos) {
        string val = "";
        foreach (var info in infos) {
            val += info.serial;
        }

        return val;
    }

    private static bool compare_monitor_with_mutter_info (Display.Monitor monitor, MutterReadMonitorInfo mutter_info) {
        return monitor.connector == mutter_info.connector
               && monitor.vendor == mutter_info.vendor
               && monitor.product == mutter_info.product
               && monitor.serial == mutter_info.serial;
    }

    private Display.Monitor? get_monitor_by_serial (string serial) {
        foreach (var monitor in monitors) {
            if (monitor.serial == serial) {
                return monitor;
            }
        }

        return null;
    }
}
