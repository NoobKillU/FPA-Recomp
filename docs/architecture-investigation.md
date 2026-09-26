# Architecture investigation: Fancy Pants Adventures (Xbox 360 XBLA, 2011)

## Evidence available before inspecting target files

- The title was released on Xbox Live Arcade and PlayStation Network in 2011.
- Contemporary reporting describes the console version as a collaboration between Brad Borne and EA, with Over the Top Games building the console version from the ground up.
- Brad Borne described prototyping the core game in Flash. This is evidence about the development workflow, not evidence that the retail Xbox 360 binary contains a Flash VM or ActionScript runtime.
- The Xbox Wire announcement lists local and Xbox Live multiplayer, which indicates multiplayer services existed in the product. It does not establish what services are required for offline boot/gameplay.

Sources:

- [Wired, March 1, 2011](https://www.wired.com/2011/03/fancy-pants-adventures/)
- [Brad Borne's console FAQ](https://www.bornegames.com/games/fpa-for-console/faqs/)
- [Xbox Wire, April 20, 2011](https://news.xbox.com/en-us/2011/04/20/arcade-the-fancy-pants-adventures/)

## Target-specific findings

Status after the first read-only inspection of the supplied game folder. No architecture claims are inferred from the NFS reference.

| Area | Status | Evidence required |
|---|---|---|
| XBLA package structure / title ID / region | Partially known: extracted folder, title ID 58410A9F; region unknown | Package metadata and XEX headers |
| Executable format and XEX modules | XEX2 title module; decrypted variant supplied, basic compression | Readable XEX and inner PE headers |
| PPC code, imports, exports, entry points | PowerPC big-endian PE confirmed; entry/base and section map read; function control flow not analyzed | Disassembly/recompiler analysis |
| Runtime dependencies / initialization | XAM/xboxkrnl ordinal imports; static links list XNET/XONLINE, D3D9/XGRAPHC, XAUDIO2, etc.; startup flow unknown | Call-site and runtime observation |
| Memory map / threading | Unknown | Executable metadata and runtime evidence |
| Graphics API / shader representation | D3D9/D3DX9/XGRAPHC statically linked; actual call paths and shader blobs unknown | Imports, call sites, assets |
| Audio and input APIs | XAUDIO2 statically linked; input APIs/call sites unknown | Imports and runtime evidence |
| Filesystem, profile, saves, achievements | Unknown | Imports and controlled behavior observation |
| Xbox Live / entitlement dependencies | Unknown | Call-site analysis and offline behavior; no bypass work |
| Asset and scripting formats | KCAP signature; path-like asset references and Lua evidence found; binary index/layout still unknown | Container-format analysis and script/resource relation |
| Middleware / engine identity | Unknown | Binary strings, import patterns, symbols, and corroborating evidence |

## Investigation sequence

1. Inventory supplied files without modifying the originals; record hashes and sizes.
2. Identify package/container format and executable modules using non-destructive metadata inspection. Do not defeat signatures, encryption, or entitlement controls.
3. Record XEX headers, imports, exports, entry point, image sections, and declared runtime requirements where readable.
4. Identify code and data regions and map imports to observed call sites.
5. Inspect package assets by file signatures and metadata; distinguish evidence of Flash-authored source/prototype from evidence of a runtime dependency.
6. If lawful and practical, observe normal startup and offline behavior on the user's Xbox 360 environment; record which services are actually invoked.
7. Only after the evidence review, select or adapt a static recompiler and define runtime compatibility needs.

## Findings log

At the initial scaffold stage, no title binary or package was present in the workspace. The supplied folder has since enabled the initial metadata/header findings below; the detailed executable and runtime findings listed as unknown are still pending.

## Initial inspection of the supplied folder (2026-09-26)

A user-supplied extracted game folder was inspected read-only.

### Confirmed from package metadata and readable headers

- `ArcadeInfo.xml` names the title **Fancy Pants Adventures**, points to `default.xex`, reports XDK version `1.0.0.0` and project version `1.0.205.0`.
- The title ID in `ArcadeInfo.xml` is decimal `1480657567`, which is hexadecimal `58410A9F`.
- The package manifest contains achievement metadata for IDs 13 through 24 (12 entries), leaderboard metadata, and parental-control metadata. This shows those features are represented in the package; it does not prove they are all needed to boot or play offline.
- `default.xex` is 2,174,976 bytes and begins with `XEX2`. Its readable optional header fields include an entry-point value `0x820A1D70`, image-base value `0x82000000`, and an import-library table at file offset `0x194C`.
- The XEX file-format metadata marks both encryption and compression as `normal` (enum values 1 and 2 in Xenia's public XEX header definitions). We have only read the metadata; no protected image content was decrypted or unpacked.
- The readable import-library table names `xam.xex` and `xboxkrnl.exe` and contains 136 and 264 import-table words respectively. Those words have not been mapped to exported function names or call sites.
- The XEX static-library metadata lists 16 libraries, including XAPILIB, XBOXKRNL, XNET, XONLINE, XPARTY, D3D9, D3DX9, XGRAPHC, XAUDIO2, XAPOBA, XMCORE, and XHV2. This is evidence of link-time dependencies, not proof every subsystem is used in normal offline gameplay.
- The available evidence supports classifying this as an Xbox 360 XEX title with native Xbox API dependencies. The inner PE machine field and actual PPC instruction stream remain unread, so native PPC is not independently verified from the inner image. There is no evidence of a Flash VM in the inspected metadata; the engine/framework remains unidentified.
- Execution metadata independently reports title ID `58410A9F` and version/base version value `2`.
- `Media/Data360/Data360.pak` is 404,240,032 bytes and begins with `KCAP`, followed by big-endian words `1` and `3868`. Their meanings have not been identified from a format specification, so `3868` is recorded as a raw field, not asserted to be a resource count.
- A read-only signature scan found 280 PNG signatures; 274 were structurally traversable through PNG `IEND` chunks. The first PNG is 64×64, starts at offset `0x20`, and ends at `0x2068`. The next PNG signature is at `0x16E5A2E0`; a `78 9C` byte sequence appears at `0x2080`, but its format and boundaries are unverified. No assets were extracted.
- The remaining root files are PNG images, including title/marketplace imagery and achievement icons.

### Inspection of the user-supplied decrypted XEX

The supplied `defaultdecrypted.xex` was inspected read-only and not copied into this project.

- Its readable XEX metadata reports encryption `none`, compression `basic`, the same title ID `58410A9F`, entry point `0x820A1D70`, and image base `0x82000000` as the original.
- The basic-compressed inner PE was reconstructed in memory only. Its machine field is `0x01F2` (PowerPC big-endian), PE32 optional-header magic `0x010B`, and Xbox subsystem `14`. The inner PE entry RVA `0xA1D70` agrees with the XEX entry point relative to image base.
- Eight PE sections are present: `.rdata`, `.pdata`, `.text`, `.data`, `.XBMOVIE`, `.idata`, `.XBLD`, and `.reloc`. `.text` has virtual size `0x3F81CC`; this is a substantial native PPC code image, not a Flash executable container.
- The XEX import list resolves through XAM and xboxkrnl ordinal records. XAM imports cover input, local user/sign-in/profile, content/storage, notifications/UI, voice, and XNet networking families. Examples include `XamInputGetState`, `XamUserGetSigninInfo`, `XamUserCheckPrivilege`, `XamUserReadProfileSettings`, `XamContentGetLicenseMask`, `XamShowAchievementsUI`, `XamShowMarketplaceUI`, and `NetDll_XNetStartup`/socket functions. This establishes linked API dependencies only; it does not prove every import executes or that an online service is required for offline boot. In particular, entitlement-related imports must not be replaced with success responses as a way to defeat access checks.
- The static library list independently includes `D3D9`, `D3DX9`, `XGRAPHC`, `XAUDIO2`, `XNET`, `XONLINE`, and `XPARTY`. This points to the Xbox 360 D3D9/Xenos graphics path, XAudio2-family audio, and Xbox networking/party integration. Actual rendering commands, shader format, audio middleware behavior, input call sites, and startup sequence remain to be traced.
- The PE read-only data includes Lua's `5.1.4` identification string. The archive also contains one path-like reference, `scripts/test.lua`. Together these are strong evidence of an embedded Lua component and a script resource, though the script's content, runtime role, and native binding surface are not yet established. No standalone Lua bytecode signature was found by a raw archive scan.
- A filename-pattern scan of `Data360.pak` found 816 distinct path-like references, with many under texture/sound/font folders (heuristic suffix counts: 626 `.png`, 94 `.wav`, 32 `.ogg`, 42 `.txt`, 21 `.fnt`, one `.lua`). These are name references, not a validated archive file count. The KCAP header's `3868` field is still uninterpreted.

### Still unknown

The decrypted image establishes a native PPC executable and section map, but no game code has been translated or executed. Call-site behavior, initialization flow, threading, graphics/audio/input details, the KCAP index format, Lua use, save layout, and which XAM/XNet services are required for offline boot remain unknown.

Next safe analysis step: identify or document the KCAP container/index format using non-invasive evidence and public format documentation. Function-level XEX analysis cannot proceed from these metadata alone. This project will not defeat DRM, signatures, encryption, or entitlement checks.

The repeatable read-only inventory script is [inspect_inputs.py](../tools/inspect_inputs.py). Run it with the path to the user's game folder or an individual XEX. For an unencrypted basic-compressed XEX it reconstructs the PE image in memory to report headers and section metadata; it does not save or copy the reconstructed image or modify any game files.

XEX key and structure names were interpreted against [Xenia's public XEX header definitions](https://github.com/xenia-project/xenia/blob/master/src/xenia/kernel/util/xex2_info.h). XAM import ordinal names were cross-referenced with [Xenia's XAM export table](https://github.com/xenia-project/xenia/blob/master/src/xenia/kernel/xam/xam_table.inc). The decrypted file was provided by the user; the project parser deliberately refuses encrypted or normal-compressed code images.

### Source inventory fingerprints

