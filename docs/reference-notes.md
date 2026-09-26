# NFSMW-Recompiled: technique transfer notes

Reference examined: [madelrandel-blip/NFSMW-Recompiled](https://github.com/madelrandel-blip/NFSMW-Recompiled), with its architecture, build, patch, and performance documentation. The repository describes a static ahead-of-time path from a user-provided `default.xex` through generated C++ to a native x64 executable, using ReXGlue for Xbox runtime services and Xenos-to-host-GPU translation.

| Reference technique | Why it works there / evidence | Transfer to Fancy Pants Adventures |
|---|---|---|
| XenonRecomp-style ahead-of-time PPC translation | Game PPC code is translated to C++ at build time, then compiled as native x64. | Candidate only if the target contains PPC code and its instructions/calling conventions are supported. Confirm target binary first. |
| ReXGlue runtime and GPU backend | Reference separates translated game code from kernel/VFS/audio/input services and a Xenos graphics plugin. | Potential foundation; enumerate target imports and graphics behavior before adopting. XBLA title services may differ. |
| Manifest and override configuration | Reproducible codegen inputs and explicit manual translator corrections. | General pattern transfers; all addresses, symbols, and overrides must be target-derived. |
| SDK patch scripts with exact anchors and reversible application | Reference documents runtime fixes in its own SDK fork, with strict matching/idempotence. | Useful maintenance pattern if target evidence requires runtime changes. Never transfer patch contents blindly. |
| EDRAM/render-target alternatives | Reference documents Xenos render-target behavior and measured trade-offs. | Only relevant if target uses comparable Xenos rendering paths; measure after boot/rendering works. |
| Separate game app, SDK runtime, and GPU plugin | Provides boundaries for codegen, kernel compatibility, and graphics. | Likely a useful architectural separation, but validate whether target APIs fit these layers. |
| Profiling and measured optimization | Performance notes tie changes to hardware and measurements. | Transfer method, not reported performance or chosen defaults. |
| User-supplied game data and generated code excluded from repository | Reference excludes game executable/assets/generated game C++ from distribution. | Adopt as repository policy. Generated proprietary code stays local and ignored. |

## Important non-transferables

Do not copy NFSMW title ID, executable assumptions, XEX extraction process unless independently appropriate to the target package, PPC addresses, symbol names, game patches, shader fixes, EDRAM settings, save behavior, controller mappings, or multiplayer logic. The reference's success on one retail game is not evidence of compatibility with this XBLA title.

## Reproducibility practices worth adopting

- Keep target-specific manifests and overrides explicit and reviewed.
- Make generated output reproducible and local-only.
- Make source patches fail closed when an expected anchor is missing or ambiguous.
- Record evidence and verification for every compatibility fix.
- Separate runtime requirements from title-specific behavior.
- Benchmark optimizations with controlled configurations and retain measured results.

## Evidence boundary

This is a repository-level review, not a source-code audit of every SDK file. The public README and docs substantiate the high-level pipeline, architecture boundaries, patch discipline, and EDRAM/performance approach. Revisit deeper implementation details against the SDK and the target's actual requirements before implementation.
