# works out what to compile from upstream itself, so restructures upstream need no change here:
# the sources reachable from the entry files, plus the include dirs and string defines meson declares
#
# usage: plan.py <noctalia source> <sources.txt> <cflags.txt> <entry>...
# reads $out and $version for the install prefix and version defines
import os
import pathlib
import re
import shlex
import sys

root = pathlib.Path(sys.argv[1]).resolve()
sources_out, cflags_out = sys.argv[2], sys.argv[3]
entries = [pathlib.Path(arg).resolve() for arg in sys.argv[4:]]

meson_files = sorted(root.rglob("meson.build"))
include_re = re.compile(r'^\s*#\s*include\s+"([^"]+)"', re.M)

# every include_directories(...) upstream declares, resolved against its meson.build
roots = {}  # path -> is_system
for meson in meson_files:
    for args in re.findall(r"include_directories\(([^)]*)\)", meson.read_text()):
        system = re.search(r"is_system\s*:\s*true", args) is not None
        for directory in re.findall(r"'([^']*)'", args):
            path = (meson.parent / directory).resolve()
            if path.is_dir():
                roots[path] = roots.get(path, False) or system


def resolve(header, includer):
    # quoted includes look next to the including file first, then on the include path
    for base in [includer.parent, *roots]:
        path = base / header
        if path.is_file():
            return path.resolve()
    return None


seen = set()
used_roots = set()
missing = set()
todo = list(entries)
while todo:
    file = todo.pop()
    if file in seen:
        continue
    seen.add(file)
    for header in include_re.findall(file.read_text(errors="ignore")):
        path = resolve(header, file)
        if path is None:
            missing.add(f"{file.relative_to(root) if file.is_relative_to(root) else file.name}: {header}")
            continue
        used_roots.update(r for r in roots if path.is_relative_to(r) and (r / header).is_file())
        todo.append(path)
        for ext in (".cpp", ".cc"):
            if path.with_suffix(ext).is_file():
                todo.append(path.with_suffix(ext))

# generated headers (wayland protocols etc.) can't be found; fine unless the build then fails
for line in sorted(missing):
    print(f"plan.py: not found (generated?): {line}", file=sys.stderr)

sources = sorted(p for p in seen if p.suffix in (".cpp", ".cc"))
pathlib.Path(sources_out).write_text("".join(f"{p}\n" for p in sources))

# string defines like '-DNAME="' + get_option('prefix') / get_option('datadir') + '"'
options = {
    "prefix": os.environ["out"],
    "bindir": "bin",
    "datadir": "share",
    "libdir": "lib",
    "libexecdir": "libexec",
    "sysconfdir": "etc",
    "localstatedir": "var",
}


def evaluate(expr):
    parts = []
    for term in re.split(r"\s*\+\s*", expr.strip()):
        pieces = []
        for piece in re.split(r"\s*/\s*", term):
            if m := re.fullmatch(r"get_option\('(\w+)'\)", piece):
                if m[1] not in options:
                    return None
                pieces.append(options[m[1]])
            elif piece == "meson.project_version()":
                pieces.append(os.environ["version"])
            elif m := re.fullmatch(r"'([^']*)'", piece):
                pieces.append(m[1])
            else:
                return None  # a meson variable, can't know its value
        parts.append(os.path.join(*pieces) if len(pieces) > 1 else pieces[0])
    return "".join(parts)


used_text = "\n".join(p.read_text(errors="ignore") for p in seen)
defines = {}
for meson in meson_files:
    if meson.is_relative_to(root / "third_party"):
        continue
    for name, expr in re.findall(r"""'-D(\w+)="'\s*\+\s*(.+?)\s*\+\s*'"'""", meson.read_text()):
        value = evaluate(expr)
        if value is not None and re.search(rf"\b{name}\b", used_text):
            defines.setdefault(name, value)

flags = [("-isystem" if roots[r] else "-I") + str(r) for r in sorted(used_roots)]
flags += [f'-D{name}="{value}"' for name, value in sorted(defines.items())]
pathlib.Path(cflags_out).write_text(shlex.join(flags) + "\n")
print(f"plan.py: {len(sources)} sources, {len(used_roots)} include dirs, {len(defines)} defines", file=sys.stderr)
