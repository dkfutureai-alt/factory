#!/usr/bin/env python3
"""Idempotent Android INTERNET/CAMERA permission fix after flutter create."""

import argparse
from pathlib import Path
from xml.etree import ElementTree as ET

NS = "http://schemas.android.com/apk/res/android"
NAME = f"{{{NS}}}name"
REQUIRED = f"{{{NS}}}required"
ET.register_namespace("android", NS)


def apply_manifest(path: Path) -> bool:
    tree = ET.parse(path)
    root = tree.getroot()
    if root.tag != "manifest":
        raise ValueError("Expected Android manifest root")
    changed = False
    existing = {e.attrib.get(NAME) for e in root.findall("uses-permission")}
    for value in ("android.permission.INTERNET", "android.permission.CAMERA"):
        if value not in existing:
            root.insert(0, ET.Element("uses-permission", {NAME: value}))
            changed = True
    feature = next((e for e in root.findall("uses-feature")
                    if e.attrib.get(NAME) == "android.hardware.camera"), None)
    if feature is None:
        root.insert(0, ET.Element("uses-feature", {NAME: "android.hardware.camera", REQUIRED: "false"}))
        changed = True
    elif feature.attrib.get(REQUIRED) != "false":
        feature.attrib[REQUIRED] = "false"
        changed = True
    if changed:
        ET.indent(tree, space="    ")
        tree.write(path, encoding="utf-8", xml_declaration=True)
    return changed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    print("Android manifest " + ("updated" if apply_manifest(args.manifest) else "already configured"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
