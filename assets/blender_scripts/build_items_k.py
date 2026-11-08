"""Zero Return - item models K: the rounds of the catalogue's third slice (decision economy-1a, 2026-11-08), the KS-74's
5.4x39 and the PM's 9x18. Same cartridge groups as build_items_a.py; lacquered steel cases as on EFT's Soviet loads,
told apart by the usual colour codes (a green tip for tracers and the steel cores, black for armour piercers, red on
the hardened cores); no maker's marks.
"""
from zr_items import col
from build_items_a import ammo_item, COPPER, STEEL_CASE

GREEN, BLACK, RED, VIOLET = col("3E7A3A"), col("1E1E1E"), col("8E2A1E"), col("5A3A6A")
LACQUER = col("6A6A4E")          # green-grey lacquered steel case
CLAD = col("A87048")             # copper-clad steel jacket

# 5.4x39 (EFT's 5.45x39): HP, US gs, T gs, PS gs, BT gs, BP gs, BS gs
ammo_item("A54_HP", 0.039, 0.016, 0.0049, COPPER, casecol=LACQUER)
ammo_item("A54_US", 0.039, 0.017, 0.0049, CLAD, tip2=BLACK, casecol=LACQUER)
ammo_item("A54_T", 0.039, 0.016, 0.0049, CLAD, tip2=GREEN, casecol=LACQUER)
ammo_item("A54_PS", 0.039, 0.016, 0.0049, CLAD, casecol=LACQUER)
ammo_item("A54_BT", 0.039, 0.016, 0.0049, CLAD, tip2=VIOLET, casecol=LACQUER)
ammo_item("A54_BP", 0.039, 0.016, 0.0049, CLAD, tip2=RED, casecol=LACQUER)
ammo_item("A54_BS", 0.039, 0.016, 0.0049, col("8C8F86"), tip2=BLACK, casecol=LACQUER)
# 9x18 (EFT's 9x18 PM): P gzh, PSV, PPT gzh, Pst gzh, RG028 gzh, PBM gzh
ammo_item("A918_P", 0.018, 0.0105, 0.0046, CLAD, casecol=STEEL_CASE, n=6)
ammo_item("A918_PSV", 0.018, 0.0105, 0.0046, col("C8A050"), casecol=STEEL_CASE, n=6)
ammo_item("A918_PPT", 0.018, 0.0105, 0.0046, CLAD, tip2=GREEN, casecol=STEEL_CASE, n=6)
ammo_item("A918_PST", 0.018, 0.0105, 0.0046, col("9C9A90"), casecol=STEEL_CASE, n=6)
ammo_item("A918_RG", 0.018, 0.0105, 0.0046, CLAD, tip2=BLACK, casecol=STEEL_CASE, n=6)
ammo_item("A918_PBM", 0.018, 0.0105, 0.0046, col("8E8E86"), tip2=RED, casecol=STEEL_CASE, n=6)

EXTRA = ["A54_HP", "A54_US", "A54_T", "A54_PS", "A54_BT", "A54_BP", "A54_BS",
         "A918_P", "A918_PSV", "A918_PPT", "A918_PST", "A918_RG", "A918_PBM"]
