"""Zero Return - item models P: the 7.6x25 rounds of the catalogue's ninth slice (decision economy-1a, 2026-11-08), EFT's
7.62x25 TT loads: slim bottlenecked cases (lacquered steel for the Soviet loads, brass for the commercial and sabot
ones), told apart by their bullets and tip colours; no maker's marks.
"""
from zr_items import col
from build_items_a import ammo_item, COPPER, STEEL_CASE

RED, GREEN, BLACK, GREY, LEAD, VIOLET = col("8E2A1E"), col("3E7A3A"), col("1E1E1E"), col("8C8F86"), col("8A8C88"), col("5A3A6A")
CLAD = col("A87048")

# 7.6x25 (EFT's 7.62x25 TT): LRNPC, LRN, FMJ43, AKBS, P gl, PT gzh, Pst gzh, TT M856A1, TT M855A1, TT M995
ammo_item("A76T_LRNPC", 0.025, 0.009, 0.0042, col("6A4A3A"), n=5)
ammo_item("A76T_LRN", 0.025, 0.009, 0.0042, LEAD, n=5)
ammo_item("A76T_FMJ", 0.025, 0.009, 0.0042, COPPER, n=5)
ammo_item("A76T_MATCH", 0.025, 0.009, 0.0042, COPPER, tip2=VIOLET, n=5)
ammo_item("A76T_P", 0.025, 0.009, 0.0042, CLAD, casecol=STEEL_CASE, n=5)
ammo_item("A76T_PT", 0.025, 0.009, 0.0042, CLAD, tip2=GREEN, casecol=STEEL_CASE, n=5)
ammo_item("A76T_PST", 0.025, 0.009, 0.0042, GREY, casecol=STEEL_CASE, n=5)
ammo_item("A76T_SBT", 0.025, 0.009, 0.0042, col("4A6A8A"), tip2=RED, n=5)
ammo_item("A76T_SB", 0.025, 0.009, 0.0042, col("4A6A8A"), n=5)
ammo_item("A76T_SBAP", 0.025, 0.009, 0.0042, col("4A6A8A"), tip2=BLACK, n=5)

EXTRA = ["A76T_LRNPC", "A76T_LRN", "A76T_FMJ", "A76T_MATCH", "A76T_P", "A76T_PT", "A76T_PST", "A76T_SBT", "A76T_SB", "A76T_SBAP"]
