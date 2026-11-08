"""Zero Return - item models O: the 11.4x23 rounds of the catalogue's eighth slice (decision economy-1a, 2026-11-08),
EFT's .45 ACP loads: short fat brass cases, told apart by their bullets (a fragmenting copper cup, a hollow point with
a post, an orange-tipped tracer, plain ball, a black-tipped piercer); no maker's marks.
"""
from zr_items import col
from build_items_a import ammo_item, COPPER

RED, ORANGE, BLACK, GREY = col("8E2A1E"), col("C0602A"), col("1E1E1E"), col("8C8F86")
CLAD = col("A87048")

# 11.4x23 (EFT's .45 ACP): RIP, Hydra-Shok, Lasermatch FMJ, Match FMJ, AP
ammo_item("A114_FX", 0.023, 0.009, 0.0057, COPPER, tip2=RED, n=5)
ammo_item("A114_HP", 0.023, 0.009, 0.0057, COPPER, tip2=col("8A8C88"), n=5)
ammo_item("A114_TR", 0.023, 0.009, 0.0057, CLAD, tip2=ORANGE, n=5)
ammo_item("A114_FMJ", 0.023, 0.009, 0.0057, CLAD, n=5)
ammo_item("A114_AP", 0.023, 0.009, 0.0057, GREY, tip2=BLACK, n=5)

EXTRA = ["A114_FX", "A114_HP", "A114_TR", "A114_FMJ", "A114_AP"]
