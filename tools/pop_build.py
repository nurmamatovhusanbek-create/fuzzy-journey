#!/usr/bin/env python3
"""Builds godot/data/pop_real.json: the REAL population (persons) of every province in every era, before the game's 30:1 / 20:1 / 10:1 scale and its random jitter.

Method (documented in docs/RULES5_REALISM.md):
  1. Modern (2024) population of every country (UN World Population Prospects, rounded, from memory: +-5 %), shared over the country's provinces by
     area^0.6 x lie of the land x climate x a fixed per-province "city" factor.
  2. Every other era: the population of each of 13 world regions (McEvedy & Jones, HYDE 3.x, Maddison, rounded, from memory: +-15 %) is shared over the
     provinces of that region by (modern population)^0.6 x (area, land, climate)^0.4, so a region's mass moves but its geography stays real.
Everything is approximate on purpose: each new game jitters every province again (+-20 %), so no two games hold the same figures.
Usage: python3 tools/pop_build.py
"""
import json, os, hashlib, math

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot')
W = json.load(open(os.path.join(ROOT, 'data/world.json')))
TERR = open(os.path.join(ROOT, 'data/terrain.bin'), 'rb').read()      # one byte per province: plains hills mountain forest marsh steppe
P = W['P']
ERAS = ['ancient', 'roman', 'medieval', 'mongol', 'timurid', 'discovery', 'gunpowder', 'napoleonic', 'victorian', 'ww1', 'ww2', 'coldwar', 'modern']
YEARS = [-218, 117, 1096, 1300, 1400, 1492, 1700, 1804, 1850, 1914, 1939, 1947, 2024]
SCALE = {'ancient': 10, 'roman': 10, 'medieval': 10, 'mongol': 10, 'timurid': 10, 'discovery': 10,
         'gunpowder': 20, 'napoleonic': 20, 'victorian': 20, 'ww1': 30, 'ww2': 30, 'coldwar': 30, 'modern': 30}

# ---- 2024, millions ---------------------------------------------------------------------------------------------------------------
POP2024 = dict(
 AFG=42, AGO=37, ALB=2.8, AND=.08, ARE=10, ARG=46, ARM=3.0, AUS=26.5, AUT=9.1, AZE=10.4, BDI=13, BEL=11.8, BEN=14, BFA=23, BGD=173, BGR=6.4, BHR=1.5, BHS=.4,
 BIH=3.2, BLR=9.2, BLZ=.41, BOL=12.4, BRA=217, BRN=.45, BTN=.79, BWA=2.6, CAF=5.7, CAN=40.1, CHE=8.9, CHL=19.6, CHN=1410, CIV=29, CMR=29, COD=102, COG=6.1,
 COL=52, COM=.85, CPV=.6, CRI=5.2, CUB=11, CYP=.95, CZE=10.9, DEU=84.5, DJI=1.1, DNK=5.9, DOM=11.3, DZA=46, ECU=18, EGY=112, ERI=3.7, ESP=48.4, EST=1.4,
 ETH=126, FIN=5.6, FJI=.93, FRA=68.4, GAB=2.4, GBR=68.3, GEO=3.7, GHA=34, GIN=14, GMB=2.8, GNB=2.2, GNQ=1.7, GRC=10.4, GRL=.057, GTM=18, GUY=.82, HKG=7.5,
 HND=10.7, HRV=3.9, HTI=11.7, HUN=9.6, IDN=279, IND=1428, IRL=5.3, IRN=89, IRQ=46, ISL=.39, ISR=9.8, ITA=59, JAM=2.8, JOR=11.3, JPN=123.5, KAZ=20, KEN=55,
 KGZ=7.2, KHM=17, KOR=51.7, KWT=4.3, LAO=7.6, LBN=5.4, LBR=5.4, LBY=7.0, LKA=22, LSO=2.3, LTU=2.9, LUX=.67, LVA=1.9, MAC=.7, MAR=37.8, MCO=.04, MDA=2.5,
 MDG=30.3, MDV=.52, MEX=128, MKD=1.8, MLI=23.3, MLT=.54, MMR=54, MNE=.62, MNG=3.4, MOZ=33.9, MRT=4.9, MUS=1.26, MWI=20.9, MYS=34.3, NAM=2.6, NER=27, NGA=223,
 NIC=7.0, NLD=17.9, NOR=5.5, NPL=30.9, NZL=5.2, OMN=4.6, PAK=240, PAN=4.4, PER=34, PHL=117, PNG=10.3, POL=36.6, PRK=26, PRT=10.4, PRY=6.9, QAT=2.7, ROU=19,
 RUS=144, RWA=14, SAU=36.9, SDN=48, SDS=11, SEN=17.8, SGP=5.9, SLE=8.6, SLV=6.3, SOM=18, SOL=6.2, SRB=6.7, STP=.23, SUR=.62, SVK=5.4, SVN=2.1, SWE=10.5, SWZ=1.2,
 SYR=23, TCD=18, TGO=9, THA=71.8, TJK=10, TKM=6.5, TLS=1.4, TTO=1.5, TUN=12.2, TUR=85, TWN=23.4, TZA=67, UGA=49, UKR=37, URY=3.4, USA=335, UZB=36, VEN=28,
 VNM=100, YEM=34, ZAF=62, ZMB=20.6, ZWE=16.7, KOS=1.7, PSX=5.4, SAH=.6, CYN=.4,
 ABW=.11, AIA=.016, ALD=.03, ASM=.045, ATG=.1, BLM=.01, BMU=.064, BRB=.28, CUW=.15, CYM=.07, FLK=.003, FRO=.054, FSM=.115, GGY=.067, GIB=.033, GRD=.125,
 GUM=.17, IMN=.084, JEY=.1, KIR=.13, KNA=.047, LCA=.18, LIE=.04, MAF=.032, MHL=.042, MNP=.05, MSR=.004, NCL=.27, NFK=.002, NIU=.002, NRU=.012, PLW=.018,
 PRI=3.2, PYF=.28, SHN=.006, SLB=.74, SMR=.034, SPM=.006, SXM=.04, SYC=.1, TCA=.046, TON=.1, TUV=.011, VAT=.0008, VCT=.1, VGB=.03, VIR=.1, VUT=.32, WLF=.011,
 WSM=.22, DMA=.07, COK=.017, KAB=.01, KAS=.01,
)

# ---- regions ------------------------------------------------------------------------------------------------------------------------
REG = {}
def reg(name, codes):
    for c in codes.split(): REG[c] = name
reg('EUW', 'GBR IRL FRA ESP PRT ITA DEU AUT CHE NLD BEL LUX DNK NOR SWE FIN ISL MLT AND MCO LIE SMR VAT GIB FRO IMN GGY JEY ALD')
reg('EUE', 'POL CZE SVK HUN ROU BGR GRC ALB MKD SRB MNE BIH HRV SVN KOS EST LVA LTU UKR BLR MDA')
reg('MEA', 'TUR IRN IRQ SYR LBN JOR ISR PSX SAU YEM OMN ARE QAT KWT BHR CYP CYN GEO ARM AZE')
reg('NAF', 'EGY LBY TUN DZA MAR SAH')
reg('SSA', 'AGO BDI BEN BFA BWA CAF CIV CMR COD COG COM CPV DJI ERI ETH GAB GHA GIN GMB GNB GNQ KEN LBR LSO MDG MLI MOZ MRT MUS MWI NAM NER NGA RWA SDN SDS SEN SLE SOL SOM STP SWZ SYC TCD TGO TZA UGA ZAF ZMB ZWE SHN')
reg('CAS', 'AFG KAZ KGZ TJK TKM UZB MNG')
reg('SAS', 'IND PAK BGD NPL BTN LKA MDV KAB KAS IOT')
reg('CHN', 'CHN TWN HKG MAC')
reg('JK', 'JPN KOR PRK')
reg('SEA', 'IDN MYS SGP BRN THA VNM LAO KHM MMR PHL TLS')
reg('NAM', 'USA CAN GRL BMU SPM')
reg('LAM', 'MEX GTM BLZ HND SLV NIC CRI PAN CUB JAM HTI DOM BHS BRB TTO ATG DMA GRD KNA LCA VCT ABW CUW SXM AIA VGB VIR CYM TCA MSR PRI BOL BRA CHL COL ECU GUY PRY PER SUR URY VEN ARG FLK BLM MAF CLP')
reg('OCE', 'ATA ATC ATF CSI ESB PGA SGS USG WSB AUS NZL PNG FJI SLB VUT NCL PYF WSM TON KIR TUV NRU MHL FSM PLW COK NIU PCN NFK WLF ASM GUM MNP UMI HMD IOA')
REGIONS = ['EUW', 'EUE', 'MEA', 'NAF', 'SSA', 'CAS', 'SAS', 'CHN', 'JK', 'SEA', 'NAM', 'LAM', 'OCE']
# world regions, millions, at YEARS[0..11] (the 2024 figure is the sum of the country table)
HIST = {
 'EUW': [18, 30, 28, 45, 38, 48, 70, 115, 150, 245, 275, 280],
 'EUE': [14, 28, 20, 30, 28, 36, 55, 85, 105, 175, 195, 180],
 'MEA': [25, 35, 28, 25, 24, 28, 35, 38, 40, 45, 55, 60],
 'NAF': [8, 12, 10, 10, 9, 10, 12, 14, 17, 26, 32, 35],
 'SSA': [16, 22, 30, 40, 45, 55, 72, 86, 90, 105, 155, 172],
 'CAS': [4, 6, 7, 6, 6, 6, 7, 8, 9, 18, 25, 27],
 'SAS': [45, 50, 75, 100, 100, 110, 165, 190, 215, 300, 345, 360],
 'CHN': [58, 58, 100, 80, 75, 105, 150, 320, 420, 450, 480, 530],
 'JK':  [3, 6, 10, 11, 11, 16, 42, 44, 46, 70, 95, 103],
 'SEA': [8, 10, 18, 20, 22, 25, 38, 45, 55, 100, 130, 140],
 'NAM': [1, 1.5, 2.5, 2, 2, 3, 2, 7, 26, 107, 142, 156],
 'LAM': [6, 8, 12, 17, 20, 30, 10, 21, 33, 80, 115, 135],
 'OCE': [1, 1, 1.2, 1.3, 1.4, 1.5, 1.7, 1.8, 2, 7, 9, 10],
}
UNIT_NOISE = lambda s: 0.6 + 1.1 * (int(hashlib.md5(s.encode()).hexdigest()[:8], 16) / 0xffffffff)          # the fixed "city" factor of a province, 0.6 .. 1.7

TERR_F = [1.30, 1.00, 0.45, 0.80, 0.60, 0.70]       # plains hills mountain forest marsh steppe

def climate(lat, lon):
    f = 1.0
    if lat > 70: f *= 0.15
    elif lat > 62: f *= 0.4
    elif lat < -55: f *= 0.1
    if 16 <= lat <= 31 and -17 <= lon <= 33: f *= 0.25                  # Sahara
    if 15 <= lat <= 28 and 38 <= lon <= 58: f *= 0.3                    # Arabian desert
    if -32 <= lat <= -18 and 118 <= lon <= 145: f *= 0.2                # Australian interior
    if 36 <= lat <= 46 and 85 <= lon <= 110: f *= 0.3                   # Taklamakan, Gobi
    return f

def region_of(p):
    c = W['natCode'][W['provNat'][p]]
    if c == 'RUS': return 'EUE' if W['lon'][p] < 60 else 'CAS'
    return REG.get(c)

geo = []
for p in range(P):
    c = W['natCode'][W['provNat'][p]]
    area = max(1.0, float(W['area'][p]))
    t = TERR[p] if p < len(TERR) else 0
    base = (area ** 0.6) * TERR_F[min(5, t)] * climate(W['lat'][p], W['lon'][p]) * UNIT_NOISE(W['id'][p])
    geo.append((c, base, region_of(p)))
missing = sorted({g[0] for g in geo if g[2] is None})
if missing: raise SystemExit('no region for ' + ' '.join(missing))
nopop = sorted({g[0] for g in geo if g[0] not in POP2024})
if nopop: print('no 2024 figure (treated as 2,000 people a province):', ' '.join(nopop))

# ---- 2024 per province ----------------------------------------------------------------------------------------------------------
tot_w = {}
for c, b, r in geo: tot_w[c] = tot_w.get(c, 0.0) + b
modern = []
for c, b, r in geo:
    m = POP2024.get(c)
    modern.append(max(500.0, (m * 1e6 * b / tot_w[c]) if m is not None else 2000.0))

# ---- every era ---------------------------------------------------------------------------------------------------------------------
out = {'scale': SCALE, 'years': dict(zip(ERAS, YEARS)), 'real': {}}
out['real']['modern'] = [int(round(float('%.3g' % v))) for v in modern]
reg_modern = {r: sum(modern[p] for p in range(P) if geo[p][2] == r) for r in REGIONS}
for i, era in enumerate(ERAS[:-1]):
    vs = []
    for p in range(P):
        c, b, r = geo[p]
        vs.append((modern[p] ** 0.6) * (b ** 0.4))
    reg_v = {r: sum(vs[p] for p in range(P) if geo[p][2] == r) for r in REGIONS}
    vals = []
    for p in range(P):
        r = geo[p][2]
        vals.append(max(300.0, HIST[r][i] * 1e6 * vs[p] / reg_v[r]))
    out['real'][era] = [int(round(float('%.3g' % v))) for v in vals]
json.dump(out, open(os.path.join(ROOT, 'data/pop_real.json'), 'w'), separators=(',', ':'))
print('wrote data/pop_real.json: %d provinces x %d eras, %d KB' % (P, len(ERAS), os.path.getsize(os.path.join(ROOT, 'data/pop_real.json')) // 1024))
for era in ERAS:
    print('%-11s world %7.1f M real   (game: %7.2f M people at %d:1)' % (era, sum(out['real'][era]) / 1e6, sum(out['real'][era]) / 1e6 / SCALE[era], SCALE[era]))
for c in ['FRA', 'DEU', 'CHN', 'IND', 'USA', 'EGY', 'ITA', 'TUR', 'IRN']:
    ps = [p for p in range(P) if geo[p][0] == c]
    print(c, ' '.join('%s=%.1f' % (e[:4], sum(out['real'][e][p] for p in ps) / 1e6) for e in ['ancient', 'roman', 'medieval', 'napoleonic', 'ww1', 'modern']))
