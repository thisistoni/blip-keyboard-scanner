# App Store Screenshots

## Workflow

1. Capture raw iPhone screenshots for the real Blip workflow:
   - Safari text field with the Blip keyboard open
   - scanner opened from the keyboard
   - successful insert back into Safari
2. Place those files in `raw/manual/iphone`.
3. Capture iPad-specific shots if Blip remains listed for iPad, then place them in `raw/manual/ipad`.
4. Use Fastlane for status checks and optional review frames.
5. Build the final App Store artwork in AppScreens and export it to `final/iphone-6.9` and `final/ipad-13`.

## Final Screenshot Story

1. Scan into any field.
2. Open the scanner from the keyboard.
3. Insert barcode and QR results instantly.
4. Configure layouts for each workflow.
5. Choose return target and scan suffix.
6. Simple setup for employees.

## Notes

The camera, custom keyboard inside Safari, and return-to-target flow must be captured on a physical device. Simulator screenshots are useful for clean app setup/settings screens, but they do not prove the wedge workflow.
