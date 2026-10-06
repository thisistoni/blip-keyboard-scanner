# Three iPhone screenshot concepts

These English iPhone images are review concepts, not the current App Store set. They do not replace `composed` or `redesign`.

- `01-hero.png`: a large iPhone frame around the real Safari/Blip keyboard capture.
- `02-scan.png`: a close view of the real Blip scanner capture and demo barcode.
- `03-use.png`: the real Blip History capture with a close crop of the saved scan and its copy control. This shows a scan ready to use without claiming an insertion result or browser handoff that the available captures do not show.

Generate the three PNGs and contact sheet with:

```sh
xcrun swift scripts/compose_app_store_concepts.swift
```

The source captures are in `AppStore/Screenshots/final/en-US/iphone`. The existing captures precede the latest Settings rating row, which is not shown in these concepts.
