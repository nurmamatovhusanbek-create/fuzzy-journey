#!/usr/bin/env python3
"""Adds hand-written random events (EN+RU) to godot/data/events/random.json and reference/i18n/{en,ru}.js.
Idempotent: events whose id is already present are skipped. Run, then `node tools/i18n.mjs`."""
import json, os, re
ROOT = os.path.join(os.path.dirname(__file__), '..')
OPW = {'gold': ('{d} gold', '{d} золота'), 'manpower': ('{d} manpower', '{d} людей'), 'dp': ('{d} diplomacy points', '{d} очков дипломатии'),
       'stab': ('stability {d}', 'стабильность {d}'), 'research': ('{d} research', '{d} науки'), 'infamy': ('infamy {d}', 'дурная слава {d}'),
       'intel': ('{d} intel', '{d} разведки'), 'army': ('armies {d}%', 'армии {d}%'), 'dev': ('a province develops', 'провинция развивается'),
       'trade': ('{d} gold next turn', '{d} золота на след. ход')}
SCOPE = {'capital': (' (capital)', ' (столица)'), 'third': (' (a third of provinces)', ' (треть провинций)'), 'half': (' (half the provinces)', ' (половина провинций)')}
def fx(s):
    out = []
    for tok in s.split():
        if tok == 'dev': out.append({'op': 'dev'}); continue
        m = re.match(r'^([a-z]+)([+-]\d+)(?::(capital|third|half))?$', tok)
        k, v, sc = m.group(1), int(m.group(2)), m.group(3)
        if k == 'army': out.append({'op': 'army', 'pct': v, 'scope': sc or 'all'})
        elif k == 'trade': out.append({'op': 'bonus', 'kind': 'trade', 'amount': v})
        elif k == 'stab': out.append({'op': 'stab', 'd': v, 'scope': sc or 'all'})
        else: out.append({'op': k, 'd': v})
    return out
def desc(tokens, lang):
    parts = []
    for tok in tokens.split():
        if tok == 'dev': parts.append(OPW['dev'][lang]); continue
        m = re.match(r'^([a-z]+)([+-]\d+)(?::(capital|third|half))?$', tok)
        k, v, sc = m.group(1), int(m.group(2)), m.group(3)
        t = OPW[k][lang].replace('{d}', ('%+d' % v).replace('-', '−'))
        if sc: t += SCOPE[sc][lang]
        parts.append(t)
    return ' · '.join(parts) if parts else ('no cost' if lang == 0 else 'без затрат')
R = []
def X(id, cat, icon, cd, cond, t_en, t_ru, f_en, f_ru, ch):
    R.append((id, cat, icon, cd, cond, t_en, t_ru, f_en, f_ru, ch))
X('royal_wedding','DIPLOMACY','💍',12,[{'not_war':True},{'chance':0.3}],'A Royal Wedding','Королевская свадьба','A neighbouring court proposes a marriage that would ease the border and fill the palace with guests.','Соседний двор предлагает брак, который смягчит границу и наполнит дворец гостями.',
  [('Host a lavish wedding','Устроить пышную свадьбу','gold-60 dp+3 stab+4'),('Keep it modest','Скромная церемония','gold-15 stab+1')])
X('heresy','DOMESTIC','✝',10,[{'chance':0.25}],'Dissenting Preachers','Проповедники-раскольники','Wandering preachers draw crowds in the market squares and criticise the established order.','Странствующие проповедники собирают толпы на рынках и критикуют существующий порядок.',
  [('Suppress the preachers','Подавить проповедников','gold-20 stab+3 infamy+2'),('Tolerate dissent','Терпеть инакомыслие','stab-4 research+10')])
X('bandits','CRISIS','🗡',8,[{'chance':0.3}],'Brigands on the Roads','Разбойники на дорогах','Caravans are robbed and tax collectors turn back. The countryside wants a response.','Караваны грабят, сборщики налогов поворачивают назад. Деревня ждёт ответа.',
  [('Hire hunters and patrols','Нанять охотников и патрули','gold-40 stab+4'),('Ignore the problem','Не обращать внимания','gold-20 manpower-10 stab-3')])
X('famine','CRISIS','🌾',12,[{'chance':0.2},{'not_war':True}],'A Failed Harvest','Неурожай','Rain ruined the grain. Prices climb and the poor look to the granaries.','Дожди погубили зерно. Цены растут, бедняки смотрят на амбары.',
  [('Open the granaries','Открыть амбары','gold-50 stab-1'),('Let the market decide','Предоставить дело рынку','stab-8:third')])
X('great_fire','DISASTER','🔥',14,[{'chance':0.18}],'The Great Fire','Великий пожар','Fire sweeps the old wooden quarter of a major city. The ministers ask how to rebuild.','Огонь проходит по старому деревянному кварталу крупного города. Министры спрашивают, как отстраиваться.',
  [('Rebuild in stone','Отстроить из камня','gold-80 dev'),('Rebuild cheaply','Отстроить подешевле','gold-30 stab-4')])
X('gold_strike','TRADE','⛏',14,[{'chance':0.18}],'A Rich Strike','Богатая жила','Prospectors have found a seam of precious metal in the hills.','Старатели нашли в холмах жилу драгоценного металла.',
  [('Claim it for the crown','Присвоить короне','gold+120 stab-2'),('License prospectors','Выдавать лицензии','gold+60 trade+40')])
X('foreign_tutors','ENLIGHTENMENT','🎓',12,[{'chance':0.22},{'gold_min':60}],'Foreign Engineers','Иностранные инженеры','Skilled foreigners offer to teach your workshops and academies for a price.','Искусные иностранцы предлагают обучить ваши мастерские и академии за плату.',
  [('Hire the engineers','Нанять инженеров','gold-60 research+30'),('Rely on native talent','Положиться на своих','research+8')])
X('border_incident','MILITARY','⚔',8,[{'not_war':True},{'has_neighbors':True},{'chance':0.25}],'A Border Incident','Пограничный инцидент','Patrols have clashed with a neighbour\'s troops and each side accuses the other.','Патрули столкнулись с войсками соседа, и каждая сторона обвиняет другую.',
  [('Demand an apology','Потребовать извинений','dp-1 infamy+3 stab+2'),('Let it pass','Закрыть глаза','stab-2 dp+1')])
X('pretender','DOMESTIC','👑',12,[{'stab_below':50},{'chance':0.35}],'A Pretender Appears','Появление самозванца','A man claiming royal blood has gathered followers in the provinces.','Человек, называющий себя отпрыском царской крови, собрал сторонников в провинциях.',
  [('Imprison him','Заключить под стражу','stab+3 infamy+1'),('Buy his loyalty','Купить его верность','gold-70 stab+5')])
X('veterans','MILITARY','🎖',10,[{'at_war':True},{'chance':0.3}],'The Veterans Return','Возвращение ветеранов','Soldiers back from the front want land and pay.','Солдаты, вернувшиеся с фронта, хотят земли и жалованья.',
  [('Reward the veterans','Наградить ветеранов','gold-50 army+10'),('Pension them off','Отправить на пенсию','gold-20 stab+2')])
X('spy_ring','DIPLOMACY','🕵',12,[{'chance':0.2},{'gold_min':60}],'A Spy Network','Шпионская сеть','A merchant offers his far-flung agents to the crown as eyes and ears.','Купец предлагает короне своих разбросанных по свету агентов в качестве глаз и ушей.',
  [('Expand the network','Расширить сеть','gold-40 intel+4'),('Disband it','Распустить её','gold+20')])
X('great_library','ENLIGHTENMENT','📚',20,[{'era_min':1},{'gold_min':150},{'chance':0.2}],'A Great Library','Великая библиотека','Scholars petition the court to found a library to rival the ancient ones.','Учёные просят двор основать библиотеку, равную древним.',
  [('Found the library','Основать библиотеку','gold-120 research+40 dev'),('Spend on the army instead','Потратить на армию','gold-60 army+8')])
X('trade_embargo','TRADE','⛔',12,[{'chance':0.18},{'not_war':True}],'A Trade Embargo','Торговое эмбарго','A rival bans your goods from its ports. Merchants beg the crown to answer.','Соперник закрыл свои порты для ваших товаров. Купцы умоляют корону ответить.',
  [('Retaliate in kind','Ответить тем же','gold-30 infamy+2 dp-1'),('Endure it','Стерпеть','gold-60')])

def main():
    p = os.path.join(ROOT, 'godot', 'data', 'events', 'random.json')
    d = json.load(open(p, encoding='utf-8'))
    have = {e['id'] for e in d}
    en_lines = []; ru_lines = []; added = 0
    for (id, cat, icon, cd, cond, t_en, t_ru, f_en, f_ru, ch) in R:
        if id in have: continue
        added += 1
        d.append({'id': id, 'cat': cat, 'icon': icon, 'cooldown': cd, 'cond': cond, 'choices': [{'effects': fx(c[2])} for c in ch]})
        e = "  ev_%s_t: '%s', ev_%s_f: '%s',\n" % (id, t_en.replace("'", "\\'"), id, f_en.replace("'", "\\'"))
        r = "  ev_%s_t: '%s', ev_%s_f: '%s',\n" % (id, t_ru.replace("'", "\\'"), id, f_ru.replace("'", "\\'"))
        for i, c in enumerate(ch):
            e += "  ev_%s_c%d: '%s', ev_%s_d%d: '%s',\n" % (id, i, c[0].replace("'", "\\'"), id, i, desc(c[2], 0))
            r += "  ev_%s_c%d: '%s', ev_%s_d%d: '%s',\n" % (id, i, c[1].replace("'", "\\'"), id, i, desc(c[2], 1))
        en_lines.append(e); ru_lines.append(r)
    json.dump(d, open(p, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    for lang, lines in (('en', en_lines), ('ru', ru_lines)):
        f = os.path.join(ROOT, 'reference', 'i18n', lang + '.js'); s = open(f, encoding='utf-8').read()
        s = s.replace('  ev_worldwide:', ''.join(lines) + '  ev_worldwide:', 1); open(f, 'w', encoding='utf-8').write(s)
    print('added', added, 'random events; total', len(d))
main()
