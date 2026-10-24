# PeriPage printer protocol

Reverse engineered from the official Android app `com.ileadtek.peripage` v6.10.12. The relevant classes are `y0.e` (transport), `y0.h` (command builder) and `y6.a` (driver and reply parser).

## Transport

- **Bluetooth Classic SPP** (RFCOMM). The UUID is `00001101-0000-1000-8000-00805F9B34FB`.
- **Windows:** the paired printer appears as a virtual COM port.
- **Write size:** the official app writes in chunks of at most 1024 bytes.
- **Printer identification:** by Bluetooth name, e.g. `PeriPage_A6_3F21` or `PPG_P21_HD_1A02`.

## Commands

| Purpose | Bytes | Reply |
|---|---|---|
| Model | `10 FF 20 F0` | ASCII, may end in `OK` |
| Firmware | `10 FF 20 F1` | ASCII `V1.4.7_xxxx` |
| Serial | `10 FF 20 F2` | ASCII |
| Bluetooth firmware | `10 FF 30 10` | ASCII |
| All info | `10 FF 70` | `\|`-separated ASCII |
| Battery | `10 FF 50 F1` | 2 bytes, `[1]` = percent |
| Status | `10 FF 40` | `00` idle · `01` busy · `03` voice mode · `04` no paper · `08` low battery · `10` overheated |
| Density | `10 FF 10 00 n` | `OK` |
| Paper type | `10 FF 10 03 n` | `OK` |
| Speed (some models) | `10 FF C0 n` | `OK` |
| Auto-off (minutes) | `10 FF 12 hi lo` | – |
| Start job | `10 FF FE 01` (newer models also send `1F B2 10`) | – |
| End job | `10 FF FE 45` | – |
| Feed n dots | `1B 4A n` | – |
| Paper back-off | `10 FF 81 n` | – |
| Form feed / next label | `1D 0C` | – |

**Density values.** The UI offers light, normal and dark, which the app sends as 0, 1 and 2 for most models. Some families use a different scale: 0/2/4, or values such as 6/8/12.

**Paper type values.** `0` continuous roll, `1` folded black mark, `2` label with gaps, `3` single sheets.

## Print sequence (roll paper)

```
10 FF FE 01                     start
00 × 12                         wake
1D 76 30 00 xL xH yL yH <data>  raster, x = bytes per row, y = rows
1B 4A n                         feed
10 FF FE 45                     end
```

Raster rows are 1 bit per pixel, with the most significant bit as the leftmost pixel and `1` meaning black. The official app counts a pixel as black when its grey value is below 190, applied after dithering.

## Compressed raster (not implemented)

Newer models get `1F 00 wH wL hH hL len32BE` followed by data compressed with `com.example.sdk.Code.code()`. That function lives in the native `libCode.so`, which is not in the base APK we have. The models are listed in `PrinterModel._compressedExact` and `PrinterModel._compressedPrefixes`.
