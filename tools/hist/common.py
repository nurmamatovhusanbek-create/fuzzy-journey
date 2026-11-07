"""Historical province names: the tables are written here by country and era, build_hist_names.py turns them into godot/data/hist_names.json and the ru / uz name files.
Era codes (the year the game starts in): A -218 ancient, R 117 roman, M 1096 medieval, G 1300 mongol, T 1400 timurid, D 1492 discovery, U 1700 gunpowder,
N 1804 napoleonic, V 1850 victorian, W 1914 first world war, X 1939 second world war, C 1947 cold war. A province keeps its modern name in every era no rule names."""
ALL = "ARMGTDUNVWXC"
TO1500 = "ARMGTD"            # ... up to 1492
TO1700 = "ARMGTDU"
TO1804 = "ARMGTDUN"
TO1850 = "ARMGTDUNV"
TO1914 = "ARMGTDUNVW"
TO1939 = "ARMGTDUNVWX"
ANC = "AR"
MED = "MGT"
EARLY = "UNV"                # 1700 - 1850
RULES = []                   # (country, modern name, codes, english, russian, uzbek)
def E(cc, modern, codes, en, ru, uz):
    RULES.append((cc, modern, codes, en, ru, uz))
