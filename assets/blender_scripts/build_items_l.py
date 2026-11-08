"""Zero Return - item models L: the 7.6x51 rounds of the catalogue's fifth slice (decision economy-1a, 2026-11-08), EFT's
7.62x51 NATO loads. Brass cases for the service loads, lacquered steel for the two commercial ones (EFT's BCP and TCW
are Russian steel-cased), told apart by tip colours: orange for the tracer, black for the armour piercers, a bare steel
tip on the enhanced load, a red polymer tip on the hunting bullet; no maker's marks.
"""
from zr_items import col
from build_items_a import ammo_item, COPPER, STEEL_CASE

ORANGE, BLACK, RED = col("C0602A"), col("1E1E1E"), col("8E2A1E")
LEAD, SILVER, VIOLET = col("8A8C88"), col("A4A7A0"), col("5A3A6A")
CLAD = col("A87048")

# 7.6x51 (EFT's 7.62x51 NATO): Ultra Nosler, TCW SP, BCP FMJ, M62 Tracer, M80, M80A1, M61, M993
ammo_item("A76N_HP", 0.051, 0.021, 0.006, COPPER, tip2=RED, n=4)
ammo_item("A76N_SP", 0.051, 0.02, 0.006, CLAD, tip2=LEAD, casecol=STEEL_CASE, n=4)
ammo_item("A76N_FMJ", 0.051, 0.02, 0.006, CLAD, casecol=STEEL_CASE, n=4)
ammo_item("A76N_TR", 0.051, 0.02, 0.006, COPPER, tip2=ORANGE, n=4)
ammo_item("A76N_BALL", 0.051, 0.02, 0.006, COPPER, n=4)
ammo_item("A76N_EP", 0.051, 0.02, 0.006, COPPER, tip2=SILVER, n=4)
ammo_item("A76N_AP", 0.051, 0.02, 0.006, COPPER, tip2=BLACK, n=4)
ammo_item("A76N_TC", 0.051, 0.02, 0.006, col("8C8F86"), tip2=VIOLET, n=4)

EXTRA = ["A76N_HP", "A76N_SP", "A76N_FMJ", "A76N_TR", "A76N_BALL", "A76N_EP", "A76N_AP", "A76N_TC"]
