# FPA-Recomp
A static native recompilation of The Fancy Pants Adventures (2011), Xbox 360, built on the ReXGlue SDK.

This is not an emulator. The PowerPC code inside the game's default.xex is translated ahead of time into C++, then compiled into a native x86-64 binary. There is no JIT and no instruction interpreter at runtime — the game's own logic runs as native code. What the SDK provides is everything around that: the Xbox 360 kernel calls, the filesystem, audio, input, and a translation of the Xenos GPU to Direct3D 12.

You need your own copy of the game. This repository contains no game data, no default.xex, no generated C++, and no compiled binary — and it never will. See Legal.

Status
Playable, with some stuttering (still working out the kinks).

