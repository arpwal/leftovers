# dmgbuild layout for Leftovers.dmg: a fixed 660×400 window with no toolbar,
# the app on the left, Applications on the right, and the arrow background
# from design/dmg-background.html between them. Used by scripts/make-dmg.sh.
import os

app = defines.get("app", "build/Leftovers.app")  # noqa: F821 (provided by dmgbuild)
appname = os.path.basename(app)

format = "UDZO"
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = os.path.join(app, "Contents/Resources/AppIcon.icns")  # volume icon

background = "packaging/dmg/background.tiff"
# The window frame includes the title bar (28 pt), so the content area is 660×400.
window_rect = ((200, 140), (660, 428))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 128
text_size = 13
# Icon centres, matching the arrow in the background.
icon_locations = {appname: (170, 200), "Applications": (490, 200)}
