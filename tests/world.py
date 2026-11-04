"""Mundo simulado: varios clientes del addon real, reloj, guild, grupos y mensajes."""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
from lupa.lua51 import LuaRuntime

ADDON = os.path.dirname(HERE)
REALM = 'Reino'
MOCK = open(os.path.join(HERE, 'mock.lua'), encoding='utf-8').read()


def toc_files():
    out = []
    for line in open(os.path.join(ADDON, 'SolfaGuild.toc'), encoding='utf-8'):
        line = line.strip()
        if line and not line.startswith('#'):
            out.append(line.replace('\\', '/'))
    return out


class Client:
    def __init__(self, world, acc, chars, online, faction='Horde', gm=False):
        self.world, self.acc, self.chars, self.name = world, acc, chars, online
        self.faction, self.gm = faction, gm
        self.prints, self.errors, self.chat = [], [], []
        self.invite_from = None
        self.has_addon = True
        rt = LuaRuntime(unpack_returned_tuples=True, encoding='utf-8')
        self.rt, self.g = rt, rt.globals()
        g = self.g
        g.py_print = lambda m: self.prints.append(str(m))
        g.py_error = lambda m: self.errors.append(str(m))
        g.py_send = lambda text, chan, target: world.send(self, text, chan, target)
        g.py_chat = lambda msg, chan, target: self.chat.append((msg, chan, target))
        g.py_invite = lambda n: world.invite(self, n)
        g.py_leave = lambda: world.leave(self)
        g.py_accept = lambda: world.accept(self)
        g.py_convert = lambda: world.convert(self)
        rt.execute('CFG = { forever = %s }' % ('true' if world.forever else 'false'))
        rt.execute(MOCK)
        g.lua_initForever()
        if os.environ.get('STRICT'):
            g.lua_strict()
        self.set_player(online)
        self.seed_db()
        ns = rt.table()
        for path in toc_files():
            g.lua_load(open(os.path.join(ADDON, path), encoding='utf-8').read(), path, ns)
        self.rt.execute("SG = SolfaGuild")

    def info(self, name=None):
        return self.chars[name or self.name]

    def set_player(self, name):
        self.name = name
        c = self.chars[name]
        first, _, second = name.partition(' ')
        u = self.rt.table_from({'first': first, 'isPlayer': True, 'class': c['class'], 'level': c['level'],
                                'faction': self.faction, 'guid': 'Player-1-' + first})
        if self.world.forever:
            u['second'] = second
        self.g.UNITS['player'] = u

    def seed_db(self):
        lines = ['SolfaGuildDB = { accountId = %r, my = { main = %r, chars = {' % (self.acc, self.name)]
        for n, c in self.chars.items():
            d = ', '.join('%s = 1' % k for k in c.get('done', []))
            lines.append('[%r] = { class = %r, level = %d, guild = "Los Solfamidas", dungeons = { %s }, goldSeeded = true },'
                         % (n, c['class'], c['level'], d))
        lines.append('} } }')
        self.rt.execute('\n'.join(lines))

    def ev(self, code):
        """Evalúa Lua. Con 'return' ejecuta y devuelve."""
        return self.rt.execute(code)

    def ret(self, expr):
        return self.rt.eval(expr)

    def fire(self, event, *a):
        self.g.lua_fire(event, *a)

    def set_unit(self, unit, first, second=None, faction='Alliance', guid=None, dead=False, is_player=True):
        u = self.rt.table_from({'first': first, 'isPlayer': is_player, 'faction': faction, 'class': 'MAGE', 'level': 20,
                                'guid': guid or ('Player-1-' + first), 'dead': dead})
        if second and self.world.forever:
            u['second'] = second
        self.g.UNITS[unit] = u

    def clear_unit(self, unit):
        self.g.UNITS[unit] = None

    def group_size(self):
        return self.ret('#GROUP')

    def shown(self, frame):
        return bool(self.ret('%s ~= nil and %s:IsShown()' % (frame, frame)))


class World:
    def __init__(self, forever=True, sender_format=0):
        self.forever = forever
        self.sender_format = sender_format
        self.clients = {}       # por nombre del personaje conectado
        self.members = []       # roster completo: (nombre, datos, cliente o None)
        self.now = 10000.0   # GetTime es el tiempo encendido del PC: nunca empieza en 0
        self.outbox = []
        self.groups = []        # [{ leader, members:[client], raid }]
        self.whisper_targets = []
        self.invite_targets = []
        self.failed_targets = []
        self.sent = []          # (tipo, de, canal, para)

    def add(self, acc, chars, online, faction='Horde', has_addon=True):
        self.members.extend((n, c) for n, c in chars.items())
        cl = Client(self, acc, chars, online, faction)
        cl.has_addon = has_addon
        self.clients[acc] = cl
        return cl

    def start(self, settle=30):
        for c in self.clients.values():
            c.fire('ADDON_LOADED', 'SolfaGuild')
        self.push_roster()
        for c in self.clients.values():
            c.fire('PLAYER_LOGIN')
            c.fire('PLAYER_ENTERING_WORLD')
        self.run(settle)

    # ------------------------------------------------------------ nombres
    def roster_raw(self, name):
        if self.forever:
            return name + '-' + REALM
        return name.split(' ')[0] + '-' + REALM

    def sender_raw(self, name):
        if not self.forever:
            return name + '-' + REALM
        first, _, second = name.partition(' ')
        return [first + '-' + second + '-' + REALM, name + '-' + REALM, first + '-' + second][self.sender_format]

    def online_names(self):
        return {c.name: c for c in self.clients.values()}

    def resolve(self, target):
        """El juego acepta el nombre con reino, o Nombre-Apellido; un nombre suelto en Forever, no."""
        t = re.sub('-' + REALM + '$', '', target)
        t = t.replace('-', ' ')
        return self.online_names().get(t)

    def push_roster(self):
        online = self.online_names()
        for c in self.clients.values():
            rows = []
            for i, (n, d) in enumerate(self.members):
                o = n in online
                rows.append(c.rt.table_from({'raw': self.roster_raw(n), 'rankIndex': 0 if d.get('gm') else 2,
                                             'level': d['level'], 'class': d['class'], 'zone': 'Baldíos', 'online': o}))
            c.g.ROSTER = c.rt.table_from(rows)
            c.fire('GUILD_ROSTER_UPDATE')

    # ------------------------------------------------------------ reloj
    def run(self, secs, step=0.1):
        end = self.now + secs
        while self.now < end - 1e-9:
            self.now += step
            for c in list(self.clients.values()):
                c.g.lua_tick(self.now)
            self.flush()

    def flush(self):
        box, self.outbox = self.outbox, []
        for src, text, chan, dest in box:
            for c in self.clients.values():
                if c is src or not c.has_addon:
                    continue
                if chan == 'WHISPER' and c is not dest:
                    continue
                c.fire('CHAT_MSG_ADDON', 'SolfaGuild', text, chan, self.sender_raw(src.name))

    # ------------------------------------------------------------ mensajes
    def send(self, src, text, chan, target):
        if not src.has_addon:
            return
        m = re.search(r's1:t(?:s\d+:)?', text)
        if chan == 'WHISPER':
            self.whisper_targets.append(target)
            dest = self.resolve(target)
            if not dest:
                self.failed_targets.append(target)
                return
            self.outbox.append((src, text, chan, dest))
        else:
            self.outbox.append((src, text, chan, None))
        t = re.search(r's1:ts\d+:([A-Z_]+)', text)
        self.sent.append((t.group(1) if t else '?', src.name, chan, target))

    # ------------------------------------------------------------ grupos
    def group_of(self, c):
        for g in self.groups:
            if c in g['members']:
                return g

    def sync_group(self, g):
        for m in g['members']:
            others = [o for o in g['members'] if o is not m]
            rows = []
            for o in others:
                first, _, second = o.name.partition(' ')
                row = {'first': first, 'guid': 'Player-1-' + first}
                if self.forever:
                    row['second'] = second
                rows.append(m.rt.table_from(row))
            m.g.lua_setGroup(m.rt.table_from(rows), g['leader'] is m, g.get('raid', False))

    def invite(self, c, target):
        self.invite_targets.append(target)
        dest = self.resolve(target)
        if not dest:
            self.failed_targets.append(target)
            return
        if self.group_of(dest):
            c.prints.append('[juego] %s ya está en un grupo' % dest.name)
            return
        g = self.group_of(c)
        if g and not g.get('raid') and len(g['members']) >= 5:
            c.prints.append('[juego] grupo lleno')
            return
        dest.invite_from = c
        dest.fire('PARTY_INVITE_REQUEST', self.sender_raw(c.name))

    def accept(self, c):
        inv = c.invite_from
        if not inv:
            return
        c.invite_from = None
        g = self.group_of(inv)
        if not g:
            g = {'leader': inv, 'members': [inv]}
            self.groups.append(g)
        g['members'].append(c)
        self.sync_group(g)

    def leave(self, c):
        g = self.group_of(c)
        if not g:
            return
        g['members'].remove(c)
        c.g.lua_setGroup(c.rt.table_from([]), True, False)
        if len(g['members']) <= 1:
            self.groups.remove(g)
            for m in g['members']:
                m.g.lua_setGroup(m.rt.table_from([]), True, False)
        else:
            if g['leader'] is c:
                g['leader'] = g['members'][0]
            self.sync_group(g)

    def convert(self, c):
        g = self.group_of(c)
        if g:
            g['raid'] = True
            self.sync_group(g)

    def make_group(self, *clients):
        g = {'leader': clients[0], 'members': list(clients)}
        self.groups.append(g)
        self.sync_group(g)
        return g

    def switch_char(self, c, name):
        """Cambia de personaje: misma cuenta y SavedVariables, sin recargar el addon."""
        c.set_player(name)
        self.push_roster()
        c.ev('SG.LFS:OnLogin()')

    def all_errors(self):
        out = []
        for c in self.clients.values():
            for e in c.errors:
                out.append((c.name, e))
            for p in c.prints:
                if 'error:' in p:
                    out.append((c.name, p))
        return out
