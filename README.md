# Cheezy Tunes 🧀

A small 2D **timed service-rush** game built in **Godot 4.6.3 (GDScript)**.
A customer order shows a cheese; a timer counts down. Click the correct
ingredient & step tiles to build it, then **Serve**. Get the recipe right
before time runs out. Three strikes and you're out.

The recipes are *real-ish* — they teach the basic ingredients and steps of
actual cheese-making.

## Run it

```bash
# from the repo root
~/.local/bin/Godot_v4.6.3-stable_linux.x86_64 --path . 
```

Or open the folder in the Godot editor and press **F5**.

Headless sanity check (imports + parses scripts, no window):

```bash
~/.local/bin/Godot_v4.6.3-stable_linux.x86_64 --headless --path . --quit
```

## How to play

- Read the order card (`Make: <Cheese>`) and its hint.
- Click ingredient/step tiles — they collect in the **Vat**.
- Click a tile again (or **Clear**) to remove it.
- Hit **Serve**. The vat must match the recipe **exactly** (no missing or
  extra tiles).
- Correct → +1 score and a new, slightly faster order.
- Wrong recipe or running out of time → a **strike**. 3 strikes → Game Over.

## Recipes (current rotation)

| Cheese     | Tiles |
|------------|-------|
| Mozzarella | Milk, Citric Acid, Rennet, Heat, Stretch, Salt |
| Cheddar    | Milk, Starter Culture, Rennet, Cut Curd, Drain Whey, Salt, Press |
| Brie       | Milk, Starter Culture, Rennet, Drain Whey, Salt, White Mold |

Blue Cheese, Feta and Swiss are defined in `scripts/cheese_db.gd` (set
`"active": true` to add them to the rotation).

## Project layout

```
project.godot          # Godot project config (main scene = scenes/main.tscn)
icon.svg               # placeholder cheese-wedge icon
scenes/main.tscn       # root Control node; game.gd builds the rest of the UI in code
scripts/game.gd        # game manager: UI, orders, timer, scoring, strikes
scripts/cheese_db.gd   # static data: tiles + cheese recipes
```

All visuals are in-engine placeholder art (colored buttons/panels/labels) — no
image assets yet.
