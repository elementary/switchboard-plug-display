SOURCES=src/OutputList.vala \
        src/DisplayPlug.vala \
	src/DisplayPopover.vala \
        src/Utils.vala

displays: $(SOURCES)
	valac -X -DGETTEXT_PACKAGE="\"abc\"" -X -DGNOME_DESKTOP_USE_UNSTABLE_API --pkg granite --pkg gnome-desktop-3.0 --vapidir=. $(SOURCES) -o displays -X -lm -g

