/*
 * SPDX-License-Identifier: LGPL-2.0-or-later
 * SPDX-FileCopyrightText: 2024 elementary, Inc. (https://elementary.io)
 */

[DBus (name = "net.hadess.SensorProxy")]
public interface Display.SensorProxy : GLib.DBusProxy {
    public abstract bool has_accelerometer { get; }
}

public class Display.SensorManager : Object {
    public bool has_accelerometer { get; private set; }

    private static GLib.Once<SensorManager> instance;
    public static unowned SensorManager get_default () {
        return instance.once (() => new SensorManager ());
    }

    private class SensorManager () { }

    construct {
        try {
            // Synchronous otherwise search might be false negative
            SensorProxy sensor_proxy = Bus.get_proxy_sync (BusType.SYSTEM, "net.hadess.SensorProxy", "/net/hadess/SensorProxy");
            has_accelerometer = sensor_proxy.has_accelerometer;
        } catch (Error e) {
            info ("Unable to connect to SensorProxy bus, probably means no accelerometer supported: %s", e.message);
        }
    }
}
