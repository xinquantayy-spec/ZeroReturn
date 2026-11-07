#!/usr/bin/env python3
"""Luau lint for Zero Return (audit tech-8): undefined globals and stray global writes.

A small recursive-descent parser for Luau (types, generics, compound assignment, if-expressions, string interpolation,
attributes, continue, type aliases and type functions). It resolves every name against the scopes it is used in and
reports:
  E1 read of a name that is neither a local nor a known Luau / Roblox global (the "rain" bug class)
  E2 assignment to an undeclared global (a missing `local`)
  E0 a parse error (the file is not valid Luau as far as this parser knows)
  W1 a local declared twice in the same scope where the first is never read (likely a copy-paste slip)

Usage: python3 tools/luau_lint.py [paths...]   (default: src). Exit status 1 when any E finding exists.
It runs before every sync, next to tools/luau_check.py. selene, StyLua and luau-lsp (tech-8b) are the fuller tools;
this one needs nothing installed.
"""
import os
import re
import sys

# ── globals ──────────────────────────────────────────────────────────────────────────────────────────────────────────
LUAU = """assert error getmetatable ipairs next pairs pcall print rawequal rawget rawlen rawset require select setmetatable
tonumber tostring type typeof unpack xpcall gcinfo getfenv setfenv newproxy collectgarbage _G _VERSION math string table
coroutine bit32 utf8 os debug buffer vector loadstring""".split()
ROBLOX = """game workspace Workspace script plugin shared Instance Vector3 Vector2 CFrame Color3 UDim UDim2 Enum Ray Rect
Region3 Region3int16 Vector3int16 Vector2int16 BrickColor NumberRange NumberSequence NumberSequenceKeypoint ColorSequence
ColorSequenceKeypoint PhysicalProperties TweenInfo RaycastParams OverlapParams Axes Faces DateTime Random task tick time
wait delay spawn warn elapsedTime ElapsedTime settings UserSettings version stats PathWaypoint Font Content SharedTable
Path2DControlPoint RotationCurveKey FloatCurveKey DockWidgetPluginGuiInfo CatalogSearchParams ValueCurveKey
SecurityCapabilities RaycastResult PluginDrag CellId Secret""".split()
KNOWN = set(LUAU) | set(ROBLOX)

KEYWORDS = set("""and break do else elseif end false for function if in local nil not or repeat return then true until
while""".split())

# ── tokens ───────────────────────────────────────────────────────────────────────────────────────────────────────────
class Tok:
    __slots__ = ("k", "v", "line", "parts")

    def __init__(self, k, v, line, parts=None):
        self.k, self.v, self.line, self.parts = k, v, line, parts

    def __repr__(self):
        return f"{self.k}:{self.v!r}@{self.line}"


OPS = ["...", "..=", "//=", "==", "~=", "<=", ">=", "+=", "-=", "*=", "/=", "%=", "^=", "..", "::", "->", "//",
       "+", "-", "*", "/", "%", "^", "#", "<", ">", "=", "(", ")", "{", "}", "[", "]", ";", ":", ",", ".", "?", "|",
       "&", "@"]
NUM_RE = re.compile(r"0[xX][0-9a-fA-F_]+|0[bB][01_]+|(?:\d[\d_]*\.?[\d_]*|\.\d[\d_]*)(?:[eE][+-]?\d+)?")
NAME_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


class LexError(Exception):
    pass


def long_bracket(src, i):
    """at src[i] == '[': return (level, end_of_open) for [[ / [==[ , else None"""
    m = re.match(r"\[(=*)\[", src[i:])
    if not m:
        return None
    return len(m.group(1)), i + m.end()


def lex(src):
    toks, i, line, n = [], 0, 1, len(src)
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c in " \t\r\f\v":
            i += 1
            continue
        if src.startswith("--", i):
            lb = long_bracket(src, i + 2) if i + 2 < n and src[i + 2] == "[" else None
            if lb:
                close = "]" + "=" * lb[0] + "]"
                j = src.find(close, lb[1])
                if j < 0:
                    raise LexError(f"line {line}: unfinished long comment")
                line += src.count("\n", i, j)
                i = j + len(close)
            else:
                j = src.find("\n", i)
                i = n if j < 0 else j
            continue
        if c == "[":
            lb = long_bracket(src, i)
            if lb:
                close = "]" + "=" * lb[0] + "]"
                j = src.find(close, lb[1])
                if j < 0:
                    raise LexError(f"line {line}: unfinished long string")
                toks.append(Tok("str", None, line))
                line += src.count("\n", i, j)
                i = j + len(close)
                continue
        if c in "\"'":
            j, start = i + 1, line
            while j < n and src[j] != c:
                if src[j] == "\\":
                    if j + 1 < n and src[j + 1] == "\n":
                        line += 1
                    if j + 1 < n and src[j + 1] == "z":
                        j += 2
                        while j < n and src[j] in " \t\r\n":
                            if src[j] == "\n":
                                line += 1
                            j += 1
                        continue
                    j += 2
                    continue
                if src[j] == "\n":
                    raise LexError(f"line {line}: unfinished string")
                j += 1
            toks.append(Tok("str", None, start))
            i = j + 1
            continue
        if c == "`":
            # interpolated string: the {expr} parts are lexed as token lists of their own
            j, parts, start = i + 1, [], line
            while j < n and src[j] != "`":
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == "\n":
                    line += 1
                if src[j] == "{":
                    depth, k = 1, j + 1
                    while k < n and depth:
                        if src[k] == "{":
                            depth += 1
                        elif src[k] == "}":
                            depth -= 1
                        elif src[k] in "\"'":
                            q = src[k]
                            k += 1
                            while k < n and src[k] != q:
                                k += 2 if src[k] == "\\" else 1
                        k += 1
                    sub = lex(src[j + 1:k - 1])
                    for t in sub:
                        t.line += line - 1
                    parts.append(sub)
                    j = k
                    continue
                j += 1
            toks.append(Tok("istr", None, start, parts))
            i = j + 1
            continue
        if c.isdigit() or (c == "." and i + 1 < n and src[i + 1].isdigit()):
            m = NUM_RE.match(src, i)
            toks.append(Tok("num", m.group(0), line))
            i = m.end()
            continue
        if c.isalpha() or c == "_":
            m = NAME_RE.match(src, i)
            w = m.group(0)
            toks.append(Tok("kw" if w in KEYWORDS else "name", w, line))
            i = m.end()
            continue
        for op in OPS:
            if src.startswith(op, i):
                toks.append(Tok("op", op, line))
                i += len(op)
                break
        else:
            raise LexError(f"line {line}: unexpected character {c!r}")
    toks.append(Tok("eof", None, line))
    return toks


# ── parser with scopes ───────────────────────────────────────────────────────────────────────────────────────────────
class ParseError(Exception):
    pass


class Local:
    __slots__ = ("name", "line", "reads")

    def __init__(self, name, line):
        self.name, self.line, self.reads = name, line, 0


class Linter:
    BINOPS = {"+", "-", "*", "/", "//", "%", "^", "..", "==", "~=", "<", "<=", ">", ">=", "and", "or"}
    COMPOUND = {"+=", "-=", "*=", "/=", "//=", "%=", "^=", "..="}

    def __init__(self, toks, path):
        self.t, self.i, self.path = toks, 0, path
        self.scopes = [{}]
        self.findings = []

    # token helpers
    def peek(self, k=0):
        return self.t[min(self.i + k, len(self.t) - 1)]

    def at(self, v, k=0):
        t = self.peek(k)
        return t.v == v and t.k in ("op", "kw")

    def at_name(self, v=None, k=0):
        t = self.peek(k)
        return t.k == "name" and (v is None or t.v == v)

    def next(self):
        t = self.t[self.i]
        self.i += 1
        return t

    def expect(self, v):
        t = self.next()
        if t.v != v or t.k not in ("op", "kw"):
            raise ParseError(f"line {t.line}: expected {v!r}, found {t.v!r}")
        return t

    def name(self):
        t = self.next()
        if t.k != "name":
            raise ParseError(f"line {t.line}: expected a name, found {t.v!r}")
        return t

    # scopes
    def push(self):
        self.scopes.append({})

    def pop(self):
        self.scopes.pop()

    def declare(self, tok):
        sc = self.scopes[-1]
        old = sc.get(tok.v)
        if old is not None and old.reads == 0 and tok.v != "_" and not tok.v.startswith("_"):
            self.findings.append((tok.line, "W1", f"local '{tok.v}' declared again in the same scope; the one on line {old.line} is never read"))
        sc[tok.v] = Local(tok.v, tok.line)

    def resolve(self, name):
        for sc in reversed(self.scopes):
            if name in sc:
                return sc[name]
        return None

    def use(self, tok):
        loc = self.resolve(tok.v)
        if loc is not None:
            loc.reads += 1
        elif tok.v not in KNOWN:
            self.findings.append((tok.line, "E1", f"'{tok.v}' is not a local or a known global"))

    def assign(self, tok):
        loc = self.resolve(tok.v)
        if loc is None and tok.v not in KNOWN:
            self.findings.append((tok.line, "E2", f"assignment to undeclared global '{tok.v}' (missing local?)"))

    # ── blocks and statements ──
    def block_end(self):
        t = self.peek()
        return t.k == "eof" or (t.k == "kw" and t.v in ("end", "else", "elseif", "until"))

    def block(self):
        while not self.block_end():
            if self.at("return"):
                self.next()
                if not self.block_end() and not self.at(";"):
                    self.explist()
                if self.at(";"):
                    self.next()
                return
            self.statement()
            if self.at(";"):
                self.next()

    def attributes(self):
        while self.at("@"):
            self.next()
            self.name()

    def statement(self):
        t = self.peek()
        if t.k == "op" and t.v == "@":
            self.attributes()
            t = self.peek()
        if t.k == "kw":
            v = t.v
            if v == "local":
                self.next()
                self.attributes()
                if self.at("function"):
                    self.next()
                    nt = self.name()
                    self.declare(nt)
                    self.funcbody()
                    return
                names = [self.binding()]
                while self.at(","):
                    self.next()
                    names.append(self.binding())
                if self.at("="):
                    self.next()
                    self.explist()
                for nt in names:
                    self.declare(nt)
                return
            if v == "function":
                self.next()
                first = self.name()
                is_method = False
                if self.at(".") or self.at(":"):
                    self.use(first)
                    while self.at("."):
                        self.next()
                        self.name()
                    if self.at(":"):
                        self.next()
                        self.name()
                        is_method = True
                else:
                    self.assign(first)
                self.funcbody(is_method)
                return
            if v == "do":
                self.next()
                self.push()
                self.block()
                self.pop()
                self.expect("end")
                return
            if v == "while":
                self.next()
                self.expr()
                self.expect("do")
                self.push()
                self.block()
                self.pop()
                self.expect("end")
                return
            if v == "repeat":
                self.next()
                self.push()
                self.block()
                self.expect("until")
                self.expr()  # the until condition sees the body's locals
                self.pop()
                return
            if v == "if":
                self.next()
                self.expr()
                self.expect("then")
                self.push()
                self.block()
                self.pop()
                while self.at("elseif"):
                    self.next()
                    self.expr()
                    self.expect("then")
                    self.push()
                    self.block()
                    self.pop()
                if self.at("else"):
                    self.next()
                    self.push()
                    self.block()
                    self.pop()
                self.expect("end")
                return
            if v == "for":
                self.next()
                first = self.binding()
                if self.at("="):
                    self.next()
                    self.expr()
                    self.expect(",")
                    self.expr()
                    if self.at(","):
                        self.next()
                        self.expr()
                    names = [first]
                else:
                    names = [first]
                    while self.at(","):
                        self.next()
                        names.append(self.binding())
                    self.expect("in")
                    self.explist()
                self.expect("do")
                self.push()
                for nt in names:
                    self.declare(nt)
                self.block()
                self.pop()
                self.expect("end")
                return
            if v == "break":
                self.next()
                return
        if t.k == "name":
            # contextual keywords
            if t.v == "continue" and not self.continues_expr(1):
                self.next()
                return
            if t.v == "export" and self.at_name("type", 1):
                self.next()
                t = self.peek()
            if t.v == "type" and (self.peek(1).k == "name" or (self.peek(1).v == "function" and self.peek(2).k == "name")):
                self.next()
                if self.at("function"):
                    self.next()
                    self.name()
                    self.push()
                    self.funcbody()
                    self.pop()
                    return
                self.name()
                if self.at("<"):
                    self.generic_list(defaults=True)
                self.expect("=")
                self.type_()
                return
        # expression statement: assignment or call
        targets = [self.suffixed(lhs=True)]
        if self.at(",") or self.at("="):
            while self.at(","):
                self.next()
                targets.append(self.suffixed(lhs=True))
            self.expect("=")
            self.explist()
            for tg in targets:
                if tg[0] == "name":
                    self.assign(tg[1])
            return
        if self.peek().v in self.COMPOUND and self.peek().k == "op":
            self.next()
            self.expr()
            if targets[0][0] == "name":
                self.use(targets[0][1])
            return
        if targets[0][0] != "call":
            raise ParseError(f"line {t.line}: a statement must be a call or an assignment")

    def continues_expr(self, k):
        t = self.peek(k)
        return (t.k == "op" and t.v in ("(", ".", ":", "[", "=", ",", "{", "+=", "-=")) or t.k in ("str", "istr")

    def binding(self):
        nt = self.name()
        if self.at(":"):
            self.next()
            self.type_()
        return nt

    def funcbody(self, is_method=False):
        self.push()
        if is_method:
            self.scopes[-1]["self"] = Local("self", self.peek().line)
            self.scopes[-1]["self"].reads = 1
        if self.at("<"):
            self.generic_list()
        self.expect("(")
        params = []
        if not self.at(")"):
            while True:
                if self.at("..."):
                    self.next()
                    if self.at(":"):
                        self.next()
                        self.type_pack_or_type()
                    break
                params.append(self.binding())
                if not self.at(","):
                    break
                self.next()
        self.expect(")")
        if self.at(":"):
            self.next()
            self.return_type()
        for p in params:
            self.declare(p)
            self.scopes[-1][p.v].reads = 1  # unused parameters are fine
        self.block()
        self.expect("end")
        self.pop()

    # ── expressions ──
    def explist(self):
        self.expr()
        while self.at(","):
            self.next()
            self.expr()

    def expr(self):
        t = self.peek()
        if (t.k == "kw" and t.v == "not") or (t.k == "op" and t.v in ("-", "#")):
            self.next()
            self.expr_unary_tail()
        else:
            self.simple()
        while True:
            t = self.peek()
            if (t.k == "op" and t.v in self.BINOPS) or (t.k == "kw" and t.v in ("and", "or")):
                self.next()
                t2 = self.peek()
                if (t2.k == "kw" and t2.v == "not") or (t2.k == "op" and t2.v in ("-", "#")):
                    self.next()
                    self.expr_unary_tail()
                else:
                    self.simple()
            else:
                return

    def expr_unary_tail(self):
        t = self.peek()
        if (t.k == "kw" and t.v == "not") or (t.k == "op" and t.v in ("-", "#")):
            self.next()
            self.expr_unary_tail()
        else:
            self.simple()

    def simple(self):
        t = self.peek()
        if t.k in ("num", "str"):
            self.next()
        elif t.k == "istr":
            self.next()
            for part in t.parts:
                sub = Linter(part + [Tok("eof", None, t.line)], self.path)
                sub.scopes = self.scopes
                sub.explist()
                self.findings += sub.findings
        elif t.k == "kw" and t.v in ("nil", "true", "false"):
            self.next()
        elif t.k == "op" and t.v == "...":
            self.next()
        elif t.k == "op" and t.v == "{":
            self.table()
        elif t.k == "kw" and t.v == "function":
            self.next()
            self.funcbody()
        elif t.k == "op" and t.v == "@":
            self.attributes()
            self.expect("function")
            self.funcbody()
        elif t.k == "kw" and t.v == "if":
            self.next()
            self.expr()
            self.expect("then")
            self.expr()
            while self.at("elseif"):
                self.next()
                self.expr()
                self.expect("then")
                self.expr()
            self.expect("else")
            self.expr()
        else:
            self.suffixed()
        if self.at("::"):
            self.next()
            self.type_()

    def primary(self):
        t = self.next()
        if t.k == "name":
            return ("name", t)
        if t.k == "op" and t.v == "(":
            self.expr()
            self.expect(")")
            return ("paren", t)
        raise ParseError(f"line {t.line}: unexpected {t.v!r}")

    def suffixed(self, lhs=False):
        kind, tok = self.primary()
        first = (kind, tok)
        used = False
        while True:
            t = self.peek()
            if t.k == "op" and t.v == ".":
                if kind == "name" and not used:
                    self.use(tok)
                    used = True
                self.next()
                self.name()
                kind = "field"
            elif t.k == "op" and t.v == "[":
                if kind == "name" and not used:
                    self.use(tok)
                    used = True
                self.next()
                self.expr()
                self.expect("]")
                kind = "index"
            elif t.k == "op" and t.v == ":" and self.peek(1).k == "name" and (self.peek(2).v in ("(", "{") or self.peek(2).k in ("str", "istr")):
                if kind == "name" and not used:
                    self.use(tok)
                    used = True
                self.next()
                self.name()
                self.call_args()
                kind = "call"
            elif (t.k == "op" and t.v in ("(", "{")) or t.k in ("str", "istr"):
                if t.k == "op" and t.v == "(" and self.peek().line != self.t[self.i - 1].line and kind != "call":
                    pass  # Luau would warn about an ambiguous call across lines; still a call
                if kind == "name" and not used:
                    self.use(tok)
                    used = True
                self.call_args()
                kind = "call"
            else:
                break
        if kind == "name":
            if not lhs:
                self.use(tok)
            return ("name", tok)
        return (kind, first[1])

    def call_args(self):
        t = self.peek()
        if t.k == "str":
            self.next()
        elif t.k == "istr":
            self.simple()
        elif t.v == "{":
            self.table()
        else:
            self.expect("(")
            if not self.at(")"):
                self.explist()
            self.expect(")")

    def table(self):
        self.expect("{")
        while not self.at("}"):
            if self.at("["):
                self.next()
                self.expr()
                self.expect("]")
                self.expect("=")
                self.expr()
            elif self.peek().k == "name" and self.at("=", 1):
                self.next()
                self.next()
                self.expr()
            else:
                self.expr()
            if self.at(",") or self.at(";"):
                self.next()
            else:
                break
        self.expect("}")

    # ── types (skipped, apart from typeof(expr), which reads names) ──
    def generic_list(self, defaults=False):
        self.expect("<")
        while not self.at(">"):
            self.name()
            if self.at("..."):
                self.next()
            if defaults and self.at("="):
                self.next()
                self.type_pack_or_type()
            if self.at(","):
                self.next()
            else:
                break
        self.close_angle()

    def close_angle(self):
        t = self.peek()
        if t.k == "op" and t.v == ">=":
            # `local x: A<B>= y`: split the token
            t.v = "="
            return
        self.expect(">")

    def return_type(self):
        self.type_pack_or_type()

    def type_pack_or_type(self):
        if self.at("..."):
            self.next()
            self.type_()
            return
        if self.peek().k == "name" and self.at("...", 1):
            self.next()
            self.next()
            return
        self.type_()

    def type_(self):
        if self.at("|") or self.at("&"):
            self.next()
        self.simple_type()
        while True:
            if self.at("?"):
                self.next()
            elif self.at("|") or self.at("&"):
                self.next()
                self.simple_type()
            else:
                return

    def simple_type(self):
        t = self.peek()
        if t.k == "kw" and t.v in ("nil", "true", "false"):
            self.next()
            return
        if t.k == "str":
            self.next()
            return
        if t.k == "name" and t.v == "typeof" and self.at("(", 1):
            self.next()
            self.next()
            self.expr()
            self.expect(")")
            return
        if t.k == "name":
            self.next()
            if self.at("."):
                self.next()
                self.name()
            if self.at("<"):
                self.next()
                while not self.at(">") and not self.at(">="):
                    if self.at("("):
                        self.type_pack_paren()
                    else:
                        self.type_pack_or_type()
                    if self.at(","):
                        self.next()
                    else:
                        break
                self.close_angle()
            return
        if t.k == "op" and t.v == "{":
            self.next()
            while not self.at("}"):
                if self.peek().k == "name" and self.peek().v in ("read", "write") and self.peek(1).k == "name" and self.at(":", 2):
                    self.next()
                if self.at("["):
                    self.next()
                    self.type_()
                    self.expect("]")
                    self.expect(":")
                    self.type_()
                elif self.peek().k in ("name", "kw") and self.at(":", 1):
                    self.next()
                    self.next()
                    self.type_()
                else:
                    self.type_()
                if self.at(",") or self.at(";"):
                    self.next()
                else:
                    break
            self.expect("}")
            return
        if t.k == "op" and t.v == "<":
            self.generic_list()
            self.type_pack_paren()
            self.expect("->")
            self.return_type()
            return
        if t.k == "op" and t.v == "(":
            self.type_pack_paren()
            if self.at("->"):
                self.next()
                self.return_type()
            return
        if t.k == "kw" and t.v == "function":
            raise ParseError(f"line {t.line}: unexpected 'function' in a type")
        raise ParseError(f"line {t.line}: unexpected {t.v!r} in a type")

    def type_pack_paren(self):
        self.expect("(")
        while not self.at(")"):
            if (self.peek().k == "name" or self.peek().k == "kw") and self.at(":", 1):
                self.next()
                self.next()
            self.type_pack_or_type()
            if self.at(","):
                self.next()
            else:
                break
        self.expect(")")


def lint_file(path):
    src = open(path, encoding="utf-8").read()
    try:
        toks = lex(src)
    except LexError as e:
        return [(0, "E0", f"lex error: {e}")]
    lt = Linter(toks, path)
    try:
        lt.block()
        if lt.peek().k != "eof":
            raise ParseError(f"line {lt.peek().line}: unexpected {lt.peek().v!r}")
    except ParseError as e:
        lt.findings.append((0, "E0", f"parse error: {e}"))
    except IndexError:
        lt.findings.append((0, "E0", "parse error: unexpected end of file"))
    return sorted(set(lt.findings))


def main(argv):
    paths = argv or ["src"]
    files = []
    for p in paths:
        if os.path.isdir(p):
            for root, _, names in os.walk(p):
                files += [os.path.join(root, n) for n in names if n.endswith((".luau", ".lua"))]
        else:
            files.append(p)
    errors = warnings = 0
    for f in sorted(files):
        for line, code, msg in lint_file(f):
            print(f"{f}:{line}: {code} {msg}")
            if code.startswith("E"):
                errors += 1
            else:
                warnings += 1
    print(f"luau_lint: {len(files)} files, {errors} errors, {warnings} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
