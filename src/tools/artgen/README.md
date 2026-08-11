# artgen

Run from the project root with the bundled Python runtime:

```powershell
python src/tools/artgen/artgen.py --build-source --generate
python src/tools/artgen/verify_art.py
```

`golden_sample.json` is the generated, reviewable source contract: each frame
contains a palette-index matrix, its named frame metadata, canvas size, FPS and
center anchor. `artgen.py` deterministically emits the PNG sheet, 4× nearest
neighbour preview, Godot 4 `SpriteFrames` resource, manifest, contact sheet,
and 640×360 scene. It has no network dependencies.

Do not edit files under `assets/sprites/` or `assets/previews/` by hand.
Edit the source-building functions, run `--build-source --generate`, and then
run the verifier. The verifier regenerates once and compares SHA-256 values,
then checks dimensions, expected frame count, anchors, palette membership,
binary alpha and Godot resource references.
