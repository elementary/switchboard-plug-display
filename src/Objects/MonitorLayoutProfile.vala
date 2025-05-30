/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Leonardo Lemos <leonardolemos@live.com>
 */

public class Display.MonitorLayoutProfile : GLib.Object {
    public class MonitorPosition : GLib.Object {
        public string id { get; set; }
        public int x { get; set; }
        public int y { get; set; }

        public MonitorPosition (string id, int x, int y) {
            Object (id: id, x: x, y: y);
        }
    }

    public string id { get; set; }
    private List<MonitorPosition> _positions;

    public unowned List<MonitorPosition> positions {
        get {
            return _positions;
        }
    }

    public MonitorLayoutProfile (string id) {
        Object (id: id);
    }

    construct {
        _positions = new List<MonitorPosition> ();
    }

    public void add_position (string id, int x, int y) {
        _positions.append (new MonitorPosition (id, x, y));
    }

    public MonitorPosition? find_position_by_id (string id) {
        foreach (var position in _positions) {
            if (position.id == id) {
                return position;
            }
        }
        return null;
    }
}