"""Zero Return - item models N: the 4.6x30 and 5.7x28 rounds of the catalogue's seventh slice (decision economy-1a,
2026-11-08), EFT's personal-defence loads: small bottlenecked brass cases, told apart by tip colours (red on the
expanding loads, green on the subsonics, orange on the tracer, black on the piercers, a grey steel-core tip on the duty
round); no maker's marks.
"""
from zr_items import col
from build_items_a import ammo_item, COPPER

RED, GREEN, ORANGE, BLACK, GREY, BLUE = col("8E2A1E"), col("3E7A3A"), col("C0602A"), col("1E1E1E"), col("8C8F86"), col("2E4E8E")
CLAD = col("A87048")

# 4.6x30 (EFT's 4.6x30): Action SX, Subsonic SX, JSP SX, FMJ SX, AP SX
ammo_item("A46_HP", 0.03, 0.01, 0.0041, COPPER, tip2=RED, n=5)
ammo_item("A46_SUB", 0.03, 0.01, 0.0041, CLAD, tip2=GREEN, n=5)
ammo_item("A46_JSP", 0.03, 0.01, 0.0041, CLAD, tip2=col("8A8C88"), n=5)
ammo_item("A46_FMJ", 0.03, 0.01, 0.0041, CLAD, n=5)
ammo_item("A46_AP", 0.03, 0.01, 0.0041, GREY, tip2=BLACK, n=5)
# 5.7x28 (EFT's 5.7x28): R37.F, R37.X, SS198LF, SS197SR, SB193, L191, SS190
ammo_item("A57_FX", 0.029, 0.012, 0.004, COPPER, tip2=RED, n=5)
ammo_item("A57_EX", 0.029, 0.012, 0.004, COPPER, tip2=BLUE, n=5)
ammo_item("A57_LF", 0.029, 0.012, 0.004, col("A4A7A0"), tip2=col("6A8A5A"), n=5)
ammo_item("A57_SR", 0.029, 0.012, 0.004, CLAD, tip2=col("5A3A6A"), n=5)
ammo_item("A57_SUB", 0.029, 0.012, 0.004, CLAD, tip2=GREEN, n=5)
ammo_item("A57_TR", 0.029, 0.012, 0.004, CLAD, tip2=ORANGE, n=5)
ammo_item("A57_SS", 0.029, 0.012, 0.004, GREY, tip2=BLACK, n=5)

EXTRA = ["A46_HP", "A46_SUB", "A46_JSP", "A46_FMJ", "A46_AP", "A57_FX", "A57_EX", "A57_LF", "A57_SR", "A57_SUB", "A57_TR", "A57_SS"]
