"""Small repository check; excludes generated files via Git's ignore rules."""
import pathlib
import re
import subprocess
import sys

patterns = [
    re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(r'"private_key"\s*:\s*"[^"\s]+'),
    re.compile(r"(?:ghp_|github_pat_)[A-Za-z0-9_]{30,}"),
    re.compile(r"AKIA[A-Z0-9]{16}"),
]
paths = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"]
).decode().split("\0")
failures = []
for name in set(paths):
    path = pathlib.Path(name)
    if not path.is_file() or path.suffix.lower() not in {
        ".dart", ".kt", ".kts", ".json", ".yaml", ".yml", ".md", ".py", ".mjs", ".xml"
    }:
        continue
    source = path.read_text(encoding="utf-8", errors="replace")
    if any(pattern.search(source) for pattern in patterns):
        failures.append(name)
if failures:
    print("Possible private credentials in: " + ", ".join(sorted(failures)))
    sys.exit(1)
print("No matching private credential patterns found.")
