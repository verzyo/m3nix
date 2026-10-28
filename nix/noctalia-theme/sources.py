# lists the noctalia sources reachable from the given files through local includes
import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1]) / "src"
include = re.compile(r'^\s*#\s*include\s+"([^"]+)"', re.M)

seen = set()
todo = [pathlib.Path(arg) for arg in sys.argv[2:]]
while todo:
    file = todo.pop()
    if file in seen:
        continue
    seen.add(file)
    for header in include.findall(file.read_text(errors="ignore")):
        path = src / header
        if not path.exists():
            continue
        todo.append(path)
        for ext in (".cpp", ".cc"):
            if path.with_suffix(ext).exists():
                todo.append(path.with_suffix(ext))

print("\n".join(sorted(str(p) for p in seen if p.is_relative_to(src) and p.suffix in (".cpp", ".cc"))))
