# Valluvar's Pond (வள்ளுவர் குளம்)

A small 3D game built on the Thirukkural. Thiruvalluvar walks a map and plays a different
Kural game at each place. Made with Godot 4.7; runs in the browser, on Windows, and (planned) Android.

**Play it:** see the live link in the repository's "About" box.

## The games

| Place | Game |
|---|---|
| The pond (குளம்) | A Kural is missing a word and the fish carry words. Cast near the right fish; when it bites, tap to hook it. Wrong fish cost a heart. Streaks speed the pond up, every fifth Kural is a storm round, and a golden fish gives a heart and time. |
| The school (பள்ளி) | The first line of a Kural is shown; choose its second line. |
| The scribe's hut (ஏடகம்) | Write a Kural by tapping its words in the right order. |

Every game earns wisdom (ஞானம்), which is saved on the device. All 1,330 Kurals are included,
with English meanings.

**Controls:** tap or click the ground to walk (or use the arrow keys / WASD). When a gold ring
is reached, press the button that appears (or E / Enter).

## Adding it to a website (for the KTS site)

The `web/` folder is the finished web build: plain static files, no server code.

- **Simplest:** link to the hosted version (the live link above), or show it in a page:

  ```html
  <iframe src="LIVE_LINK_HERE" width="100%" height="720" style="border:0" allow="autoplay; fullscreen"></iframe>
  ```

- **Hosting it yourself:** copy the contents of `web/` to any folder on the site
  (for example `/games/valluvar/`) and open `index.html` from there.
  - The server should send `index.wasm` as `application/wasm` (most do).
  - Turn on gzip or brotli for `.wasm` and `.pck`: the download drops from about 42 MB to about 10 MB.
  - No special headers are needed; this is Godot's single-threaded web export.

## Working on it

1. Install [Godot 4.7](https://godotengine.org/download) and open this folder as a project.
2. Press Play. On Windows, `play.cmd` starts it if Godot is at the path inside that file.
3. To rebuild the web version: Project → Export → Web, or
   `godot --headless --export-release "Web" web/index.html` (needs Godot's web export templates).
4. `node serve-web.cjs` serves `web/` at http://localhost:4180 for testing.

The whole scene is built in code:

| File | What it holds |
|---|---|
| `scripts/main.gd` | The map: walking, the camera, entering and leaving each place |
| `scripts/world.gd` | Scenery: meadow, pond, trees, the school, the hut, paths, what is solid |
| `scripts/player.gd` | Thiruvalluvar on foot, with collisions |
| `scripts/fishing.gd`, `scripts/fish.gd` | The pond game |
| `scripts/minigames.gd` | The school and hut games |
| `scripts/sfx.gd` | All sound, generated in code (no audio files) |
| `scripts/hud.gd` | Everything drawn over the scene |
| `blender/make_valluvar.py` | Builds both Thiruvalluvar models (seated and standing) in Blender |

Thiruvalluvar is modelled by script: `blender --background --python blender/make_valluvar.py`
(seated) and the same with the environment variable `POSE=stand` (standing).

## Credits

- Kural text, transliteration and English meanings: the KTS portal (kts.cict.in),
  Central Institute of Classical Tamil. This game is a student project and is not an official CICT release.
- Fonts: Noto Serif Tamil, Noto Sans Tamil and Plus Jakarta Sans (SIL Open Font License; see `fonts/LICENSE-FONTS.txt`).
- Engine: Godot (MIT). Models made with Blender.
