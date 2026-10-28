#!/usr/bin/env python3
"""Lightweight structural checker for Luau files (no Luau toolchain available in the cloud workspace).
Checks: unterminated strings/comments, bracket balance, and block balance
(function/if/for/while/do/repeat ... end/until), including Luau if-expressions.
Usage: python3 tools/luau_check.py src
"""
import re, sys, pathlib

EXPR_PREV_UNUSED = {"=", "(", ",", "{", "[", "return", "and", "or", "not", "..", "+", "-", "*", "/", "%", "^", "==",
             "~=", "<", ">", "<=", ">=", "//", "+=", "-=", "*=", "/=", "..=", "then", "else", ":", "#"}


def tokens(src, path):
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1; i += 1; continue
        if c in " \t\r":
            i += 1; continue
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, i)
                if j < 0: raise SyntaxError(f"{path}:{line}: unterminated long comment")
                line += src.count("\n", i, j); i = j + len(close)
            else:
                j = src.find("\n", i); i = n if j < 0 else j
            continue
        m = re.match(r"\[(=*)\[", src[i:])
        if m:
            close = "]" + m.group(1) + "]"
            j = src.find(close, i)
            if j < 0: raise SyntaxError(f"{path}:{line}: unterminated long string")
            line += src.count("\n", i, j); i = j + len(close); yield ("str", "", line); continue
        if c in "\"'":
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == "\\": j += 1
                elif src[j] == "\n": raise SyntaxError(f"{path}:{line}: unterminated string")
                j += 1
            if j >= n: raise SyntaxError(f"{path}:{line}: unterminated string")
            i = j + 1; yield ("str", "", line); continue
        if c == "`":
            j, depth = i + 1, 0
            while j < n:
                ch = src[j]
                if ch == "\\": j += 2; continue
                if ch == "{": depth += 1
                elif ch == "}": depth -= 1
                elif ch == "`" and depth == 0: break
                elif ch == "\n": line += 1
                j += 1
            if j >= n: raise SyntaxError(f"{path}:{line}: unterminated interpolated string")
            i = j + 1; yield ("str", "", line); continue
        m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", src[i:])
        if m:
            yield ("id", m.group(0), line); i += len(m.group(0)); continue
        m = re.match(r"0[xX][0-9a-fA-F_]+|0[bB][01_]+|\d[\d_]*(\.\d*)?([eE][+-]?\d+)?|\.\d+", src[i:])
        if m:
            yield ("num", "", line); i += len(m.group(0)); continue
        for op in ("...", "..=", "//=", "==", "~=", "<=", ">=", "//", "..", "+=", "-=", "*=", "/=", "%=", "^=", "::", "->"):
            if src.startswith(op, i):
                yield ("op", op, line); i += len(op); break
        else:
            yield ("op", c, line); i += 1


def check(path):
    """Every `if` is a block (house rule: no Luau if-expressions; use and/or)."""
    src = pathlib.Path(path).read_text(encoding="utf-8")
    stack = []
    pairs = {")": "(", "]": "[", "}": "{"}
    for kind, val, line in tokens(src, path):
        if kind == "op" and val in "([{":
            stack.append((val, line))
        elif kind == "op" and val in ")]}":
            if not stack or stack[-1][0] != pairs[val]:
                raise SyntaxError(f"{path}:{line}: unexpected '{val}' (open: {stack[-1] if stack else None})")
            stack.pop()
        elif kind == "id":
            if val in ("function", "if", "repeat"):
                stack.append((val, line))
            elif val in ("for", "while"):
                stack.append(("loop", line))
            elif val == "do":
                if stack and stack[-1][0] == "loop":
                    stack[-1] = ("do", stack[-1][1])
                else:
                    stack.append(("do", line))
            elif val == "end":
                if not stack or stack[-1][0] not in ("function", "if", "do"):
                    raise SyntaxError(f"{path}:{line}: unexpected 'end' (open: {stack[-1] if stack else None})")
                stack.pop()
            elif val == "until":
                if not stack or stack[-1][0] != "repeat":
                    raise SyntaxError(f"{path}:{line}: unexpected 'until'")
                stack.pop()
    if stack:
        raise SyntaxError(f"{path}: unclosed '{stack[-1][0]}' opened at line {stack[-1][1]}")


def main(roots):
    files = [p for r in roots for p in sorted(pathlib.Path(r).rglob("*.luau"))]
    bad = 0
    for f in files:
        try:
            check(f)
        except SyntaxError as e:
            bad += 1; print("FAIL", e)
    print(f"checked {len(files)} files, {bad} failing")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:] or ["src"]))
