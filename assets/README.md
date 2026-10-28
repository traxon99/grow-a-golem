# Original assets (#16)

The model templates, vector illustrations and synthesized WAV files in this
folder were created specifically for Grow A Golem. No third-party models,
recordings, fonts, textures or samples were used. Their sources are
`scripts/create_assets.py` and `scripts/create_keyart.py`; they may be used and
modified for this project. Visual polish, Studio appearance and audibility still
need review before public release. These are a starter art kit, not commissioned
production art or evidence of a playtest.

## Model contract

Rojo maps `models/Assets.rbxmx` to `ReplicatedStorage.Assets`:

- `Golem/<tier>/<part>`: eight tiers, each with Head, Torso, LeftArm, RightArm,
  LeftLeg and RightLeg. Part pivots are their attachment centres, in golem
  scale-1 studs. The loader decorates invisible gameplay carriers and keeps
  existing Motor6D joints, collision roots and the shoulder seat. Supplemental
  feet, fists, chest pieces and runes from the fallback remain visible, except
  on slots that have uploaded mesh art (below).
- `Enemies/boss1` through `boss6`: normalized to one stud of approximate height;
  the loader scales to `def.size.Y`, centred at the gameplay root. Body/Torso/
  Carapace, Head/Jaw, Fist/Wing, Leg/Foot/CrawlerLeg names create body/head/jaw/
  arm/leg Motor6D animation joints. Eyes and antlers attach to the head.
- `Props/rock`, `Props/basalt`, `Props/crystalCluster`: ground-centred pivots,
  scale-1 studs. Other prop types keep their procedural fallback.

Replace templates with original Studio-authored models at the same paths.
Templates require at least one BasePart and must be Archivable. Scripts,
Humanoids and imported joints/constraints are stripped; seats reject the asset.
All decorative parts are massless, non-colliding, non-touchable and excluded
from queries. The game owns physics and animations. An absent or empty template
falls back to the code model. Golem skins recolor imported parts too; check
Wardrobe preview and live skin appearance in Studio.

The three added zone bosses currently have distinct silhouettes built from this
kit. New regular enemies reuse the older procedural designs and palettes.

## Blender golem meshes

`scripts/blender/build_golems.py` builds one original low-poly golem per tier
from primitives in Blender (1 unit = 1 stud, facing +Y) and exports
`models/golems/golem_<tier>.fbx` plus `golem_meshes.json` (each mesh's offset
and size). Each slot has up to three meshes: `<Slot>_Main` (tier colour),
`<Slot>_Trim` (darker shade) and `<Slot>_Glow` (neon runes, recoloured by
skins). `preview.png` shows all eight.

To get them into the game:

1. In Studio, **File > Import 3D** each FBX with **Scale unit: Studs** and
   upload on. Keep the objects as separate MeshParts.
2. Record each MeshPart's mesh id in `models/golems/mesh_ids.json` as
   `{"<tier>/<Slot>_<Role>": <id>}`.
3. Run `python3 scripts/blender/golem_mesh_data.py`, which writes
   `src/server/Models/GolemMeshData.luau`.

`GolemMeshes` creates the MeshParts with `AssetService:CreateMeshPartAsync`
when the server starts and swaps them in for the block templates. A slot is
used only when all its meshes have ids and load, so a missing upload falls
back to the block art.

## Audio upload manifest

There is one original 22,050 Hz mono 16-bit PCM file per Config.SoundEffects key
under `audio/`. Three are also the moment sounds: artifact.wav, levelUp.wav,
grow.wav. Upload these in Creator Dashboard as the experience owner, grant the
test and production experiences access, and check moderation/permissions before
assigning numeric IDs. Set the corresponding Config.SoundEffects `<key>.id` to
`rbxassetid://<uploaded id>`, set playback speed to 1 for these rendered samples,
and set Config.Sounds artifact/levelUp/grow to those three **numeric** IDs.
Existing built-in sounds and zero IDs intentionally remain until valid uploads
exist. An invented ID would hide an incomplete task and may play unlicensed audio.

| File | Effect |
| --- | --- |
| golemStep.wav, bossStep.wav | Heavy footsteps |
| punch.wav, enemyAttack.wav, defeat.wav | Combat |
| mine.wav, mineBreak.wav | Mining |
| quake.wav, mend.wav, magnet.wav | Spells |
| slamWarn.wav, slam.wav, downed.wav | Boss/reform feedback |
| artifact.wav, levelUp.wav, grow.wav | Moment sounds and matching Config.Sounds |
| click.wav, tutorialStep.wav | Interface |
| wind.wav | Soft ambience (2-second clip; audition loop seam) |

## Key-art drafts

`keyart/icon-a.png` and `icon-b.png` are 512×512 face-first icon alternatives
(stone on blue, crystal on orange) drawn to stay readable at 48 px. The four
`thumbnail-*.png` files are 1920×1080 vector illustration drafts, with editable
SVG sources. They depict the ride, Old Rockjaw's slam warning, a party and a
starter golem beside its grown self; **they are not screenshots**. Prefer actual Studio captures following the launch shot list
before advertising. Do not imply the illustrations are recorded gameplay.

Rebuild:

```sh
python3 scripts/create_assets.py
# PNG export uses cairosvg if installed (pip install cairosvg==2.9.1),
# otherwise Playwright's Chromium through node.
python3 scripts/create_keyart.py
```

## Mystical UI icons (#83)

See [ui-icons/README.md](ui-icons/README.md) for the 37 original icons, editable
SVGs, individual PNGs, color/grayscale sprite sheets and upload instructions.
