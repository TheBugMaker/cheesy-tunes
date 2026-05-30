class_name Songs
extends RefCounted
## Per-recipe riffs for Cheezy Tunes. Pure data (mirrors CheeseDB).
##
## Each cheese maps to a recognizable riff transcribed from a well-known song.
## The riff is split into PHRASES — one phrase per recipe ingredient, in recipe
## order (recipe[i] owns phrases[i]). The sequencer flattens the phrases into one
## looping melody: a selected ingredient sounds its whole phrase, an unselected one
## rests for that phrase's length, and a selected WRONG tile tacks an off-key clash
## onto the tail. Clicking ingredients in recipe order unmasks the tune phrase by
## phrase.
##
## Within a phrase, `notes` are semitone offsets from the tonic (C3 = 0; negatives
## go below) and `durs` are note lengths in STEP units (1 = eighth, 2 = quarter,
## 4 = half, 8 = whole). notes.size() == durs.size() per phrase. Phrases give each
## riff several bars and a real long/short rhythm, so the melody is easy to
## recognize instead of one flat note per ingredient. Copyright isn't a concern
## (hobby project), so these are direct (register-shifted) transcriptions.

const STEP := 0.24   # seconds per duration unit (one eighth note ≈ 125 BPM, the
                     # average tempo of these riffs — Smoke 114, 7-Nation 124,
                     # Sunshine 117, Day Tripper 137)

## cheese name -> {title, phrases}. phrases.size() == recipe length (one per ingredient).
const SONGS: Dictionary = {
	"Mozzarella": {
		"title": "Smoke on the Water",          # Deep Purple, G minor — one full pass of the riff,
		"phrases": [                            # quarter-note feel with each phrase ringing out
			{"notes": [7, 10, 12], "durs": [2, 2, 4]},   # milk    — G  Bb C
			{"notes": [7, 10],     "durs": [2, 2]},      # citric  — G  Bb
			{"notes": [13, 12],    "durs": [2, 4]},      # rennet  — Db C
			{"notes": [7, 10],     "durs": [2, 2]},      # heat    — G  Bb
			{"notes": [12, 10],    "durs": [2, 2]},      # stretch — C  Bb
			{"notes": [7],         "durs": [6]},         # salt    — G  (held turnaround)
		],
	},
	"Cheddar": {
		"title": "Seven Nation Army",            # The White Stripes, E minor — the riff's signature
		"phrases": [                            # rhythm: dotted-quarter, four quick notes, two halves
			{"notes": [4],   "durs": [3]},   # milk       — E  (dotted quarter)
			{"notes": [4],   "durs": [1]},   # culture    — E  (eighth)
			{"notes": [7],   "durs": [1]},   # rennet     — G  (eighth)
			{"notes": [4],   "durs": [1]},   # cut_curd   — E  (eighth)
			{"notes": [2],   "durs": [1]},   # drain_whey — D  (eighth)
			{"notes": [0],   "durs": [4]},   # salt       — C  (half)
			{"notes": [-1],  "durs": [4]},   # press      — B  (half)
		],
	},
	"Brie": {
		"title": "My Girl",                      # The Temptations, C major — relaxed ascending intro:
		"phrases": [                            # eighth-note walk-ups landing on held notes
			{"notes": [0, 2, 4],  "durs": [1, 1, 1]},   # milk       — C  D  E
			{"notes": [7],        "durs": [4]},         # culture    — G  (held)
			{"notes": [0, 2, 4],  "durs": [1, 1, 1]},   # rennet     — C  D  E
			{"notes": [7, 9],     "durs": [1, 4]},      # drain_whey — G  A  (held)
			{"notes": [7, 4],     "durs": [2, 2]},      # salt       — G  E
			{"notes": [2, 0],     "durs": [2, 6]},      # white_mold — D  C  (resolve to tonic)
		],
	},
	"Blue Cheese": {
		"title": "Close Encounters",             # John Williams — the 5-note motif, then a low echo;
		"phrases": [                            # three even notes answered by two long ones
			{"notes": [14, 16],     "durs": [2, 2]},      # milk      — D  E
			{"notes": [12],         "durs": [2]},         # culture   — C
			{"notes": [0],          "durs": [4]},         # rennet    — C (8vb, half)
			{"notes": [7],          "durs": [6]},         # salt      — G  (dotted half)
			{"notes": [2, 4, 0, 7], "durs": [2, 2, 2, 6]},# blue_mold — D  E  C  G (low echo)
		],
	},
	"Feta": {
		"title": "Sunshine of Your Love",        # Cream, D blues — the descending riff: a held note
		"phrases": [                            # ends each motif, giving the heavy bluesy swagger
			{"notes": [2, 2],     "durs": [2, 2]},   # milk     — D  D
			{"notes": [0, 2],     "durs": [2, 4]},   # culture  — C  D  (held)
			{"notes": [-3],       "durs": [2]},      # rennet   — A
			{"notes": [-5, -3],   "durs": [2, 4]},   # cut_curd — G  A  (held)
			{"notes": [2, 2, 0],  "durs": [2, 2, 2]},# salt     — D  D  C
			{"notes": [-3, -5],   "durs": [2, 6]},   # brine    — A  G  (resolve)
		],
	},
	"Swiss": {
		"title": "Day Tripper",                  # The Beatles, E major — driving eighth-note riff that
		"phrases": [                            # climbs to the 5th and resolves back to the root
			{"notes": [4, 6, 8],  "durs": [1, 1, 1]},   # milk      — E  F# G#
			{"notes": [4],        "durs": [2]},         # culture   — E  (quarter pivot)
			{"notes": [8, 9],     "durs": [1, 1]},      # rennet    — G# A
			{"notes": [11, 9],    "durs": [1, 2]},      # propionic — B  A  (peak)
			{"notes": [8, 6],     "durs": [1, 1]},      # press     — G# F#
			{"notes": [4],        "durs": [6]},         # age       — E  (resolve to root)
		],
	},
}


## Phrases for a cheese (one per ingredient, in recipe order). Unknown cheeses get
## a one-note-per-ingredient ascending pentatonic fallback sized to the recipe.
static func phrases_for(cheese_name: String, recipe: Array) -> Array:
	if SONGS.has(cheese_name):
		return SONGS[cheese_name]["phrases"]
	var penta: Array[int] = [0, 2, 4, 7, 9, 12, 14, 16]
	var out: Array = []
	for i in recipe.size():
		out.append({"notes": [penta[i % penta.size()]], "durs": [2]})
	return out


## Display title of the riff for a cheese (falls back to a generic label).
static func title_for(cheese_name: String) -> String:
	if SONGS.has(cheese_name):
		return SONGS[cheese_name]["title"]
	return "%s riff" % cheese_name
