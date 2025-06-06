/*-
 * Copyright (c) 2014-2018 elementary LLC.
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

namespace Display.Utils {
    public static Gee.LinkedList<Display.MonitorMode> get_common_monitor_modes (Gee.LinkedList<Display.Monitor> monitors) {
        var common_modes = new Gee.LinkedList<Display.MonitorMode> ();
        double min_scale = get_min_compatible_scale (monitors);
        bool first_monitor = true;
        foreach (var monitor in monitors) {
            if (first_monitor) {
                foreach (var mode in monitor.modes) {
                    if (min_scale in mode.supported_scales) {
                        common_modes.add (mode);
                    }
                }

                first_monitor = false;
            } else {
                var to_remove = new Gee.LinkedList<Display.MonitorMode> ();
                foreach (var mode_to_check in common_modes) {
                    bool mode_found = false;
                    foreach (var monitor_mode in monitor.modes) {
                        if (mode_to_check.width == monitor_mode.width &&
                            mode_to_check.height == monitor_mode.height) {
                            mode_found = true;
                            break;
                        }
                    }

                    if (mode_found == false) {
                        to_remove.add (mode_to_check);
                    }
                }

                common_modes.remove_all (to_remove);
            }
        }

        return common_modes;
    }

    public static double get_min_compatible_scale (Gee.LinkedList<Display.Monitor> monitors) {
        double min_scale = double.MAX;
        foreach (var monitor in monitors) {
            min_scale = double.min (min_scale, monitor.get_max_scale ());
        }

        return min_scale;
    }
    
    public double[] sort_and_deduplicate_double_array (double[] input) {
        for (int i = 0; i < input.length - 1; i++) {
            for (int j = 0; j < input.length - i - 1; j++) {
                if (input[j] > input[j + 1]) {
                    double temp = input[j];
                    input[j] = input[j + 1];
                    input[j + 1] = temp;
                }
            }
        }

        double[] result = {};

        foreach (double v in input) {
            bool found = false;
            foreach (double r in result) {
                if (Math.fabs (v - r) < 1e-9) {
                    found = true;
                    break;
                }
            }

            if (!found) {
                result += v;
            }
        }

        return result;
    }
}
