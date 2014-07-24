SOURCES=src/OutputList.vala \
        src/DisplayPlug.vala \
        src/Utils.vala

displays: main.vala
	valac -X -DGETTEXT_PACKAGE="\"abc\"" -X -DGNOME_DESKTOP_USE_UNSTABLE_API --pkg granite --pkg gnome-desktop-3.0 --vapidir=. $(SOURCES) -o displays -X -lm

