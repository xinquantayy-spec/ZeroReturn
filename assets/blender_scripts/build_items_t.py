"""Zero Return - item models T: the Smelter's two items (art-1a follow-up, 2026-11-09), original designs:
- the note with the code word for the smugglers' crawl (EFT's note with the code word "Ark" for Factory's smugglers'
  passage): a folded sheet torn from a pad, a word pencilled on it;
- the stores keycard (EFT's TerraGroup storage room keycard, 1x1, 10 uses): a pale card with a dark band and a chip.
Modelled in metres (front toward -Y, top +Z), conventions in zr_items.py.
"""
from zr_items import col, shade, label_band, R
from zr_item_reg import item
from build_items_c import card, GOLDC

PAPER = col("E4DCC4")
PENCIL = col("4A4A4E")


@item("NOTE_SMELT_CRAWL", 1, 1, view="top_tilt", margin=0.08)
def crawl_note(I):
    p = I("paper")
    # two leaves of a folded sheet, the top one slightly open
    p.box((0, 0, 0.0006), (0.074, 0.052, 0.0012), shade(PAPER, 0.92))
    p.box((0.002, 0.003, 0.0019), (0.07, 0.048, 0.0012), PAPER, rot=(0, 0, R(3)))
    # the torn top edge and the pencilled word (bands, no letters)
    for k in range(7):
        label_band(p, (-0.03 + k * 0.01, 0.025, 0.00255), (0.006, 0.0025, 0), shade(PAPER, 0.8), axis="z", sign=1)
    label_band(p, (-0.006, 0.004, 0.0026), (0.034, 0.005, 0), PENCIL, axis="z", sign=1)
    label_band(p, (-0.012, -0.008, 0.0026), (0.022, 0.0025, 0), shade(PENCIL, 1.4), axis="z", sign=1)
    label_band(p, (0.008, -0.016, 0.0026), (0.03, 0.0025, 0), shade(PENCIL, 1.4), axis="z", sign=1)


@item("KEY_SMELT_STORE", 1, 1, view="top_tilt", margin=0.08)
def stores_card(I):
    card(I, col("C9CCC4"), stripe=col("2C3A44"), chip=GOLDC)


EXTRA = ["NOTE_SMELT_CRAWL", "KEY_SMELT_STORE"]
