from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parent
RECIPES_PATH = ROOT / "recipes.yaml"
ASSUMPTIONS_PATH = ROOT / "economy_assumptions.yaml"
OUTPUT_PATH = ROOT / "cheese_payout_estimates.md"
CHEESE_DB_NAMES = {
    "Cream cheese": "Cream Cheese",
}
CHEESE_DB_INGREDIENTS = {
    "milk": "milk",
    "acid": "acid",
    "salt": "salt",
    "bacteria culture": "bacteria",
    "rennet": "rennet",
    "blue mold": "mold",
    "wine": "wine",
}


@dataclass(frozen=True)
class CheeseEstimate:
    name: str
    raw_cost: float
    process_steps: int
    process_bonus: float
    ingredient_bonus: float
    target_price: int
    low_price: int
    high_price: int
    ingredients: list[str]


def load_yaml(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as file:
        data = yaml.safe_load(file)
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a YAML mapping at the top level.")
    return data


def estimate_cheeses(
    recipes: dict[str, Any],
    assumptions: dict[str, Any],
) -> tuple[list[CheeseEstimate], list[str]]:
    target_margin = float(assumptions["target_margin"])
    payout_range_percent = float(assumptions["payout_range_percent"])
    process_step_bonus = float(assumptions["process_step_bonus"])
    raw_material_costs = assumptions.get("raw_material_costs", {})
    ingredient_bonuses = assumptions.get("ingredient_bonuses", {})

    cheese_data = recipes.get("cheese", {})
    if not isinstance(cheese_data, dict):
        raise ValueError("recipes.yaml must contain a 'cheese' mapping.")

    estimates: list[CheeseEstimate] = []
    warnings: list[str] = []

    for cheese_name, cheese_recipe in cheese_data.items():
        if not isinstance(cheese_recipe, dict):
            warnings.append(f"{cheese_name}: recipe entry is not a mapping; skipped.")
            continue

        raw_cost = 0.0
        ingredient_bonus = 0.0
        ingredients: list[str] = []

        for ingredient in cheese_recipe.get("ingredients", []):
            ingredient_name = str(ingredient).strip()
            ingredients.append(ingredient_name)

            if ingredient_name in raw_material_costs:
                raw_cost += float(raw_material_costs[ingredient_name])
            else:
                warnings.append(
                    f"{cheese_name}: missing raw material cost for '{ingredient_name}'."
                )

            ingredient_bonus += float(ingredient_bonuses.get(ingredient_name, 0))

        process_steps = len(cheese_recipe.get("process", []))
        process_bonus = process_steps * process_step_bonus
        base_cost = raw_cost + process_bonus + ingredient_bonus
        target_price = round(base_cost * target_margin)
        low_price = round(target_price * (1 - payout_range_percent))
        high_price = round(target_price * (1 + payout_range_percent))

        estimates.append(
            CheeseEstimate(
                name=str(cheese_name),
                raw_cost=raw_cost,
                process_steps=process_steps,
                process_bonus=process_bonus,
                ingredient_bonus=ingredient_bonus,
                target_price=target_price,
                low_price=low_price,
                high_price=high_price,
                ingredients=ingredients,
            )
        )

    estimates.sort(key=lambda estimate: (estimate.target_price, estimate.name.lower()))
    return estimates, warnings


def money(value: float) -> str:
    if float(value).is_integer():
        return f"${int(value)}"
    return f"${value:.2f}"


def cheese_db_name(name: str) -> str:
    return CHEESE_DB_NAMES.get(name, name)


def format_cheese_payout_range_code(estimates: list[CheeseEstimate]) -> str:
    names = [cheese_db_name(estimate.name) for estimate in estimates]
    name_width = max(len(name) for name in names)
    lines = [
        "const CHEESE_PAYOUT_RANGE: Dictionary = {",
    ]

    for estimate, name in zip(estimates, names):
        padding = " " * (name_width - len(name))
        lines.append(
            f'\t"{name}":{padding} Vector2i({estimate.low_price}, {estimate.high_price}),'
        )

    lines.append("}")
    return "\n".join(lines)


def format_ingredient_prices_code(assumptions: dict[str, Any]) -> str:
    raw_material_costs = assumptions.get("raw_material_costs", {})
    name_width = max(len(name) for name in CHEESE_DB_INGREDIENTS.values())
    lines = [
        "const INGREDIENT_PRICES: Dictionary = {",
    ]

    for research_name, cheese_db_id in CHEESE_DB_INGREDIENTS.items():
        if research_name not in raw_material_costs:
            continue
        padding = " " * (name_width - len(cheese_db_id))
        lines.append(
            f'\t"{cheese_db_id}":{padding} {round(float(raw_material_costs[research_name]))},'
        )

    lines.append("}")
    return "\n".join(lines)


def format_report(
    estimates: list[CheeseEstimate],
    warnings: list[str],
    assumptions: dict[str, Any],
) -> str:
    lines: list[str] = [
        "Cheese payout estimates",
        "=======================",
        "",
        "Assumptions",
        "-----------",
        f"Target margin: {assumptions['target_margin']}",
        f"Payout range: +/- {float(assumptions['payout_range_percent']) * 100:.0f}%",
        f"Process step bonus: {money(float(assumptions['process_step_bonus']))}",
        "",
        "Raw material costs:",
    ]

    for ingredient, cost in assumptions.get("raw_material_costs", {}).items():
        lines.append(f"- {ingredient}: {money(float(cost))}")

    lines.extend(["", "Ingredient bonuses:"])
    ingredient_bonuses = assumptions.get("ingredient_bonuses", {})
    if ingredient_bonuses:
        for ingredient, bonus in ingredient_bonuses.items():
            lines.append(f"- {ingredient}: {money(float(bonus))}")
    else:
        lines.append("- none")

    lines.extend(
        [
            "",
            "Estimated payout ranges",
            "-----------------------",
            (
                "Cheese | Ingredients | Raw cost | Process steps | Process bonus | "
                "Ingredient bonus | Target price | Payout range"
            ),
            (
                "--- | --- | ---: | ---: | ---: | ---: | ---: | ---:"
            ),
        ]
    )

    for estimate in estimates:
        lines.append(
            " | ".join(
                [
                    estimate.name,
                    ", ".join(estimate.ingredients),
                    money(estimate.raw_cost),
                    str(estimate.process_steps),
                    money(estimate.process_bonus),
                    money(estimate.ingredient_bonus),
                    money(float(estimate.target_price)),
                    f"{money(float(estimate.low_price))}-{money(float(estimate.high_price))}",
                ]
            )
        )

    lines.extend(
        [
            "",
            "Target cheese_db.gd code",
            "------------------------",
            "Replace `INGREDIENT_PRICES` in `scripts/cheese_db.gd` with:",
            "",
            "```gdscript",
            format_ingredient_prices_code(assumptions),
            "```",
            "",
            "Replace `CHEESE_PAYOUT_RANGE` in `scripts/cheese_db.gd` with:",
            "",
            "```gdscript",
            format_cheese_payout_range_code(estimates),
            "```",
        ]
    )

    lines.extend(["", "Warnings", "--------"])
    if warnings:
        for warning in warnings:
            lines.append(f"- {warning}")
    else:
        lines.append("- none")

    lines.append("")
    return "\n".join(lines)


def main() -> None:
    recipes = load_yaml(RECIPES_PATH)
    assumptions = load_yaml(ASSUMPTIONS_PATH)
    estimates, warnings = estimate_cheeses(recipes, assumptions)
    OUTPUT_PATH.write_text(format_report(estimates, warnings, assumptions), encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
