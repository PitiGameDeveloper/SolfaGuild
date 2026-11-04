"""Simulación del addon sin el juego: carga el addon real en varios clientes con la API
de WoW falsa (mock.lua) y un mundo con reloj, guild, grupos y mensajes (world.py).
Prueba la lógica, no que Forever se comporte como aquí se supone, ni cómo se ve nada.

    python -m pip install -r tests/requirements.txt
    python tests/run.py

Se ejecuta dos veces: la segunda sin las funciones antiguas que Forever puede no tener.
Termina con error si falla algo.
"""
import os, sys, traceback
sys.stdout.reconfigure(encoding='utf-8')
from world import World

fails, passes = [], 0
def check(name, cond, detail=''):
    global passes
    if cond:
        passes += 1
        print('  ok   ', name)
    else:
        fails.append(name)
        print('  FALLO', name, detail)

def kills(c): return c.ret('SG:MyChar().kills') or 0
def team_keys(c):
    t = c.ret('SG:MyChar().teams')
    return sorted(k for k, _ in t.items()) if t else []
def no_errors(w, label):
    e = w.all_errors()
    check('%s: sin errores' % label, not e, str(e[:4]))

def hk(c, n=1):
    c.g.HK = c.ret('HK') + n
    c.fire('PLAYER_PVP_KILLS_CHANGED')

def base(forever=True, fmt=0):
    w = World(forever, fmt)
    def ch(cl, lvl): return {'class': cl, 'level': lvl}
    a = w.add('a', {'Ana Uno': ch('WARRIOR', 40)}, 'Ana Uno')
    b = w.add('b', {'Beto Dos': ch('MAGE', 40)}, 'Beto Dos')
    c = w.add('c', {'Ciro Tres': ch('ROGUE', 40)}, 'Ciro Tres')
    return w, a, b, c

# ------------------------------------------------------------------ nombres
def t_names(fmt):
    print('\n== Nombres y sincronización (formato de remitente %d) ==' % fmt)
    w, a, b, c = base(True, fmt)
    w.start()
    check('MyName con apellido', a.ret('SG:MyName()') == 'Ana Uno')
    for raw, want in [('Ana Uno-Reino', 'Ana Uno'), ('Ana-Uno-Reino', 'Ana Uno'), ('Ana-Uno', 'Ana Uno'), ('Ana Uno', 'Ana Uno')]:
        check('Short(%s)' % raw, a.ret('SG:Short(%r)' % raw) == want, a.ret('SG:Short(%r)' % raw))
    check('se ve en el roster', bool(a.ret('SG.roster["Beto Dos"] and SG.roster["Beto Dos"].online')))
    check('me reconozco en el roster', bool(a.ret('SG.roster[SG:MyName()] ~= nil')))
    check('ve la cuenta de otro', a.ret('SG:AccountOf("Beto Dos") ~= nil'))
    check('miembro de guild por remitente', a.ret('SG:IsGuildMember(%r)' % w.sender_raw('Beto Dos')))
    check('ningún susurro a nombre inválido', not w.failed_targets, str(w.failed_targets[:3]))
    no_errors(w, 'nombres')

def t_migration():
    print('\n== Migración de personaje guardado con nombre corto ==')
    w = World(True)
    a = w.add('a', {'Ana Uno': {'class': 'MAGE', 'level': 20}}, 'Ana Uno')
    a.ev('SolfaGuildDB.my.chars["Ana"] = { class = "MAGE", level = 20, kills = 7, guild = "Los Solfamidas", dungeons = {} }; SolfaGuildDB.my.chars["Ana Uno"] = nil; SolfaGuildDB.my.main = "Ana"')
    w.start(5)
    check('kills conservados', a.ret('SG.db.my.chars["Ana Uno"] and SG.db.my.chars["Ana Uno"].kills') == 7)
    check('nombre corto borrado', a.ret('SG.db.my.chars["Ana"] == nil'))
    check('main actualizado', a.ret('SG.db.my.main') == 'Ana Uno')
    no_errors(w, 'migración')

def t_chars():
    print('\n== Personajes borrados y vueltos a crear ==')
    def sync():
        w.push_roster()
        a.ev('SG:BroadcastProfile()')
        w.run(2)
    w = World(True)
    alt = {'class': 'ROGUE', 'level': 30}
    a = w.add('a', {'Ana Uno': {'class': 'MAGE', 'level': 20}, 'Ana Alt': alt}, 'Ana Uno')
    b = w.add('b', {'Beto Dos': {'class': 'MAGE', 'level': 20}}, 'Beto Dos')
    a.ev('SolfaGuildDB.my.main = "Ana Alt"; SolfaGuildDB.my.chars["Ana Alt"].kills = 5')
    w.start(12)
    def sees(c): return c.ret('SG:Accounts().a.chars["Ana Alt"] ~= nil')
    check('el alter sale en mi lista y en la de otro', sees(a) and sees(b))
    w.members.remove(('Ana Alt', alt))
    sync()
    check('borrado: desaparece de mi lista', not sees(a))
    check('borrado: desaparece de la de otro', not sees(b))
    check('borrado era el main: pasa a uno que existe', b.ret('SG:Accounts().a.main') == 'Ana Uno')
    check('sus datos no se tocan', a.ret('SG.db.my.chars["Ana Alt"].kills') == 5)
    a.ev('GetGuildRosterShowOffline = function() return false end')
    w.members.append(('Ana Alt', alt))
    sync()
    check('vuelve a la guild: vuelve a salir', sees(a) and sees(b))
    w.members.remove(('Ana Alt', alt))
    sync()
    check('desconectados ocultos: no se da por borrado', sees(a))
    a.ev('GetGuildRosterShowOffline = function() return true end')
    w.members = [m for m in w.members if m[0] != 'Ana Uno']
    sync()
    check('lista de la guild sin cargar: no se da por borrado', sees(a))
    no_errors(w, 'personajes borrados')

    print(' el perfil, cada minuto si cambia')
    w = World(True)
    a = w.add('a', {'Ana Uno': {'class': 'MAGE', 'level': 20}}, 'Ana Uno')
    b = w.add('b', {'Beto Dos': {'class': 'MAGE', 'level': 20}}, 'Beto Dos')
    w.start(12)
    def sends():
        return sum(1 for s in w.sent if s[0] == 'PROF' and s[1] == 'Ana Uno' and s[2] == 'GUILD')
    w.run(50)
    n = sends()
    w.run(100)
    check('sin cambios no se envía', sends() == n, (n, sends()))
    a.ev('SG:MyChar().kills = 5')
    w.run(61)
    check('con un cambio, llega en un minuto', sends() == n + 1 and b.ret('SG:Accounts().a.chars["Ana Uno"].kills') == 5, (n, sends()))
    n = sends()
    w.run(60)
    check('y no se repite', sends() == n, (n, sends()))
    w.run(25)
    check('cada 5 min se envía aunque no cambie', sends() == n + 1, (n, sends()))
    no_errors(w, 'perfil cada minuto')

    def login(saved):
        w = World(True)
        a = w.add('a', {'Ana Uno': {'class': 'MAGE', 'level': 20}}, 'Ana Uno')
        a.ev('local c = SolfaGuildDB.my.chars["Ana Uno"]; c.kills = 9; c.earned = 50; ' + saved)
        w.start(2)
        return a.ret('SG.db.my.chars["Ana Uno"].kills'), a.ret('SG.db.my.chars["Ana Uno"].guid')
    guid = 'Player-1-Ana'
    check('mismo identificador: mismos datos', login('c.guid = %r' % guid) == (9, guid))
    check('otro identificador: empieza de cero', login('c.guid = "Player-1-Viejo"') == (0, guid))
    check('otro reino: es un traslado, mismos datos', login('c.guid = "Player-2-Ana"') == (9, guid))
    check('sin identificador: mismos datos', login('') == (9, guid))
    check('sin identificador y otra clase: de cero', login('c.class = "ROGUE"') == (0, guid))
    check('sin identificador y nivel más alto: de cero', login('c.level = 40') == (0, guid))

# ------------------------------------------------------------------ PvP
def died(cs, guid, party_of=()):
    for c in cs:
        c.fire('UNIT_DIED', guid)
    for c in party_of:
        c.fire('PARTY_KILL', c.ret('UnitGUID("player")'), guid)

def t_pvp():
    print('\n== PvP en Forever ==')
    w, a, b, c = base(); w.start()
    check('Forever no registra el registro de combate', a.ret('#FORBIDDEN') == 0, a.ret('#FORBIDDEN'))
    for x in (a, b, c):
        x.g.PLAYERS['Player-9-Malo'] = x.rt.table_from({'class': 'PALADIN', 'race': 'Human', 'name': 'Malo Ali'})
        x.g.PLAYERS['Player-9-Feo'] = x.rt.table_from({'class': 'PRIEST', 'race': 'Dwarf', 'name': 'Feo Ali'})
        x.g.PLAYERS['Player-9-Otro'] = x.rt.table_from({'class': 'MAGE', 'race': 'Gnome', 'name': 'Otro Ali'})

    print(' parado al lado de una pelea ajena')
    n = len(w.sent)
    died((a, b, c), 'Player-9-Malo')
    w.run(10)
    check('no sube ninguna kill', (kills(a), kills(b), kills(c)) == (0, 0, 0))
    check('no avisa a nadie', not [s for s in w.sent[n:] if s[0] == 'PK'])

    print(' 2v2: los dos consiguen las dos muertes')
    died((a, b), 'Player-9-Malo', (a,))
    hk(a); hk(b)
    w.run(2)
    died((a, b), 'Player-9-Feo', (b,))
    hk(a); hk(b)
    print(' ...y a la vez Ciro mata a otro en un 1v1')
    died((c,), 'Player-9-Otro', (c,))
    hk(c)
    w.run(12)
    check('Ana 2 kills', kills(a) == 2, kills(a))
    check('Beto 2 kills', kills(b) == 2, kills(b))
    check('Ciro 1 kill', kills(c) == 1, kills(c))
    check('Ana: 2 asesinatos con Beto', a.ret('SG:MyChar().teams["Ana Uno,Beto Dos"]') == 2, team_keys(a))
    check('Ciro sin equipo', team_keys(c) == [], team_keys(c))
    check('Ana sin Ciro en equipos', 'Ciro' not in ''.join(team_keys(a)), team_keys(a))
    check('ventana: un equipo de 2 cuentas', a.ret('#SG.PvP:Teams(false)') == 1, a.ret('#SG.PvP:Teams(false)'))
    no_errors(w, 'PvP 2v2')

    print(' un nivel 60 ayuda a un nivel 20 (al 60 no le da honor)')
    w, a, b, c = base(); w.start()
    for x in (a, b):
        x.g.PLAYERS['Player-9-Malo'] = x.rt.table_from({'class': 'PALADIN', 'race': 'Human', 'name': 'Malo Ali'})
    died((a, b), 'Player-9-Malo', (a,))
    hk(a)
    w.run(10)
    check('al 20 le cuenta', kills(a) == 1)
    check('al 60 no le cuenta', kills(b) == 0)
    check('no es asesinato en grupo', team_keys(a) == [], team_keys(a))
    no_errors(w, 'PvP 20+60')

    print(' mismo segundo y misma zona, ids distintas')
    w, a, b, c = base(); w.start()
    for x in (a, b):
        x.g.PLAYERS['Player-9-Malo'] = x.rt.table_from({'class': 'PALADIN', 'race': 'Human', 'name': 'Malo Ali'})
        x.g.PLAYERS['Player-9-Feo'] = x.rt.table_from({'class': 'PRIEST', 'race': 'Dwarf', 'name': 'Feo Ali'})
    died((a,), 'Player-9-Malo', (a,)); died((b,), 'Player-9-Feo', (b,))
    hk(a); hk(b)
    w.run(10)
    check('una kill cada uno', (kills(a), kills(b)) == (1, 1))
    check('no hay equipo', team_keys(a) == [] and team_keys(b) == [], team_keys(a))

    print(' ids distintas aunque vayan en el mismo grupo')
    w, a, b, c = base(); w.start()
    for x in (a, b):
        x.g.PLAYERS['Player-9-Malo'] = x.rt.table_from({'class': 'PALADIN', 'race': 'Human', 'name': 'Malo Ali'})
        x.g.PLAYERS['Player-9-Feo'] = x.rt.table_from({'class': 'PRIEST', 'race': 'Dwarf', 'name': 'Feo Ali'})
    w.make_group(a, b)
    died((a,), 'Player-9-Malo', (a,)); died((b,), 'Player-9-Feo', (b,))
    hk(a); hk(b)
    w.run(10)
    check('no hay equipo', team_keys(a) == [], team_keys(a))

    print(' sin id: reserva por grupo y por objetivo')
    w, a, b, c = base(); w.start()
    w.make_group(a, b)
    hk(a); hk(b)
    w.run(10)
    check('mismo grupo sin id: equipo', a.ret('SG:MyChar().teams["Ana Uno,Beto Dos"]') == 1, team_keys(a))
    w, a, b, c = base(); w.start()
    a.set_unit('target', 'Malo', 'Ali'); b.set_unit('target', 'Malo', 'Ali')
    a.fire('PLAYER_TARGET_CHANGED'); b.fire('PLAYER_TARGET_CHANGED')
    hk(a); hk(b)
    w.run(10)
    check('mismo objetivo sin id: equipo', a.ret('SG:MyChar().teams["Ana Uno,Beto Dos"]') == 1, team_keys(a))
    w, a, b, c = base(); w.start()
    a.set_unit('target', 'Malo', 'Ali'); b.set_unit('target', 'Feo', 'Ali')
    a.fire('PLAYER_TARGET_CHANGED'); b.fire('PLAYER_TARGET_CHANGED')
    hk(a); hk(b)
    w.run(10)
    check('distinto objetivo sin id: sin equipo', team_keys(a) == [], team_keys(a))
    w, a, b, c = base(); w.start()
    hk(a); hk(b)
    w.run(10)
    check('sin nada en común: sin equipo', team_keys(a) == [] and kills(a) == 1, team_keys(a))
    no_errors(w, 'PvP reserva')

    print(' identificador oculto por el juego')
    w, a, b, c = base(); w.start()
    a.g.SECRETS['GUIDOCULTO'] = True
    a.fire('UNIT_DIED', 'GUIDOCULTO'); a.fire('PARTY_KILL', 'x', 'GUIDOCULTO')
    hk(a)
    w.run(10)
    check('kill cuenta igual', kills(a) == 1)
    no_errors(w, 'PvP oculto')

    print(' bandos: Skyborne, guild y muertes de mi facción')
    w, a, b, c = base(); w.start()
    a.g.PLAYERS['Player-9-Sky'] = a.rt.table_from({'class': 'DRUID', 'race': 'Skyborne', 'name': 'Sky Ali'})
    a.g.PLAYERS['Player-8-Horda'] = a.rt.table_from({'class': 'MAGE', 'race': 'Orc', 'name': 'Otro Horda'})
    a.g.PLAYERS['Player-8-Sky'] = a.rt.table_from({'class': 'DRUID', 'race': 'Skyborne', 'name': 'Sky Horda'})
    a.g.PLAYERS['Player-1-Beto'] = a.rt.table_from({'class': 'MAGE', 'race': 'Skyborne', 'name': 'Beto Dos'})
    a.ev('SG.db.debug = true')
    a.fire('UNIT_DIED', 'Player-8-Horda')
    a.fire('UNIT_DIED', 'Player-1-Beto')
    a.set_unit('nameplate1', 'Sky', 'Horda', faction='Horde', guid='Player-8-Sky')
    a.fire('UNIT_DIED', 'Player-8-Sky')
    a.clear_unit('nameplate1')
    w.run(1)
    hk(a)
    w.run(3)
    last = [p for p in a.prints if 'Muerte honorable' in p][-1]
    check('orco, compañero y Skyborne de mi bando: descartados', 'ninguno' in last.split('objetivo')[0], last)
    a.fire('UNIT_DIED', 'Player-9-Sky')
    hk(a)
    w.run(3)
    last = [p for p in a.prints if 'Muerte honorable' in p][-1]
    check('Skyborne enemigo: asignado', 'Player-9-Sky' in last, last)
    check('las dos kills cuentan', kills(a) == 2, kills(a))
    no_errors(w, 'PvP bandos')

    print(' en instancia no cuenta; el contador no salta al entrar')
    w, a, b, c = base(); w.start()
    a.g.INST, a.g.INST_KIND = True, 'pvp'
    hk(a)
    w.run(3)
    a.g.INST, a.g.INST_KIND = False, 'none'
    check('en campo de batalla: 0', kills(a) == 0)
    hk(a)
    w.run(3)
    check('siguiente en mundo abierto: 1 (no 2)', kills(a) == 1, kills(a))
    hk(a, 2)
    w.run(3)
    check('contador sube de 2 en 2: suma 2', kills(a) == 3, kills(a))
    no_errors(w, 'PvP instancia')

    print(' /sg debug y escalafón')
    w, a, b, c = base(); w.start()
    a.ev('SG.db.debug = true')
    a.g.PLAYERS['Player-9-Malo'] = a.rt.table_from({'class': 'PALADIN', 'race': 'Human', 'name': 'Malo Ali'})
    died((a,), 'Player-9-Malo', (a,))
    hk(a)
    w.run(3)
    check('debug enseña la id', any('Player-9-Malo' in p for p in a.prints), a.prints[-3:])
    check('sale en el escalafón', a.ret('#SG.PvP:Ladder(false)') == 1)
    check('rango del escalafón', a.ret('SG.PvP:LadderRankOf(SG:MyAccount())') is not None)
    no_errors(w, 'PvP debug')

def t_pvp_ladder():
    print('\n== Escalafón PvP: Jefe de guerra y Peón ==')
    w = World(True)
    cs = [w.add(k, {n: {'class': 'MAGE', 'level': 20}}, n) for k, n in (('a', 'Ana Uno'), ('b', 'Beto Dos'), ('c', 'Cati Tres'), ('d', 'Dani Cuatro'))]
    a, b, c, d = cs
    w.start(12)
    rank = lambda who, acc: who.ret('SG.PvP:LadderRankOf(SG:Accounts().%s)' % acc)
    check('sin asesinatos: Peón', rank(a, 'a') == 'Peón', rank(a, 'a'))
    for cl, kills in ((a, 3), (b, 10), (c, 1)):
        cl.ev('SG:MyChar().kills = %d; SG:BroadcastProfile()' % kills)
    w.run(5)
    check('el que más tiene, Jefe de guerra', rank(a, 'b') == 'Jefe de guerra', rank(a, 'b'))
    check('el resto, Peón', rank(a, 'a') == 'Peón' and rank(a, 'c') == 'Peón', (rank(a, 'a'), rank(a, 'c')))
    check('todos ven lo mismo', rank(c, 'b') == 'Jefe de guerra' and rank(b, 'a') == 'Peón')
    check('sin asesinatos sigue siendo Peón', rank(d, 'd') == 'Peón', rank(d, 'd'))
    check('solo dos rangos', a.ret('#SG.PvP:Ladder(false)') == 2)
    check('el de PvE no cambia: sin mazmorras, sin rango', a.ret('SG.DungeonTracker:LadderRankOf(SG:MyAccount())') is None)
    no_errors(w, 'escalafón PvP')

# ------------------------------------------------------------------ Classic
def t_classic():
    print('\n== Classic Era sigue con el registro de combate ==')
    w = World(False)
    a = w.add('a', {'Ana': {'class': 'WARRIOR', 'level': 40}}, 'Ana')
    b = w.add('b', {'Beto': {'class': 'MAGE', 'level': 40}}, 'Beto')
    w.start()
    check('nombre sin apellido', a.ret('SG:MyName()') == 'Ana')
    check('Short quita el reino', a.ret('SG:Short("Ana-Reino")') == 'Ana')
    check('HasCombatLog', a.ret('SG.HasCombatLog') is True)
    me = a.ret('UnitGUID("player")')
    flags_me, enemy = 0x1 | 0x400, 0x400 | 0x40
    def cl(sub, src, sf, dst, dn, df):
        a.rt.execute('CL_EVENT = {0, %r, false, %r, "x", %d, 0, %r, %r, %d}' % (sub, src, sf, dst, dn, df))
        a.fire('COMBAT_LOG_EVENT_UNFILTERED')
    cl('SWING_DAMAGE', me, flags_me, 'Player-9-M', 'Malo', enemy)
    cl('UNIT_DIED', '', 0, 'Player-9-M', 'Malo', enemy)
    w.run(1)
    check('asesinato contado', kills(a) == 1, kills(a))
    no_errors(w, 'Classic')

# ------------------------------------------------------------------ SOS
def t_sos():
    print('\n== SOS por campeo en Forever ==')
    w, a, b, c = base(); w.start()
    def recap(guid, name):
        a.rt.execute('RECAP = { { timestamp = 1, sourceGUID = "x", sourceName = "viejo" }, { timestamp = %d, sourceGUID = %r, sourceName = %r } }' % (int(w.now) + 2, guid, name))
    print(' un monstruo te mata')
    recap('Creature-0-1-1-1-100-1', 'Lobo')
    a.fire('PLAYER_DEAD'); w.run(35)
    a.fire('PLAYER_DEAD'); w.run(35)
    check('no pregunta', not a.shown('SolfaGuildCampAsk'))
    print(' un jugador te mata dos veces; el juego repite PLAYER_DEAD al liberar')
    recap('Player-9-Malo', 'Malo-Ali')
    a.fire('PLAYER_DEAD'); w.run(2)
    a.fire('PLAYER_DEAD'); w.run(2)
    check('una muerte no basta', not a.shown('SolfaGuildCampAsk'))
    w.run(30)
    a.fire('PLAYER_DEAD'); w.run(2)
    check('a las 2 muertes pregunta', a.shown('SolfaGuildCampAsk'))
    txt = a.ret('SolfaGuildCampAsk.text:GetText()')
    check('nombra al asesino', 'Malo Ali' in txt, txt)
    print(' pide refuerzos y acude Beto, que está en otro grupo')
    w.make_group(b, c)
    a.ev('SolfaGuildCampAsk.yes:Click()')
    w.run(2)
    check('a Beto le sale el aviso', b.shown('SolfaGuildCampCall'))
    b.ev('SolfaGuildCampCall.yes:Click()')
    w.run(3)
    check('Beto ha salido de su grupo', w.group_of(c) is None or b not in w.group_of(c)['members'])
    check('Beto está con Ana', w.group_of(a) is not None and b in w.group_of(a)['members'], w.invite_targets)
    check('invitación con nombre válido', not w.failed_targets, w.failed_targets)
    no_errors(w, 'SOS')
    print(' resumen vacío u oculto')
    w, a, b, c = base(); w.start()
    a.fire('PLAYER_DEAD'); w.run(35); a.fire('PLAYER_DEAD'); w.run(2)
    check('sin resumen no cuenta', not a.shown('SolfaGuildCampAsk'))
    a.g.SECRETS['OCULTO'] = True
    a.rt.execute('RECAP = { { timestamp = 5, sourceGUID = "OCULTO", sourceName = "OCULTO" } }')
    w.run(35); a.fire('PLAYER_DEAD'); w.run(2)
    check('GUID oculto no cuenta', not a.shown('SolfaGuildCampAsk'))
    a.rt.execute('RECAP = { { timestamp = 5, sourceGUID = "Player-9-M", sourceName = "OCULTO" } }')
    w.run(35); a.fire('PLAYER_DEAD'); w.run(2)
    w.run(35); a.fire('PLAYER_DEAD'); w.run(2)
    check('nombre oculto cuenta con "?"', a.shown('SolfaGuildCampAsk'))
    no_errors(w, 'SOS oculto')

# ------------------------------------------------------------------ LFS
def lfs_world(fmt=0):
    w = World(True, fmt)
    def ch(cl, lvl, done=()): return {'class': cl, 'level': lvl, 'done': list(done)}
    L = w.add('L', {'Lider Uno': ch('WARLOCK', 20)}, 'Lider Uno')
    B = w.add('B', {'Tanque Dos': ch('WARRIOR', 20)}, 'Tanque Dos')
    M = w.add('M', {'Mago Tres': ch('MAGE', 21)}, 'Mago Tres')
    G = w.add('G', {'Mini Siete': ch('WARRIOR', 8), 'Druida Siete': ch('DRUID', 19)}, 'Mini Siete')
    C = w.add('C', {'Cura Cuatro': ch('PRIEST', 18, ['vc'])}, 'Cura Cuatro')
    E = w.add('E', {'Rogue Cinco': ch('ROGUE', 60)}, 'Rogue Cinco')
    F = w.add('F', {'Bajo Seis': ch('PALADIN', 5)}, 'Bajo Seis')
    O = w.add('O', {'Otro Ocho': ch('MAGE', 40)}, 'Otro Ocho')
    N = w.add('N', {'Sinad Nueve': ch('WARRIOR', 20)}, 'Sinad Nueve', has_addon=False)
    return w, L, B, M, G, C, E, F, O, N

def offer(c): return c.shown('SolfaGuildLFSOffer')
def radios(c):
    out = {}
    for i in range(1, 4):
        if c.ret('SolfaGuildLFSOffer.radios[%d]:IsShown()' % i):
            out[c.ret('SolfaGuildLFSOffer.radios[%d].role' % i)] = i
    return out
def pick(c, role):
    c.ev('SolfaGuildLFSOffer.radios[%d]:Click()' % radios(c)[role])
def yes(c): c.ev('SolfaGuildLFSOffer.yes:Click()')
def no(c): c.ev('SolfaGuildLFSOffer.no:Click()')
def start(L, t=1, h=1, d=2, dg='vc'):
    return L.rt.eval('(function() local ok, why = SG.LFS:Start(SG.DungeonById[%r], { T = %d, H = %d, D = %d }); return ok, why end)()' % (dg, t, h, d))

def t_lfs(fmt=0):
    print('\n== LFS completo (Minas 17-26: tanque, sanador, 2 DPS; remitente %d) ==' % fmt)
    w, L, B, M, G, C, E, F, O, N = lfs_world(fmt); w.start()
    names = lambda need: [L.ret('SG.LFS:Candidates(SG.DungeonById.vc, %s)[%d].char' % (need, i)) for i in range(1, L.ret('#SG.LFS:Candidates(SG.DungeonById.vc, %s)' % need) + 1)]
    order = names('{T=1,H=1,D=2}')
    print('   orden:', order)
    check('prioridad: en rango sin hacer > hecha > por encima', order == ['Tanque Dos', 'Mago Tres', 'Druida Siete', 'Cura Cuatro', 'Otro Ocho', 'Rogue Cinco'], order)
    check('por debajo del mínimo, nunca', 'Bajo Seis' not in order and 'Mini Siete' not in order)
    check('sin addon, nunca', 'Sinad Nueve' not in order)
    w.make_group(B, O)
    ok = start(L)
    check('arranca', ok is True or (isinstance(ok, tuple) and ok[0] is True), ok)
    w.run(1)
    print(' 1) oferta a Tanque Dos, que está en otro grupo')
    check('le sale la oferta', offer(B))
    check('solo una oferta a la vez', not offer(M) and not offer(C) and not offer(E))
    check('guerrero: tanque o DPS', sorted(radios(B)) == ['D', 'T'], radios(B))
    check('sin marcar no se puede aceptar', B.ret('SolfaGuildLFSOffer.yes:IsEnabled()') is False)
    text = B.ret('SolfaGuildLFSOffer.text:GetText()')
    check('texto con mazmorra, personaje y aviso', 'Minas' in text and 'Tanque Dos' in text and '20' in text and 'echará' in text, text)
    pick(B, 'T'); yes(B)
    w.run(2)
    check('ha salido de su grupo', B not in (w.group_of(O) or {'members': []})['members'])
    check('está en el grupo del líder', w.group_of(L) and B in w.group_of(L)['members'], (w.invite_targets, w.failed_targets, L.prints[-3:]))
    print(' 2) falta sanador y 2 DPS: rechaza el mago')
    check('le toca al mago', offer(M))
    check('mago: solo DPS y ya marcado', list(radios(M)) == ['D'] and M.ret('SolfaGuildLFSOffer.radios[1]:GetChecked()') is True, radios(M))
    check('puede aceptar sin tocar nada', M.ret('SolfaGuildLFSOffer.yes:IsEnabled()') is True)
    no(M)
    w.run(1)
    print(' 3) el alter de otro jugador: druida, ya sin opción de tanque')
    check('le toca a la cuenta del druida', offer(G))
    check('sin tanque en las opciones', sorted(radios(G)) == ['D', 'H'], radios(G))
    gt = G.ret('SolfaGuildLFSOffer.text:GetText()')
    check('le dice que entre con el alter', 'Druida Siete' in gt and 'entrar con' in gt, gt)
    pick(G, 'H'); yes(G)
    w.run(2)
    check('plaza guardada, no se invita aún', G not in w.group_of(L)['members'])
    check('pendiente guardado', G.ret('SG.db.my.lfsPending ~= nil'))
    print(' 4) solo faltan 2 DPS: dos ofertas a la vez')
    check('oferta a Cura', offer(C))
    check('oferta a la siguiente cuenta', offer(O))
    check('Rogue aún no', not offer(E))
    check('sanador sin opción de curar', list(radios(C)) == ['D'], radios(C))
    yes(C); yes(O)
    w.run(2)
    check('Cura dentro', C in w.group_of(L)['members'])
    check('Otro dentro', O in w.group_of(L)['members'])
    check('Rogue nunca recibió oferta', not offer(E))
    print(' 5) entra con el alter')
    check('aún no ha acabado', L.ret('SG.LFS:Run() ~= nil'))
    w.switch_char(G, 'Druida Siete')
    w.run(8)
    check('alter dentro', G in w.group_of(L)['members'], L.prints[-3:])
    check('grupo de 5', len(w.group_of(L)['members']) == 5, len(w.group_of(L)['members']))
    w.run(2)
    check('búsqueda acabada', L.ret('SG.LFS:Run() == nil'))
    check('mensaje de grupo completo', any('completo' in p for p in L.prints), L.prints[-2:])
    check('sin destinos inválidos', not w.failed_targets, w.failed_targets[:3])
    no_errors(w, 'LFS completo')

def t_lfs_edges():
    print('\n== LFS: casos raros ==')
    w, L, B, M, G, C, E, F, O, N = lfs_world(); w.start()
    print(' no contesta nadie: pasa al siguiente a los 30 s')
    start(L, 1, 0, 0)
    w.run(1)
    check('Tanque Dos tiene oferta', offer(B))
    w.run(36)
    check('se le cierra la ventana', not offer(B))
    check('pasa a otro', offer(G) or offer(C) or offer(E), L.ret('SG.LFS:Run() ~= nil'))
    L.ev('SG.LFS:Cancel()')
    w.run(1)
    check('cancelar cierra las ofertas', not (offer(G) or offer(C) or offer(E)))
    check('sin búsqueda', L.ret('SG.LFS:Run() == nil'))
    no_errors(w, 'LFS sin respuesta')

    print(' cliente sin respuesta: se salta en 5 s')
    w, L, B, M, G, C, E, F, O, N = lfs_world(); w.start()
    B.has_addon = False
    start(L, 1, 0, 0)
    w.run(7)
    check('pasa al siguiente enseguida', offer(G), L.prints[-2:])
    L.ev('SG.LFS:Cancel()')

    print(' en combate o en instancia: se salta')
    w, L, B, M, G, C, E, F, O, N = lfs_world(); w.start()
    B.g.COMBAT = True
    start(L, 1, 0, 0)
    w.run(1)
    check('en combate no ve la oferta', not offer(B))
    check('siguiente', offer(G))
    L.ev('SG.LFS:Cancel()')
    w.run(1)
    B.g.COMBAT = False
    B.g.INST = True
    M.g.INST = True
    start(L, 0, 0, 1)
    w.run(1)
    check('en instancia no ve la oferta', not offer(B) and not offer(M))
    L.ev('SG.LFS:Cancel()')

    print(' reglas de inicio')
    w, L, B, M, G, C, E, F, O, N = lfs_world(); w.start()
    w.make_group(M, L)
    r = L.rt.eval('(function() local ok, why = SG.LFS:Start(SG.DungeonById.vc, {T=1,H=0,D=0}); return why end)()')
    check('sin ser líder no deja', r and 'líder' in r, r)
    w.leave(L)
    w.run(1)
    r = L.rt.eval('(function() local ok, why = SG.LFS:Start(SG.DungeonById.vc, {T=0,H=0,D=0}); return why end)()')
    check('sin elegir nada no deja', r and 'Elige' in r, r)
    r = L.rt.eval('(function() local ok, why = SG.LFS:Start(SG.DungeonById.vc, {T=1,H=1,D=3}); return why end)()')
    check('más de 4 no deja', r and 'plazas' in r, r)
    w.make_group(L, M, E, C)
    w.run(1)
    r = L.rt.eval('(function() local ok, why = SG.LFS:Start(SG.DungeonById.vc, {T=1,H=1,D=0}); return why end)()')
    check('con 4 en grupo solo queda 1 plaza', r and 'plazas' in r, r)
    no_errors(w, 'LFS inicio')

    print(' sin candidatos a mitad: acaba y avisa')
    w, L, B, M, G, C, E, F, O, N = lfs_world(); w.start()
    start(L, 1, 0, 0)
    for x in (B, G):
        w.run(1)
        check('oferta', offer(x))
        no(x)
    w.run(1)
    check('sin más candidatos: acaba', L.ret('SG.LFS:Run() == nil'))
    check('avisa', any('No queda' in p for p in L.prints), L.prints[-2:])

    print(' dos líderes buscan a la vez: una sola ventana')
    w, L, B, M, G, C, E, F, O, N = lfs_world(); w.start()
    start(L, 1, 0, 0)
    w.run(1)
    start(E, 1, 0, 0, 'vc')
    w.run(1)
    check('Tanque no recibe dos a la vez', offer(B))
    check('E pasó a otro', offer(G), E.prints[-2:])
    no_errors(w, 'dos líderes')

    print(' el alter no llega a tiempo: se reabre la plaza')
    w, L, B, M, G, C, E, F, O, N = lfs_world(); w.start()
    L.ev('SG:Cfg().lfsRelogTime = 1')
    start(L, 0, 1, 0)
    w.run(1)
    check('oferta al druida', offer(G), L.prints[-2:])
    pick(G, 'H'); yes(G)
    w.run(2)
    check('plaza reservada', L.ret('SG.LFS:Run().need.H') == 0)
    w.run(62)
    check('avisa y sigue buscando', any('a tiempo' in p for p in L.prints), L.prints[-2:])
    check('oferta a otro sanador', offer(C))
    no_errors(w, 'LFS alter tarde')

def t_lfs_send():
    print('\n== LFS: 2 DPS a la vez, también con el juego limitando mensajes ==')
    def world():
        w = World(True)
        L = w.add('L', {'Lider Uno': {'class': 'WARLOCK', 'level': 20}}, 'Lider Uno')
        M = w.add('M', {'Mago Dos': {'class': 'MAGE', 'level': 20}}, 'Mago Dos')
        R = w.add('R', {'Picaro Tres': {'class': 'ROGUE', 'level': 20}}, 'Picaro Tres')
        w.start()
        return w, L, M, R
    limit = 'local o = C_ChatInfo.SendAddonMessage; __n = %d; C_ChatInfo.SendAddonMessage = function(...) if __n > 0 then __n = __n - 1; return %s end; return o(...) end'

    w, L, M, R = world()
    L.ev('SG.UILFS:OpenSearch(SG.DungeonById.vc)')
    S = 'SolfaGuildLFSSearch'
    L.ev('for _ = 1, 2 do %s.D:GetScript("OnClick")(%s.D, "LeftButton") end; %s.go:Click()' % (S, S, S))
    w.run(1)
    check('desde la ventana: dos ofertas a la vez', offer(M) and offer(R), L.ret(S + '.why:GetText()'))
    no_errors(w, 'dos ofertas')

    w, L, M, R = world()
    L.ev(limit % (3, '3'))
    start(L, 0, 0, 2)
    w.run(4)
    check('el juego limita los mensajes: llegan las dos', offer(M) and offer(R))

    w, L, M, R = world()
    L.ev(limit % (2, 'false'))
    start(L, 0, 0, 2)
    w.run(3)
    check('cliente que da false: también llegan', offer(M) and offer(R))

    w, L, M, R = world()
    L.ev(limit % (5, '3'))
    start(L, 0, 0, 2)
    w.run(8)
    check('si un mensaje no sale nunca, la cola sigue', L.ret('SG.Comm:QueueSize()') == 0 and (offer(M) or offer(R)))

    w, L, M, R = world()
    L.ev('SG.Comm:Send({ t = "PRUEBA", x = string.rep("a", 5000) })')
    start(L, 0, 0, 2)
    w.run(0.5)
    check('las ofertas adelantan a un perfil largo', offer(M) and offer(R) and L.ret('SG.Comm:QueueSize()') > 0, L.ret('SG.Comm:QueueSize()'))
    w.run(8)
    check('y el mensaje largo sale después', L.ret('SG.Comm:QueueSize()') == 0, L.ret('SG.Comm:QueueSize()'))
    no_errors(w, 'mensajes limitados')

# ------------------------------------------------------------------ UI
def t_ui():
    print('\n== Interfaz ==')
    w = World(True)
    a = w.add('a', {'Ana Uno': {'class': 'WARRIOR', 'level': 30, 'done': ['vc', 'dalaran']}}, 'Ana Uno')
    b = w.add('b', {'Beto Dos': {'class': 'MAGE', 'level': 30, 'gm': True}}, 'Beto Dos')
    w.start()
    a.rt.execute('''
        local o = SG.UILFS.BuildPanel
        SG.UILFS.BuildPanel = function(s, p) __panel = o(s, p); __pve = p; return __panel end
    ''')
    a.ev('SG.UI:Show("profile")')
    for tab in ('pvp', 'dungeons', 'cositas', 'events', 'admin', 'profile'):
        a.ev('SG.UI:Show(%r)' % tab)
    check('todas las pestañas sin error', not a.errors and not [p for p in a.prints if 'error:' in p], (a.errors[:2], a.prints[-2:]))
    a.ev('SG.UI:Show("dungeons")')
    check('conectados en la ventana', a.ret('SolfaGuildFrame.onlineCount:GetText()') == 2, a.ret('SolfaGuildFrame.onlineCount:GetText()'))
    a.ev('SolfaGuildFrame.online:GetScript("OnEnter")(SolfaGuildFrame.online)')
    check('tooltip de conectados', a.ret('GameTooltip:GetText()') == 'Solfamiders conectados', a.ret('GameTooltip:GetText()'))
    a.ev('SolfaGuildFrame.online:GetScript("OnLeave")(SolfaGuildFrame.online)')
    check('modos Total, Semanal, LFS', a.ret('#__pve.modeButtons') == 3)
    a.ev('__pve:Refresh()')
    check('panel LFS oculto en Total', a.ret('__panel:IsShown()') is False)
    check('lista visible en Total', a.ret('__pve.list:IsShown()') is True)
    a.ev('__pve.modeButtons[3]:Click()')
    check('al pulsar LFS se ve', a.ret('__panel:IsShown()') is True)
    check('la lista se oculta', a.ret('__pve.list:IsShown()') is False)
    w.run(0.2)
    n = a.ret('#__panel.cards')
    check('todas las mazmorras', n == a.ret('#SG.Dungeons') and n == 35, n)
    cards = [(a.ret('__panel.cards[%d].name:GetText()' % i), a.ret('__panel.cards[%d]:IsEnabled()' % i),
              a.ret('__panel.cards[%d].tick:IsShown()' % i), a.ret('__panel.cards[%d]._point[3]' % i)) for i in range(1, n + 1)]
    firstopen = next(i for i, c in enumerate(cards) if c[1])
    print('   primera disponible:', cards[firstopen][0], 'y', cards[firstopen][3])
    mins = [a.ret('SG.Dungeons[%d].min' % i) for i in range(1, n + 1)]
    check('primera disponible es la más alta a nivel 30 (mínimo 29)', cards[firstopen][0] in ('Gnomeregan','Horado Rajacieno'), cards[firstopen][0])
    vs = a.ret('__panel.scroll:GetVerticalScroll()')
    check('scroll = fila de la primera', abs(vs + a.ret('__panel.cards[%d]._point[3]' % (firstopen + 1))) < 1, (vs, a.ret('__panel.cards[%d]._point[3]' % (firstopen + 1))))
    slots = {(a.ret('__panel.cards[%d]._point[2]' % i), a.ret('__panel.cards[%d]._point[3]' % i)) for i in range(1, n + 1)}
    check('la primera mazmorra, en fila 1 y columna 1', (a.ret('__panel.cards[1]._point[2]'), a.ret('__panel.cards[1]._point[3]')) == (0, 0))
    check('la rejilla no deja huecos', len(slots) == n and len({y for _, y in slots}) == (n + 1) // 2, sorted(slots))
    art = {c[0]: a.ret('__panel.cards[%d].art:IsShown()' % (i + 1)) for i, c in enumerate(cards)}
    check('imagen en la que tiene pantalla de carga', art['Sima Ígnea'] is True and art['Scholomance'] is True)
    check('sin imagen, se queda el color', art['Prisión de Alcaz'] is False)
    check('toda mazmorra con imagen menos las seis nuevas', a.ret('(function() local c = 0; for _, d in ipairs(SG.Dungeons) do if d.art then c = c + 1 end end; return c end)()') == 29)
    nopen = sum(1 for c in cards if c[1])
    check('primero las disponibles', firstopen == 0 and all(c[1] for c in cards[:nopen]))
    check('después las bloqueadas', nopen < n and not any(c[1] for c in cards[nopen:]))
    cmin = [a.ret('(function() for _, d in ipairs(SG.Dungeons) do if d.name == %r then return d.min end end end)()' % c[0]) for c in cards]
    check('disponibles de mayor a menor nivel', cmin[:nopen] == sorted(cmin[:nopen], reverse=True), cmin[:nopen])
    check('bloqueadas de mayor a menor nivel', cmin[nopen:] == sorted(cmin[nopen:], reverse=True), cmin[nopen:])
    tick = {c[0]: c[2] for c in cards}
    check('tick en la hecha', tick['Las Minas de la Muerte'] and tick['Ciudad de Dalaran'])
    check('sin tick en la no hecha', not tick['Sima Ígnea'])
    print(' abrir la ventana de búsqueda desde la tarjeta')
    a.ev('__panel.cards[%d]:Click()' % (firstopen + 1))
    check('ventana abierta', a.shown('SolfaGuildLFSSearch'))
    check('título', a.ret('SolfaGuildLFSSearch.title:GetText()') == 'Looking for Solfamidas')
    a.ev('SolfaGuildLFSSearch.go:Click()')
    check('sin elegir nada avisa', 'Elige' in (a.ret('SolfaGuildLFSSearch.why:GetText()') or ''), a.ret('SolfaGuildLFSSearch.why:GetText()'))
    S = 'SolfaGuildLFSSearch'
    def dps(button): a.ev('%s.D:GetScript("OnClick")(%s.D, %r)' % (S, S, button))
    RESTA, SUMA = 'RightButton', 'LeftButton'
    check('sin los iconos del LFG: los otros, con aro', a.ret(S + '.T.ring ~= nil') and a.ret(S + '.T.icon._atlas') is None)
    dps(RESTA)
    check('DPS no baja de 0', a.ret(S + '.need.D') == 0)
    for _ in range(5): dps(SUMA)
    check('DPS no sube de 3', a.ret(S + '.need.D') == 3)
    check('el número se ve', a.ret(S + '.D.count:GetText()') == 3)
    a.ev(S + '.T:Click()')
    check('tanque encendido', a.ret(S + '.need.T') == 1 and a.ret(S + '.T.glow:IsShown()') is True)
    check('tanque y 3 DPS: se puede buscar', a.ret(S + '.go:IsEnabled()') is True)
    a.ev(S + '.H:Click()')
    check('tanque, sanador y 3 DPS: Buscar se apaga', a.ret(S + '.go:IsEnabled()') is False)
    dps(RESTA)
    check('con 2 DPS vuelve a encenderse', a.ret(S + '.go:IsEnabled()') is True)
    a.ev(S + '.T:Click()')
    check('otro clic izquierdo no quita el tanque', a.ret(S + '.need.T') == 1)
    def rclick(role): a.ev('%s.%s:GetScript("OnClick")(%s.%s, "RightButton")' % (S, role, S, role))
    rclick('T'); rclick('H')
    check('clic derecho apaga tanque y sanador', a.ret(S + '.need.T') == 0 and a.ret(S + '.H.glow:IsShown()') is False)
    rclick('T')
    check('tanque no baja de 0', a.ret(S + '.need.T') == 0)
    dps(RESTA)
    check('un DPS', a.ret(S + '.need.D') == 1)
    a.ev('SolfaGuildLFSSearch.go:Click()')
    w.run(1)
    check('empieza la búsqueda', a.ret('SG.LFS:Run() ~= nil'), a.ret('SolfaGuildLFSSearch.why:GetText()'))
    check('muestra el estado', a.ret('SolfaGuildLFSSearch.status:IsShown()') and not a.ret('SolfaGuildLFSSearch.form:IsShown()'))
    check('oferta a Beto', offer(b))
    a.ev('SolfaGuildLFSSearch.go:Click()')
    w.run(1)
    check('cancelar', a.ret('SG.LFS:Run() == nil'))
    print(' prueba /sg lfs')
    a.ev('SlashCmdList["SOLFAGUILD"]("lfs")')
    check('oferta de prueba visible', offer(a))
    check('tres funciones', len(radios(a)) == 3)
    check('sin marcar, apagado', a.ret('SolfaGuildLFSOffer.yes:IsEnabled()') is False)
    no(a)
    w.run(1)
    print(' GM y escalafón PvE')
    check('Beto es GM en su cliente', b.ret('SG:IsAdmin()') is True, b.ret('SG.gmName'))
    check('Ana reconoce al GM', a.ret('SG.gmName') == 'Beto Dos', a.ret('SG.gmName'))
    check('Ana no es admin', a.ret('SG:IsAdmin()') is False)
    r = a.ret('SG.DungeonTracker:LadderRankOf(SG:MyAccount())')
    check('Ana tiene rango PvE', r == 'Leyenda de las Profundidades' or r is not None, r)
    no_errors(w, 'interfaz')
    print(' LFS con un personaje que aún no llega a ninguna mazmorra')
    w = World(True)
    c = w.add('c', {'Cati Tres': {'class': 'PRIEST', 'level': 5}}, 'Cati Tres')
    w.start()
    c.rt.execute('''
        local o = SG.UILFS.BuildPanel
        SG.UILFS.BuildPanel = function(s, p) __panel = o(s, p); __pve = p; return __panel end
    ''')
    c.ev('SG.UI:Show("dungeons")')
    c.ev('__pve.modeButtons[3]:Click()')
    w.run(0.2)
    check('nivel 5: se abre desde el principio', c.ret('__panel.scroll:GetVerticalScroll()') == 0, c.ret('__panel.scroll:GetVerticalScroll()'))
    check('nivel 5: la primera, en fila 1 y columna 1', (c.ret('__panel.cards[1]._point[2]'), c.ret('__panel.cards[1]._point[3]')) == (0, 0))
    c.ev('C_Texture = { GetAtlasInfo = function() return {} end }; SG.UILFS:OpenSearch(SG.Dungeons[1])')
    S = 'SolfaGuildLFSSearch'
    check('con los iconos del LFG: se usan esos', [c.ret(S + '.%s.icon._atlas' % r) for r in 'THD'] == ['UI-LFG-RoleIcon-Tank', 'UI-LFG-RoleIcon-Healer', 'UI-LFG-RoleIcon-DPS'])
    check('con los iconos del LFG: sin aro', c.ret(S + '.T.ring == nil') is True)
    c.ev(S + '.T:Click()')
    check('con los iconos del LFG: se encienden', c.ret(S + '.T.glow:IsShown()') is True)
    no_errors(w, 'LFS a nivel bajo')

def t_dungeons():
    print('\n== Mazmorra completada en Forever ==')
    w, a, b, c = base(); w.start()
    a.g.INST, a.g.INST_KIND = True, 'party'
    a.fire('PLAYER_ENTERING_WORLD')
    guid = 'Creature-0-1-1-1-639-1'
    a.fire('UNIT_DIED', guid)
    a.fire('PARTY_KILL', 'x', guid)
    w.run(1)
    check('una sola vez', a.ret('SG:MyChar().dungeons.vc') == 1, a.ret('SG:MyChar().dungeons.vc'))
    a.fire('UNIT_DIED', 'Creature-0-1-1-1-999-1')
    w.run(1)
    check('otro bicho no cuenta', a.ret('SG:MyChar().dungeonsWeek') == 1)
    no_errors(w, 'mazmorra')

    print(' Mazmorras y grupos: una completación por grupo')
    w, a, b, c = base(); w.start()
    guid = 'Creature-0-1-1-1-639-1'
    for x in (a, b, c):
        x.g.INST, x.g.INST_KIND = True, 'party'
        x.fire('PLAYER_ENTERING_WORLD')
    def run_vc(*who):
        for x in who:
            x.fire('UNIT_DIED', guid)
        for x in who:
            x.ev('SG:BroadcastProfile()')
        w.run(2)
    runs = lambda x, week='false': x.ret('(SG.DungeonTracker:Runs(%s))[1] and (SG.DungeonTracker:Runs(%s))[1].runs or 0' % (week, week))
    def groups(x, week='false'):
        x.ev('__g = select(2, SG.DungeonTracker:Runs(%s))' % week)
        out = []
        for i in range(1, x.ret('#__g') + 1):
            names = [x.ret('__g[%d].accs[%d].main' % (i, j)) for j in range(1, x.ret('#__g[%d].accs' % i) + 1)]
            out.append((names, x.ret('__g[%d].runs' % i)))
        return out

    run_vc(a, b, c)
    check('separados: tres completaciones', runs(a) == 3, runs(a))
    check('separados: ningún grupo', groups(a) == [], groups(a))
    w.run(3601)
    w.make_group(a, b, c)
    run_vc(a, b, c)
    check('los tres juntos: solo una más', runs(a) == 4, runs(a))
    check('todos ven lo mismo', runs(b) == 4 and runs(c) == 4, (runs(b), runs(c)))
    check('el grupo sale una vez', groups(a) == [(['Ana Uno', 'Beto Dos', 'Ciro Tres'], 1)], groups(a))
    check('la semanal también', runs(a, 'true') == 4, runs(a, 'true'))
    w.run(3601)
    a.ev('SG:MyChar().weekKey = "antigua"; SG:CheckWeek(SG:MyChar())')
    check('la semana nueva borra lo mío', a.ret('next(SG:MyChar().dgWeek)') is None and a.ret('next(SG:MyChar().dgTeamsWeek)') is None)
    check('el total sigue', runs(a) == 4, runs(a))
    run_vc(a, b)
    check('si falta el aviso de uno, cuenta el otro', runs(a) == 5, runs(a))
    check('mismo grupo: misma fila', len(groups(a)) == 1 and groups(a)[0][1] == 2, groups(a))
    no_errors(w, 'mazmorras en grupo')

# ------------------------------------------------------------------ Cositas
def t_cositas():
    print('\n== Cositas en Forever ==')
    w, a, b, c = base(); w.start()
    stat = lambda k: a.ret('SG:MyChar().cositas.%s or 0' % k)
    n = {'g': 0}
    def cast(spell, target, ok=True):
        n['g'] += 1
        guid = 'Cast-%d' % n['g']
        a.fire('UNIT_SPELLCAST_SENT', 'player', target, guid, spell)
        if ok:
            a.fire('UNIT_SPELLCAST_SUCCEEDED', 'player', guid, spell)

    print(' Paracaidista: solo las caídas')
    for env, want in (('Drowning', 0), ('Fatigue', 0), ('Lava', 0), ('Falling', 1)):
        a.rt.execute('RECAP = { { timestamp = 1, environmentalType = %r } }' % env)
        a.fire('PLAYER_DEAD'); w.run(2)
        check('%s: %d' % (env, want), stat('falls') == want, stat('falls'))
        w.run(30)
    a.rt.execute('RECAP = { { timestamp = 1, sourceGUID = "Creature-0-1-1-1-1-1", sourceName = "Lobo" } }')
    a.fire('PLAYER_DEAD'); w.run(2)
    check('un monstruo no cuenta', stat('falls') == 1)
    check('muertes: 5', stat('deaths') == 5, stat('deaths'))
    a.fire('PLAYER_DEAD'); w.run(2)
    check('el evento repetido al liberar no suma otra muerte', stat('deaths') == 5, stat('deaths'))

    print(' Ángel de la guarda: sin spam')
    w.make_group(a, b)
    a.g.UNITS['party1'].dead = True
    cast(2006, 'Beto-Dos')
    check('primera resurrección cuenta', stat('rez') == 1, stat('rez'))
    cast(2006, 'Beto-Dos'); cast(2006, 'Beto-Dos')
    check('spam a quien no acepta: no suma', stat('rez') == 1, stat('rez'))
    w.run(30)
    cast(2006, 'Beto-Dos')
    check('aunque pase tiempo, si sigue muerto: no suma', stat('rez') == 1, stat('rez'))
    cast(2006, 'Ciro-Tres')
    check('a otro jugador: suma', stat('rez') == 2, stat('rez'))
    cast(2006, 'Ciro-Tres', ok=False)
    a.g.UNITS['party1'].dead = False
    w.run(5)
    cast(2006, 'Beto-Dos')
    check('ya vivo y muerto otra vez: suma', stat('rez') == 3, stat('rez'))
    w.run(601)
    cast(2006, 'Ciro-Tres')
    check('fuera de vista: se olvida a los 10 min', stat('rez') == 4, stat('rez'))
    cast(2006, 'Dani-Ocho', ok=False)
    check('lanzamiento interrumpido: no suma', stat('rez') == 4, stat('rez'))

    print(' Colegón: por hechizo y jugador')
    cast(5697, 'Beto-Dos')
    check('respirar bajo el agua a Beto', stat('buffs') == 1, stat('buffs'))
    cast(5697, 'Beto-Dos'); cast(5697, 'Beto-Dos')
    check('spam al mismo: no suma', stat('buffs') == 1, stat('buffs'))
    cast(5697, 'Ciro-Tres')
    check('a otro jugador: suma', stat('buffs') == 2, stat('buffs'))
    cast(1459, 'Beto-Dos')
    check('otro bufo a Beto: suma', stat('buffs') == 3, stat('buffs'))
    cast(5697, 'Ana-Uno'); cast(5697, '')
    check('a mí mismo: no suma', stat('buffs') == 3, stat('buffs'))
    cast(133, 'Beto-Dos')
    check('hechizo que no es bufo: no suma', stat('buffs') == 3, stat('buffs'))
    w.run(200); cast(5697, 'Beto-Dos')
    w.run(200); cast(5697, 'Beto-Dos')
    check('spam espaciado sin pasar 5 min: no suma', stat('buffs') == 3, stat('buffs'))
    w.run(301); cast(5697, 'Beto-Dos')
    check('pasados 5 min: suma', stat('buffs') == 4, stat('buffs'))
    a.set_unit('target', 'Lobo', None, faction='Horde', guid='Pet-1', is_player=False)
    cast(5697, 'Lobo')
    check('a una mascota: no suma', stat('buffs') == 4, stat('buffs'))

    print(' P.E.T.A.: cualquier bicho con "jaba"')
    for line, want in (('Jabalí joven muere, ganas 12 puntos de experiencia.', 1),
                       ('Jabato furioso muere, ganas 12 puntos de experiencia. (+3 de bonificación de grupo)', 2),
                       ('Lobo muere, ganas 12 puntos de experiencia.', 2),
                       ('Has descubierto algo y ganas 20 de experiencia.', 2)):
        a.fire('CHAT_MSG_COMBAT_XP_GAIN', line)
        check(line[:24], stat('boars') == want, stat('boars'))

    print(' Sorakambulancia: medidor del juego')
    w, a, b, c = base()
    def session(i, mine, other=999, secret=False):
        a.rt.execute("""
            DM_DATA[%d] = { combatSources = {
                { isLocalPlayer = false, totalAmount = %d },
                { isLocalPlayer = true, totalAmount = %d } } }
            local found = false
            for _, s in ipairs(DM_SESSIONS) do if s.sessionID == %d then found = true end end
            if not found then DM_SESSIONS[#DM_SESSIONS + 1] = { sessionID = %d } end
        """ % (i, other, mine, i, i))
    session(1, 100)
    w.start()
    check('lo de antes de entrar no suma', stat('heal') == 0, stat('heal'))
    a.g.COMBAT = True
    session(2, 500)
    a.fire('PLAYER_REGEN_DISABLED')
    a.fire('DAMAGE_METER_COMBAT_SESSION_UPDATED', 2, 2)
    w.run(1)
    check('en combate no se lee', stat('heal') == 0, stat('heal'))
    a.g.COMBAT = False
    a.fire('PLAYER_REGEN_ENABLED')
    w.run(4)
    check('al salir suma mi curación, no la de otros', stat('heal') == 500, stat('heal'))
    a.fire('PLAYER_REGEN_ENABLED'); w.run(4)
    check('leerla otra vez no suma de nuevo', stat('heal') == 500, stat('heal'))
    session(2, 650)
    a.fire('DAMAGE_METER_COMBAT_SESSION_UPDATED', 2, 2)
    check('si la sesión sigue, solo lo nuevo', stat('heal') == 650, stat('heal'))
    a.g.SECRETS[300] = True
    session(3, 300)
    a.fire('PLAYER_REGEN_ENABLED'); w.run(4)
    check('valor oculto: espera', stat('heal') == 650, stat('heal'))
    a.g.SECRETS[300] = None
    a.fire('PLAYER_REGEN_ENABLED'); w.run(4)
    check('cuando se puede leer: suma', stat('heal') == 950, stat('heal'))
    a.rt.execute('DM_SESSIONS = {}; DM_DATA = {}')
    a.fire('DAMAGE_METER_RESET')
    session(1, 40)
    a.fire('PLAYER_REGEN_ENABLED'); w.run(4)
    check('tras reiniciar el medidor sigue sumando', stat('heal') == 990, stat('heal'))
    no_errors(w, 'Cositas')

TESTS = [t_cositas, lambda: t_names(0), lambda: t_names(1), lambda: t_names(2), t_migration, t_chars, t_pvp, t_pvp_ladder, t_classic, t_sos,
         lambda: t_lfs(0), lambda: t_lfs(1), lambda: t_lfs(2), t_lfs_edges, t_lfs_send, t_ui, t_dungeons]

for strict in ('', '1'):
    os.environ['STRICT'] = strict
    print('\n########## %s ##########' % ('Sin las funciones antiguas' if strict else 'Con todas las funciones'))
    for fn in TESTS:
        try:
            fn()
        except Exception:
            fails.append('EXCEPCIÓN')
            traceback.print_exc(limit=4)

print('\n%d correctas, %d fallos' % (passes, len(fails)))
for f in fails:
    print(' -', f)
sys.exit(1 if fails else 0)
