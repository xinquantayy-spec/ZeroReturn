"""Zero Return - item models M: the 9x39 rounds of the catalogue's sixth slice (decision economy-1a, 2026-11-08), EFT's
9x39 loads: long heavy subsonic bullets in lacquered steel cases, told apart by tip colours (a green band on the
expanding SPP, violet on PAB-9, black on SP-6, red on BP); no maker's marks.
"""
from zr_items import col
from build_items_a import ammo_item, COPPER, STEEL_CASE

GREEN, VIOLET, BLACK, RED = col("3E7A3A"), col("5A3A6A"), col("1E1E1E"), col("8E2A1E")
CLAD = col("A87048")

# 9x39 (EFT's 9x39): FMJ, SP-5 gs, SPP gs, PAB-9 gs, SP-6 gs, BP gs
ammo_item("A939_FMJ", 0.039, 0.019, 0.0057, COPPER, casecol=STEEL_CASE, n=4)
ammo_item("A939_SP5", 0.039, 0.019, 0.0057, CLAD, casecol=STEEL_CASE, n=4)
ammo_item("A939_SPP", 0.039, 0.019, 0.0057, CLAD, tip2=GREEN, casecol=STEEL_CASE, n=4)
ammo_item("A939_PAB", 0.039, 0.019, 0.0057, CLAD, tip2=VIOLET, casecol=STEEL_CASE, n=4)
ammo_item("A939_SP6", 0.039, 0.019, 0.0057, CLAD, tip2=BLACK, casecol=STEEL_CASE, n=4)
ammo_item("A939_BP", 0.039, 0.019, 0.0057, col("8C8F86"), tip2=RED, casecol=STEEL_CASE, n=4)

EXTRA = ["A939_FMJ", "A939_SP5", "A939_SPP", "A939_PAB", "A939_SP6", "A939_BP"]
