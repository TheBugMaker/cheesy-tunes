Cheese payout estimates
=======================

Assumptions
-----------
Target margin: 1.05
Payout range: +/- 15%
Process step bonus: $0.50

Raw material costs:
- milk: $2
- salt: $2
- bacteria culture: $3
- acid: $4
- rennet: $4
- white mold: $6
- blue mold: $6
- wine: $7

Ingredient bonuses:
- white mold: $3
- blue mold: $4
- wine: $5

Estimated payout ranges
-----------------------
Cheese | Ingredients | Raw cost | Process steps | Process bonus | Ingredient bonus | Target price | Payout range
--- | --- | ---: | ---: | ---: | ---: | ---: | ---:
Paneer | milk, acid | $6 | 5 | $2.50 | $0 | $9 | $8-$10
Cream cheese | milk, salt, bacteria culture | $7 | 5 | $2.50 | $0 | $10 | $8-$12
Mozzarella (Alt) | milk, acid, salt | $8 | 10 | $5 | $0 | $14 | $12-$16
Comte | milk, bacteria culture, rennet, salt | $11 | 8 | $4 | $0 | $16 | $14-$18
Mozzarella | milk, acid, rennet, salt | $12 | 10 | $5 | $0 | $18 | $15-$21
Brie | milk, salt, rennet, bacteria culture, white mold | $17 | 8 | $4 | $3 | $25 | $21-$29
Roquefort | milk, salt, rennet, bacteria culture, blue mold | $17 | 10 | $5 | $4 | $27 | $23-$31
Taleggio | milk, bacteria culture, rennet, salt, wine | $18 | 9 | $4.50 | $5 | $29 | $25-$33

Target cheese_db.gd code
------------------------
Replace `INGREDIENT_PRICES` in `scripts/cheese_db.gd` with:

```gdscript
const INGREDIENT_PRICES: Dictionary = {
	"milk":     2,
	"acid":     4,
	"salt":     2,
	"bacteria": 3,
	"rennet":   4,
	"mold":     6,
	"wine":     7,
}
```

Replace `CHEESE_PAYOUT_RANGE` in `scripts/cheese_db.gd` with:

```gdscript
const CHEESE_PAYOUT_RANGE: Dictionary = {
	"Paneer":           Vector2i(8, 10),
	"Cream Cheese":     Vector2i(8, 12),
	"Mozzarella (Alt)": Vector2i(12, 16),
	"Comte":            Vector2i(14, 18),
	"Mozzarella":       Vector2i(15, 21),
	"Brie":             Vector2i(21, 29),
	"Roquefort":        Vector2i(23, 31),
	"Taleggio":         Vector2i(25, 33),
}
```

Warnings
--------
- none
