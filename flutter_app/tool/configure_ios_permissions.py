#!/usr/bin/env python3
"""Apply privacy purpose strings to a Flutter-generated iOS Info.plist.

Never run this on an unrelated Xcode project; the target is fixed to Runner.
"""
from pathlib import Path
import plistlib

root = Path(__file__).resolve().parent.parent
path = root / "ios" / "Runner" / "Info.plist"
if not path.is_file():
    raise SystemExit("iOS runner is missing. Run Flutter bootstrap on macOS first.")
with path.open("rb") as file:
    info = plistlib.load(file)
info["NSCameraUsageDescription"] = (
    "Kovunela benötigt die Kamera nur, wenn du ein Sammlungsobjekt fotografieren möchtest."
)
info["NSPhotoLibraryUsageDescription"] = (
    "Kovunela benötigt Zugriff auf ausgewählte Fotos, damit du Sammlungsobjekte erfassen kannst."
)
# No microphone permission: image_picker in Kovunela selects photos only.
with path.open("wb") as file:
    plistlib.dump(info, file, fmt=plistlib.FMT_XML, sort_keys=False)
print("iOS camera/photo usage explanations added.")
