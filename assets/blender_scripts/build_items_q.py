"""Zero Return - item models Q: the rounds of the catalogue's tenth slice (decision economy-1a, 2026-11-08):
EFT's 9x21 loads (PE, P, PS, 7U4, BT, 7N42: our PE, P, PS, SUB, BT, AP) on lacquered steel or brass cases, and its
.366 TKM loads (FMJ, Geksa, EKO, AP-M: our 9.6x39 FMJ, EXP, CU, AP) on lacquered steel cases; told apart by their
bullets and tip colours; no maker's marks.
"""
from zr_items import col
from build_items_a import ammo_item, COPPER, STEEL_CASE

RED, GREEN, BLACK, GREY, LEAD, VIOLET = col("8E2A1E"), col("3E7A3A"), col("1E1E1E"), col("8C8F86"), col("8A8C88"), col("5A3A6A")
CLAD = col("A87048")

# 9x21 (EFT's 9x21 gzh loads)
ammo_item("A921_PE", 0.021, 0.008, 0.0045, LEAD, casecol=STEEL_CASE, n=5)
ammo_item("A921_P", 0.021, 0.008, 0.0045, CLAD, casecol=STEEL_CASE, n=5)
ammo_item("A921_PS", 0.021, 0.008, 0.0045, CLAD, tip2=GREY, casecol=STEEL_CASE, n=5)
ammo_item("A921_SUB", 0.021, 0.009, 0.0045, COPPER, tip2=BLACK, n=5)
ammo_item("A921_BT", 0.021, 0.008, 0.0045, CLAD, tip2=RED, casecol=STEEL_CASE, n=5)
ammo_item("A921_AP", 0.021, 0.008, 0.0045, GREY, tip2=VIOLET, n=5)
# 9.6x39 (EFT's .366 TKM)
ammo_item("A96_FMJ", 0.039, 0.012, 0.0048, COPPER, casecol=STEEL_CASE, n=4)
ammo_item("A96_EXP", 0.039, 0.011, 0.0048, GREY, casecol=STEEL_CASE, n=4)
ammo_item("A96_CU", 0.039, 0.013, 0.0048, COPPER, tip2=GREEN, casecol=STEEL_CASE, n=4)
ammo_item("A96_AP", 0.039, 0.012, 0.0048, CLAD, tip2=BLACK, casecol=STEEL_CASE, n=4)

EXTRA = ["A921_PE", "A921_P", "A921_PS", "A921_SUB", "A921_BT", "A921_AP", "A96_FMJ", "A96_EXP", "A96_CU", "A96_AP"]
