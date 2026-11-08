"""Zero Return - item models R: the rounds of the catalogue's eleventh slice (decision economy-1a, 2026-11-08): EFT's
.357 Magnum loads (FMJ, JHP, HP, SP: our 9x33R FMJ, JHP, HP, SP) on straight brass rimmed cases and its 12.7x55 loads
(PS12, PS12A, PS12B) on long lacquered steel cases; told apart by their bullets and tip colours; no maker's marks.
"""
from zr_items import col
from build_items_a import ammo_item, COPPER, STEEL_CASE

RED, GREEN, BLACK, GREY, LEAD, VIOLET = col("8E2A1E"), col("3E7A3A"), col("1E1E1E"), col("8C8F86"), col("8A8C88"), col("5A3A6A")
CLAD = col("A87048")

# 9x33R (EFT's .357 Magnum)
ammo_item("A933_FMJ", 0.033, 0.009, 0.0045, COPPER, n=5)
ammo_item("A933_JHP", 0.033, 0.008, 0.0045, COPPER, tip2=LEAD, n=5)
ammo_item("A933_HP", 0.033, 0.008, 0.0045, LEAD, tip2=GREY, n=5)
ammo_item("A933_SP", 0.033, 0.009, 0.0045, LEAD, n=5)
# 12.7x55 (EFT's 12.7x55 PS12 loads)
ammo_item("A127_PS12", 0.055, 0.02, 0.0064, CLAD, casecol=STEEL_CASE, n=3)
ammo_item("A127_PS12A", 0.055, 0.016, 0.0064, CLAD, tip2=GREEN, casecol=STEEL_CASE, n=3)
ammo_item("A127_PS12B", 0.055, 0.02, 0.0064, CLAD, tip2=BLACK, casecol=STEEL_CASE, n=3)

EXTRA = ["A933_FMJ", "A933_JHP", "A933_HP", "A933_SP", "A127_PS12", "A127_PS12A", "A127_PS12B"]
