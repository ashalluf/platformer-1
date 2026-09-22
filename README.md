# LIBYAN GANGSTAS

A 2.5D premium platformer built in Godot 4 (Forward+). Gameplay is 2D; the world is 3D.

- `CLAUDE.md` — project brief and standing direction
- `docs/DESIGN.md` — the creative bible (canon)
- `docs/PROGRESS.md` — what is built, what is weak
- `docs/ROADMAP.md` — prioritized next work
- `docs/ASSETS.md` — external asset licenses

## Running

```sh
godot --path . # play
tools/capture.sh --level=res://levels/greybox/Greybox.tscn --frames=240 --out=captures/greybox
```

## Play in a browser

`docs/play/` is a Web export (Compatibility renderer, single-threaded, no
SharedArrayBuffer) so it can be served straight off GitHub Pages with no custom
headers. Rebuild it with:

```sh
godot --path . --headless --export-release "Web" build/web/index.html
cp build/web/* docs/play/
```

The browser build is a real downgrade and is not the reference for the visual
gate: Compatibility has no volumetric fog (the fog shader fails to compile
outright), no TAA and no screen-space AA. Judge visuals from the desktop build.
