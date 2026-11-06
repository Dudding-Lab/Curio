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
# Device PIN / biometrics are optional unlock factors, never Supabase auth.
if not any(
    child.tag == "uses-permission"
    and child.get(name) == "android.permission.USE_BIOMETRIC"
    for child in root
):
    root.insert(0, ET.Element(
        "uses-permission", {name: "android.permission.USE_BIOMETRIC"}
    ))

# The endorsed local_auth Android implementation needs FragmentActivity.
src = path.parent / "kotlin"
entrypoints = list(src.rglob("MainActivity.kt"))
if len(entrypoints) != 1:
    raise SystemExit("Expected exactly one generated Android MainActivity.kt")
activity = entrypoints[0]
activity_source = activity.read_text(encoding="utf-8")
if "FlutterFragmentActivity" not in activity_source:
    if "FlutterActivity" not in activity_source:
        raise SystemExit("Unexpected MainActivity; cannot configure local_auth")
    activity_source = activity_source.replace(
        "io.flutter.embedding.android.FlutterActivity",
        "io.flutter.embedding.android.FlutterFragmentActivity",
    ).replace(
        ": FlutterActivity()", ": FlutterFragmentActivity()"
    )
    activity.write_text(activity_source, encoding="utf-8")

tree.write(path, encoding="utf-8", xml_declaration=True)
print("Android network and device-unlock permissions configured (no storage permissions added).")
