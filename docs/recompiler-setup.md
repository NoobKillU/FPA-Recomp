# Recompiler setup

## Pipeline

This project uses ReXGlue for local ahead-of-time PPC-to-C++ translation and a host runtime. Consult the ReXGlue SDK's official documentation for SDK installation and supported versions. A successful translation or link is an early milestone and does not by itself establish complete game compatibility.

## Local code generation

Keep a decrypted XEX that you are entitled to use in a private local folder. Copy `config/rexglue.example.toml` to the ignored `fpa_recomp_manifest.toml`, adjust its XEX path, then run `tools/run_codegen.ps1`. Generated files are ignored and must not be committed or uploaded. The repository deliberately does not contain target binaries or generated target code.

The SDK CLI is found through `REXGLUE_SDK_PREFIX` (the SDK install prefix) or `PATH`. For CMake, set `REXGLUE_SDK_PREFIX` or configure `CMAKE_PREFIX_PATH` so `find_package(rexglue)` can locate the SDK.

## Build and run

`tools/build_release.ps1` configures and builds the Windows AMD64 Release preset. It locates Visual Studio and CMake on the current machine and uses the installed Visual Studio Clang toolchain. The build requires local generated sources and the SDK. At runtime, the app defaults its game data root to the executable's folder; place the required game files beside the executable. `FPA_GAME_ROOT` can point to another local game data folder.

## Compatibility and performance

The app has SDL and XInput controller paths. The preferred SDL backend supports common Xbox and PlayStation gamepads; the Windows XInput path is for Xbox-compatible devices. Settings are stored beside the locally built executable. The tested configuration kept 720p output and used asynchronous D3D12 pipeline creation, but frame pacing and performance depend on the host GPU and driver. No minimum hardware target or consistent 60 FPS guarantee has been verified.

The project does not patch game licensing or entitlement behavior. Implement only ordinary platform services supported by observed behavior and permitted by applicable rights.
