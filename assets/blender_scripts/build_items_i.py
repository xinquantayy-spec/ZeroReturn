"""Zero Return - item models I: the rounds of the catalogue's first slice (decision economy-1a, 2026-11-08). Same
cartridge groups and shotgun shells as build_items_a.py, told apart by the usual colour codes of their kind (a green tip
for steel-core and Soviet tracers, orange for western tracers, black for armour piercers, coloured hulls for the shotgun
loads); no maker's marks.
"""
from zr_items import col
from build_items_a import ammo_item, shells, BRASS, COPPER, STEEL_CASE
from zr_item_reg import item

GREEN, ORANGE, BLACK, RED = col("3E7A3A"), col("D8742A"), col("1E1E1E"), col("8E2A1E")

# 6.2x40
ammo_item("A62_SS", 0.04, 0.016, 0.0052, COPPER, tip2=GREEN)
ammo_item("A62_TR", 0.04, 0.016, 0.0052, COPPER, tip2=ORANGE)
ammo_item("A62_EP", 0.04, 0.016, 0.0052, col("B07A3A"), tip2=col("A9AEB0"))
# 7.6x39
ammo_item("A76_HP", 0.039, 0.019, 0.0058, col("C88A4A"), tip2=col("6E4A2A"), casecol=STEEL_CASE)
ammo_item("A76_TR", 0.039, 0.02, 0.0058, col("A9886A"), tip2=GREEN, casecol=STEEL_CASE)
ammo_item("A76_PP", 0.039, 0.02, 0.0058, col("A9886A"), tip2=col("6A5A8A"), casecol=STEEL_CASE)
# 9x19
ammo_item("A9_FMJ", 0.019, 0.011, 0.0049, COPPER, n=6)
ammo_item("A9_TR", 0.019, 0.011, 0.0049, col("9C9A90"), tip2=GREEN, n=6)
ammo_item("A9_PBP", 0.019, 0.011, 0.0049, col("8E8E86"), tip2=BLACK, casecol=STEEL_CASE, n=6)
# 7.6x54R
ammo_item("A76L_TR", 0.054, 0.024, 0.0062, col("8C8F86"), tip2=GREEN, casecol=STEEL_CASE, n=4)
ammo_item("A76L_PS", 0.054, 0.024, 0.0062, col("8C8F86"), casecol=STEEL_CASE, n=4)
ammo_item("A76L_BT", 0.054, 0.024, 0.0062, col("8C8F86"), tip2=col("D8D8D0"), casecol=STEEL_CASE, n=4)
ammo_item("A76L_BS", 0.054, 0.024, 0.0062, RED, tip2=BLACK, casecol=BRASS, n=4)


# 12/70
@item("A12_MAG", 1, 1, view="top_tilt", margin=0.08)
def a12_mag(I):
    shells(I, col("2A3A6A"))


@item("A12_FLECH", 1, 1, view="top_tilt", margin=0.08)
def a12_flech(I):
    shells(I, col("2A2A2A"), tip=col("8C8F8A"))


@item("A12_SABOT", 1, 1, view="top_tilt", margin=0.08)
def a12_sabot(I):
    shells(I, col("4E7A3A"), tip=col("D8D8D0"))


@item("A12_APS", 1, 1, view="top_tilt", margin=0.08)
def a12_aps(I):
    shells(I, RED, tip=BLACK)


EXTRA = ["A62_SS", "A62_TR", "A62_EP", "A76_HP", "A76_TR", "A76_PP", "A9_FMJ", "A9_TR", "A9_PBP", "A12_MAG", "A12_FLECH",
         "A12_SABOT", "A12_APS", "A76L_TR", "A76L_PS", "A76L_BT", "A76L_BS"]
