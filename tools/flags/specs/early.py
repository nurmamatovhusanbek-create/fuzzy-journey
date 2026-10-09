import sys; sys.path.insert(0,'tools/flags')
from mkspec import *
B={  # banner/standard keys -> Commons candidates (heraldic banners, not national flags: these states had none)
'ottoman':D("Flag of the Ottoman Empire (1299–1844).svg","Flag of the Ottoman Empire (1453–1517).svg","Flag of the Ottoman Empire (1299-1844).svg","Flag of the Ottoman Empire.svg","Flag of the Ottoman Empire (1844–1922).svg"),
'france_k':D("Flag of the Kingdom of France (1814–1830).svg","Royal Banner of France (Ancien).svg","Royal banner of France (ancien).svg","Banner of the Kingdom of France (1328–1790).svg","Royal Standard of the King of France.svg","Flag of the Kingdom of France.svg"),
'france_old':D("Royal Banner of France (Ancien).svg","Royal banner of France (ancien).svg","Banner of France (Ancien).svg","Flag of the Kingdom of France.svg","Royal Standard of the King of France.svg"),
'england_ro':D("Royal Banner of England.svg","Royal Banner of the King of England.svg","Flag of England (1198–1340).svg","Royal Standard of England (1198–1340).svg"),
'england_ft':D("Royal Banner of England (1340–1603).svg","Royal Banner of England.svg","Banner of the Royal Arms of England (1399–1603).svg"),
'scotland':D("Royal Banner of Scotland.svg","Royal Standard of Scotland.svg","Flag of Scotland.svg"),
'castile':D("Pennon of the Crown of Castile.svg","Royal Banner of Castile.svg","Banner of arms of Castile.svg","Flag of the Crown of Castile.svg","Banner of the Crown of Castile.svg"),
'aragon':D("Flag of the Crown of Aragon.svg","Senyera Reial.svg","Flag of Aragon.svg"),
'hre':D("Flag of the Holy Roman Empire (1400–1806).svg","Flag of the Holy Roman Empire (1433–1806).svg","Flag of the Holy Roman Empire.svg","Flag of the Holy Roman Empire (1400-1806).svg"),
'hre_old':D("Flag of the Holy Roman Empire (1200–1400).svg","Imperial Banner of the Holy Roman Emperor (1200–1400).svg","Banner of the Holy Roman Empire (1200-1400).svg","Flag of the Holy Roman Empire (1400–1806).svg"),
'byz':D("Flag of the Palaiologos dynasty.svg","Flag of the Byzantine Empire.svg","Flag of the Byzantine Empire (Palaiologos).svg","Flag of the Byzantine Empire (1261–1453).svg","Palaiologos flag.svg"),
'teut':D("Flag of the Teutonic Order.svg","Flag of the Teutonic Knights.svg","Banner of the Teutonic Order.svg"),
'kalmar':D("Flag of the Kalmar Union.svg","Flag of the Kalmar Union (1397–1523).svg"),
'sweden':D("Flag of Sweden.svg"),
'denmark':D("Flag of Denmark.svg"),
'venice':D("Flag of the Republic of Venice.svg","Flag of Venice (1198–1798).svg","Flag of the Republic of Venice (1198-1797).svg"),
'papal':D("Flag of the Papal States (1808–1870).svg","Flag of the Papal States.svg","Flag of the Papal States (1825–1870).svg"),
'portugal':D("Flag of Portugal (1385–1485).svg","Flag of Portugal (1495–1521).svg","Flag of Portugal (1385-1485).svg","Flag of Portugal (1521–1578).svg","Flag of Portugal (1640–1667).svg"),
'poland':D("Flag of the Polish–Lithuanian Commonwealth.svg","Flag of the Polish-Lithuanian Commonwealth.svg","Flag of Poland (1385–1795).svg","Flag of the Kingdom of Poland (1385–1569).svg"),
'swiss':D("Flag of the Old Swiss Confederacy.svg","Flag of Switzerland (Pantone).svg","Flag of the Swiss Confederacy.svg","Banner of the Swiss Confederacy.svg"),
'netherlands':D("Flag of the Netherlands.svg","Flag of the Dutch Republic.svg"),
'hungary':D("Flag of Hungary (1301–1382?).svg","Flag of Hungary (1000–1301).svg","Flag of the Kingdom of Hungary (1301–1526).svg","Flag of Hungary (1301-1526).svg"),
'mongol':D("Flag of the Mongol Empire.svg","Flag of the Mongol Empire (1206-1368).svg","Flag of the Great Mongol Empire.svg","Nine white banners.svg"),
'golden':D("Flag of the Golden Horde.svg","Flag of the Golden Horde (1240s–1502).svg"),
'ilkhan':D("Flag of the Ilkhanate.svg","Flag of the Ilkhanate (1256-1335).svg"),
'chagatai':D("Flag of the Chagatai Khanate.svg","Flag of the Chagatai Khanate (1225-1687).svg"),
'timurid':D("Flag of the Timurid Empire.svg","Flag of the Timurid Dynasty.svg","Flag of Timur.svg","Flag of the Timurid Empire (1370–1507).svg"),
'mamluk':D("Flag of the Mamluk Sultanate (1250–1517).svg","Flag of the Mamluk Sultanate.svg","Flag of the Mamluk Sultanate (1250-1517).svg"),
'delhi':D("Flag of the Delhi Sultanate.svg","Flag of the Delhi Sultanate (1206–1526).svg"),
'mughal':D("Flag of the Mughal Empire.svg","Flag of the Mughal Empire (1526–1857).svg"),
'safavid':D("Flag of Safavid Iran.svg","Flag of Safavid Iran (1501–1736).svg","Flag of the Safavid Empire.svg","Flag of the Safavid dynasty.svg"),
'ming':D("Flag of Ming China.svg","Flag of the Ming dynasty.svg","Flag of the Ming Dynasty (1368–1644).svg","Flag of the Ming dynasty (1368-1644).svg"),
'qing':D("Flag of China (1889–1912).svg","Flag of the Qing dynasty (1644–1912).svg","Flag of the Qing dynasty (1862–1889).svg"),
'japan':D("Flag of Japan (1870–1999).svg","Flag of Japan.svg",note='The Hinomaru, in use as a war banner'),
'tokugawa':D("Flag of the Tokugawa Shogunate.svg","Flag of the Tokugawa clan.svg"),
'korea':D("Flag of Korea (1882–1910).svg","Flag of the Joseon Dynasty.svg"),
'ayutthaya':D("Flag of Ayutthaya.svg","Flag of Ayutthaya Kingdom.svg","Flag of the Ayutthaya Kingdom.svg"),
'ethiopia':D("Flag of Ethiopia (1897–1936, 1941–1974).svg"),
'inca':D("Flag of the Inca Empire.svg","Flag of the Inca Empire (1438–1533).svg","Flag of the Tawantinsuyu.svg"),
'aztec':D("Flag of the Aztec Empire.svg","Flag of the Aztec Triple Alliance.svg","Flag of the Aztec Empire (1428-1521).svg"),
'maori':D("Flag of the United Tribes of New Zealand.svg"),
'morocco':D("Flag of Morocco (1666–1915).svg","Flag of Morocco (1258–1915).svg"),
'tunis':D("Flag of the Hafsid dynasty.svg","Flag of the Hafsid Caliphate.svg"),
'grenada':D("Flag of the Emirate of Granada.svg","Flag of the Nasrid dynasty.svg","Flag of Granada (Nasrid).svg"),
'oman':D("Flag of Oman (1856–1970).svg"),
'moscow':D("Flag of the Grand Duchy of Moscow.svg","Flag of the Tsardom of Russia.svg","Flag of the Tsardom of Muscovy.svg","Flag of the Grand Principality of Moscow.svg"),
'sardinia':D("Flag of the Kingdom of Sardinia.svg","Flag of Sardinia (1720–1861).svg","Flag of Savoy.svg"),
'swedish':D("Flag of Sweden.svg"),
'burgundy':D("Flag of the Duchy of Burgundy.svg","Banner of the Dukes of Burgundy.svg"),
'brittany':D("Flag of Brittany (Gwenn ha du).svg","Flag of the Duchy of Brittany.svg","Ermine Banner.svg","Flag of Brittany (ermine).svg"),
'cyprus':D("Flag of the Kingdom of Cyprus.svg","Flag of Cyprus (1192–1489).svg","Flag of the Kingdom of Cyprus (1192-1489).svg"),
'georgia':D("Flag of Georgia (1008–1490).svg","Flag of the Kingdom of Georgia.svg","Flag of the Kingdom of Georgia (1008–1490).svg"),
'sicily':D("Flag of the Kingdom of Sicily.svg","Flag of Sicily (1130–1282).svg"),
'mali':{'emblem':True},'zimbabwe':{'emblem':True},
}
S={}
def put(era,**kw):
    S.setdefault(era,{}); S[era].update(kw)
# ---- 1700
put('gunpowder',safavid_empire=B['safavid'],mughal_empire=B['mughal'],ottoman_empire=B['ottoman'],france=B['france_old'],spanish_habsburg=D("Flag of Spain (1506–1701).svg","Flag of Spain (1700).svg","Flag of the Spanish Empire.svg","Flag of Cross of Burgundy.svg","Cross of Burgundy Flag.svg"),
 holy_roman_empire=B['hre'],austrian_empire=B['hre'],polish_lithuanian_commonwealth=B['poland'],portugal=B['portugal'],swiss_confederation=B['swiss'],manchu_empire=B['qing'],tibet=D("Flag of Tibet.svg"),
 sweden=B['sweden'],denmark_norway=B['denmark'],morocco=B['morocco'],ethiopia={'emblem':True},sardinia_piedmont=B['sardinia'],scottalnd=B['scotland'],england_and_ireland=D("Flag of England.svg","Flag of the Kingdom of Great Britain (1707–1800).svg"),england=D("Flag of England.svg"),
 netherlands=B['netherlands'],dutch_republic=B['netherlands'],papal_states=B['papal'],venice=B['venice'],tokugawa_shogunate=B['tokugawa'],tsardom_of_muscovy=B['moscow'],ayutthaya=B['ayutthaya'],korea=B['korea'],
 luxembourg=D("Flag of Luxembourg.svg"),prussia=D("Flag of Prussia (1701–1750).svg","Flag of Prussia (1701-1750).svg","Flag of Prussia (1750–1801).svg"),oman=B['oman'],maori={'emblem':True})
# ---- 1492
put('discovery',timurid_emirates=B['timurid'],chagatai_khanate=B['chagatai'],ottoman_empire=B['ottoman'],arago_n=B['aragon'],inca_empire=B['inca'],holy_roman_empire=B['hre'],poland_lithuania=B['poland'],imperial_hungary=B['hungary'],
 swiss_confederation=B['swiss'],ming_chinese_empire=B['ming'],cyprus=B['cyprus'],kalmar_union=B['kalmar'],hafsid_caliphate=B['tunis'],mamluke_sultanate=B['mamluk'],ethiopia=B['ethiopia'],castille=B['castile'],teutonic_knights=B['teut'],
 france=B['france_old'],britany=B['brittany'],scottland=B['scotland'],england=B['england_ft'],georgia=B['georgia'],venice=B['venice'],sultanate_of_delhi=B['delhi'],papal_states=B['papal'],japan=B['japan'],
 golden_horde=B['golden'],white_horde=B['golden'],ayutthaya=B['ayutthaya'],korea=B['korea'],aztec_empire=B['aztec'],denmark_norway=B['denmark'],portugal=B['portugal'],grand_duchy_of_moscow=B['moscow'],wattasid_caliphate=B['morocco'])
# ---- 1400
put('timurid',timurid_empire=B['timurid'],byzantine_empire=B['byz'],arago_n=B['aragon'],holy_roman_empire=B['hre'],mali={'emblem':True},sultanate_of_delhi=B['delhi'],ottoman_empire=B['ottoman'],hungary=B['hungary'],poland_lithuania=B['poland'],
 mongol_empire=B['mongol'],cyprus=B['cyprus'],kalmar_union=B['kalmar'],hafsid_caliphate=B['tunis'],mamluke_sultanate=B['mamluk'],castile=B['castile'],granada=B['grenada'],teutonic_knights=B['teut'],ethiopia=B['ethiopia'],
 france=B['france_old'],english_territory=B['england_ft'],britany=B['brittany'],scotland=B['scotland'],georgia=B['georgia'],sardinia=B['sardinia'],sicily=B['sicily'],papal_states=B['papal'],shogun_japan_kamakura=B['japan'],
 morocco=B['morocco'],portugal=B['portugal'],seljuk_caliphate=B['mamluk'])
# ---- 1300 / 1096 / 117 / -218 (heraldic banners where they exist)
put('mongol',ilkhanate=B['ilkhan'],golden_horde=B['golden'],mongol_empire=B['mongol'],chagatai_khanate=B['chagatai'],byzantine_empire=B['byz'],holy_roman_empire=B['hre_old'],mamluke_sultanate=B['mamluk'],sultanate_of_delhi=B['delhi'],france=B['france_old'],england=B['england_ro'],scotland=B['scotland'],castile=B['castile'],arago_n=B['aragon'],yuan_dynasty=B['mongol'],teutonic_knights=B['teut'],hungary=B['hungary'],papal_states=B['papal'],venice=B['venice'],georgia=B['georgia'],sicily=B['sicily'],cyprus=B['cyprus'],ethiopia=B['ethiopia'],hafsid_caliphate=B['tunis'],granada=B['grenada'],portugal=B['portugal'])
put('medieval',byzantine_empire=B['byz'],holy_roman_empire=B['hre_old'],france=B['france_old'],england=B['england_ro'],papal_states=B['papal'],hungary=B['hungary'],sicily=B['sicily'],georgia=B['georgia'],ethiopia=B['ethiopia'])
put('roman',roman_empire=D("Vexillum of the Roman Empire.svg","Flag of the Roman Empire.svg","Vexillum with SPQR.svg","Roman vexillum.svg","Vexillum (Roman).svg"),parthian_empire=D("Flag of the Parthian Empire.svg","Flag of Parthia.svg"),han_empire=D("Flag of the Han dynasty.svg","Flag of the Han Dynasty.svg"))
put('ancient',rome=D("Vexillum of the Roman Republic.svg","Vexillum of the Roman Empire.svg","Roman vexillum.svg","Vexillum with SPQR.svg","Flag of the Roman Republic.svg"),carthage=D("Flag of Carthage.svg","Flag of Ancient Carthage.svg"),ptolemaic_kingdom=D("Flag of the Ptolemaic Kingdom.svg","Flag of Ptolemaic Egypt.svg"),han_empire=D("Flag of the Han dynasty.svg"),mauryan_empire=D("Flag of the Maurya Empire.svg","Flag of the Mauryan Empire.svg"))
import os
for era,s in S.items(): save(era,s)
print({e:len(s) for e,s in S.items()})
