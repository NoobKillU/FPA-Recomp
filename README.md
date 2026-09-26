# Fancy Pants Adventures Recompilation 
# HEAVILY VIBECODED
This is a community research project for running a native Windows build based on ReXGlue. The repository contains project scaffolding, tools, and documentation. It does not include the commercial game, its assets, XEX files, or translated game code.

## Requirements

- Windows 10 or later, CMake 3.25+, Ninja, Git, Python 3, and Visual Studio 2022 with C++ and Clang/LLVM components.
- A separately installed ReXGlue SDK compatible with the project. Set `REXGLUE_SDK_PREFIX` to its install prefix, or make the SDK tools and CMake package discoverable through `PATH` and `CMAKE_PREFIX_PATH`.
- A copy of the game obtained and used lawfully. Keep the XEX used for local code generation in a private folder; `local-game/` is the sample path and is ignored by Git.

## Build

1. Install the ReXGlue SDK using its official instructions.
2. Create `fpa_recomp_manifest.toml` from `config/rexglue.example.toml` and point it at your local decrypted XEX. Keep your local manifest and game files private.
3. The example manifest already includes the function-boundary entries in `config/fpa_overrides.toml`. Run `./tools/run_codegen.ps1` to translate locally. Generated output stays in the ignored `generated/` folder.
4. Run `./tools/build_release.ps1` to configure and build the Windows x64 Release app.

The app looks for runtime game files in the same folder as `fpa_recomp.exe`, so keep the required game files beside the executable. `FPA_GAME_ROOT` can override this. The checked-in CMake presets configure a build but do not provide game inputs or generated game code. Build output is local and ignored.

## Controllers and settings

Both SDL and XInput backends are supported by the runtime. SDL is preferred for broad controller support, including PlayStation and Xbox pads. XInput is intended for Xbox-compatible pads. Keyboard emulation is available as well. Runtime settings are in the local `fpa_recomp.toml` beside the executable.

The suggested local settings are in [config/fpa_recomp.example.toml](config/fpa_recomp.example.toml). Copy the file beside the executable as `fpa_recomp.toml`. It keeps 720p and enables asynchronous pipeline creation; unfinished pipelines can temporarily omit draws. Results vary by GPU and driver, and smooth frame pacing is not guaranteed on every system.

For a point-and-click setup, run [tools/fpa_recomp_launcher.exe](tools/fpa_recomp_launcher.exe). It lets you browse to the executable and game data folder, choose resolution and fullscreen, select SDL or XInput, then writes `fpa_recomp.toml` beside the executable and launches it. The C# source is `tools/fpa_recomp_launcher.cs`; rebuild it with `tools/build_launcher.ps1` using the .NET Framework C# compiler included with Windows/Visual Studio.

## Repository safety

Do not commit or upload XEX files, package archives, extracted assets, generated game-specific C++ files, local manifests, build output, logs, or release executables containing translated title code. This project does not provide DRM, signature, encryption, or entitlement bypasses. The release runtime binaries are not checked into this source repository; use the SDK build and follow its license notices for local distribution.

## Project notes

- `docs/architecture-investigation.md` records evidence and open questions from non-modifying inspection.
- `docs/recompiler-setup.md` documents the local workflow and known limitations.
- `docs/reference-notes.md` records general reference-project observations.
- `tools/inspect_inputs.py` reports read-only file metadata.

The NFSMW-Recompiled project is a reference for general structure only. Its title-specific code and data are unrelated to this project.
