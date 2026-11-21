# Company profiles

Settings → Company Profiles exports the current configuration as a `.blipprofile` JSON file or a QR code. Both use `BlipCompanyProfile` validation and the same preview-before-Apply flow. A scan never applies a profile automatically. Cancel leaves the configuration unchanged.

The QR sheet shows the values from the exact snapshot encoded in the code: return target, language, keyboard type and layouts, scan suffix, automatic insertion, scan formats, scan sound, flashlight, zoom, scan area, keyboard appearance, key clicks and haptics, scan mode (Single / Batch), batch separator and whether duplicate codes are skipped. A company can therefore roll out batch scanning by file or QR code. The custom URL is included only when Custom is the selected return target. A remembered but inactive custom destination is neither shared nor displayed; importing another target also preserves that local remembered destination.

Profiles contain configuration, not scan history, barcode values, clipboard contents or in-flight scan sessions. Nothing is uploaded. History retention stays a local preference. Keyboard installation and Full Access remain device-level setup steps.

## Compatibility and transport

The schema remains version 1. Automatic insertion, keyboard appearance, key clicks and haptics, scan mode (`scannerScanMode`: `single`, `batch`) batch separator (`batchSeparator`: `comma`, `semicolon`, `space`, `tab`, `newline`) and skipping duplicate codes in a batch (`batchSkipDuplicates`: `true`, `false`) are optional keys; importing older profiles, including every profile exported by 1.0.4, leaves the omitted choices unchanged. Unknown enum values and unsupported schema versions are rejected before applying any settings.

Adding the batch keys did not require a version bump. Both 1.0.4 and this build decode profiles with Swift's synthesized `Decodable` (no custom `CodingKeys` or `init(from:)`), which ignores keys it does not know, and `validate()` checks only the known fields. A profile exported by this build therefore still imports on 1.0.4, which simply keeps its single-scan behaviour, while a version bump would make 1.0.4 reject it as unsupported. The QR prefix stays `BLIP_PROFILE:1:`.

QR transport is UTF-8 `BLIP_PROFILE:1:` followed by compact, sorted JSON. The two batch keys add about 56 bytes; a full profile without a custom URL is about 580 bytes. It is limited to 1,200 bytes and a maximum 129-module matrix, with a four-module quiet zone. Larger profiles use file export instead. The QR image and settings summary share one immutable profile snapshot.

The scanner recognizes the reserved `BLIP_PROFILE:` marker before its ordinary text-insertion path. Valid profiles open a preview after the camera dismisses; invalid or unsupported profile payloads show an error. Neither becomes keyboard text, a browser navigation or a history entry. Profile QR codes remain recognizable under Common Barcodes, while ordinary QR payloads continue to obey the selected format filter.

## Validation

The standalone pending-scan tests cover transport round trips, older profiles, unsupported versions, invalid settings, oversized payloads, inactive custom destinations, new appearance/feedback fields, the batch scan mode, separator and duplicate setting (1.0.4-shaped import, round trip, preview, invalid values, QR size budget) and the ordinary-QR filter. Build and run them with:

```sh
xcrun swiftc Shared/KeyboardSettings.swift Shared/BlipCompanyProfile.swift Shared/ScanHistory.swift Tests/PendingScanInsertionTests.swift -o /tmp/blip-profile-tests
/tmp/blip-profile-tests
```

Physical validation for build 1.0.4 (27), on iPhone 16 Pro Max / iOS 27.0.1:

- A real camera scan opened a preview with the expected five changed settings. Cancel preserved the saved configuration.
- A subsequent real camera scan and explicit Apply changed all five expected settings: German to English, System to Blip Blue, and automatic insertion, key clicks and haptics to off. Device preferences confirmed the changes while Safari and the saved inactive custom destination remained unchanged.
- The displayed QR decoded to the exported configuration, excluding the independently generated export timestamp. Safari was selected; the remembered inactive custom URL was absent from both the QR content and summary.
- The QR remained readable in light and dark appearance. Landscape kept the full QR visible, with the settings below it scrollable.
- File export to On My iPhone and re-import displayed a matching-settings preview.
- After changing the theme to Blip Blue, importing the saved file previewed the change back to System. Apply restored it. Re-export matched every configuration value from before testing, and the inactive custom destination remained saved locally.
- Scanning `BLIP_PROFILE:2:{}` through the real camera showed the unsupported-version warning. After dismissing it, the existing native test-field text was unchanged. Saved preferences, ordinary last-scan/pending-scan/history data and the extension insertion trace confirmed that no profile was applied and no text was inserted.

Build 29 also rejected malformed JSON, an invalid setting, and an oversized profile through the real camera. Each case showed an error without inserting text, changing configuration, or changing the decoded ordinary scan history. Profile-summary values now use primary text; the device contrast audit no longer flags those values.

The Common Barcodes camera control also passed: it ignored a visible ordinary QR and recognized a valid profile QR, which opened Preview. Explicit Apply restored the original test settings. Final design acceptance and a second receiving device remain unverified. See the [combined validation summary](RELEASE_1_0_4_QA.md) for current limits. This work remains in the combined draft update; it is not an App Store release.
