#!/usr/bin/env python3
"""Add the network permission needed by Supabase to the generated Android runner.

The image_picker plugin does not require broad storage permissions.
"""
from pathlib import Path
import xml.etree.ElementTree as ET

path = Path(__file__).resolve().parent.parent / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
if not path.is_file():
    raise SystemExit("Android runner missing. Generate via flutter create first.")
android_ns = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", android_ns)
tree = ET.parse(path)
root = tree.getroot()
if root.tag != "manifest":
    raise SystemExit("Expected Android manifest root.")
name = f"{{{android_ns}}}name"
if not any(
    child.tag == "uses-permission"
    and child.get(name) == "android.permission.INTERNET"
    for child in root
):
    element = ET.Element("uses-permission", {name: "android.permission.INTERNET"})
    root.insert(0, element)
tree.write(path, encoding="utf-8", xml_declaration=True)
print("Android release network permission configured (no storage permissions added).")
