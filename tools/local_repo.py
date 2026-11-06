#!/usr/bin/env python3
"""Small LAN APT source and one-click local builder for Insta10."""
from __future__ import annotations

import gzip
import hashlib
import html
import http.server
import io
import os
import tarfile
import threading
import socket
import subprocess
import shutil
import time
from datetime import datetime, timezone
from pathlib import Path
from email.parser import Parser

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "local-repo"
POOL = DATA / "pool/main/i/insta10"
PACKAGES_PATH = DATA / "dists/stable/main/binary-iphoneos-arm/Packages"
PACKAGES_GZ_PATH = PACKAGES_PATH.with_suffix(".gz")
RELEASE_PATH = DATA / "dists/stable/Release"
PORT = int(os.environ.get("INSTA10_REPO_PORT", "8890"))
_lock = threading.Lock()
_package_version = "not loaded"


def ar_members(path: Path):
    with path.open("rb") as f:
        if f.read(8) != b"!<arch>\n":
            raise ValueError("Not a Debian ar archive")
        while True:
            header = f.read(60)
            if not header:
                return
            if len(header) != 60 or header[58:60] != b"`\n":
                raise ValueError("Invalid ar archive member")
            name = header[:16].decode("ascii", "replace").strip().rstrip("/")
            size = int(header[48:58].decode("ascii").strip())
            data = f.read(size)
            if len(data) != size:
                raise ValueError("Truncated ar member")
            if size % 2:
                f.read(1)
            yield name, data


def package_control(deb: Path) -> dict[str, str]:
    for name, payload in ar_members(deb):
        if not name.startswith("control.tar"):
            continue
        with tarfile.open(fileobj=io.BytesIO(payload), mode="r:*") as archive:
            member = next((m for m in archive.getmembers() if m.name.lstrip("./") == "control"), None)
            if member is None:
                continue
            raw = archive.extractfile(member).read().decode("utf-8", "replace")
            return dict(Parser().parsestr(raw).items())
    raise ValueError("Could not read package control metadata")


def make_index(deb: Path) -> tuple[str, str]:
    global _package_version
    fields = package_control(deb)
    _package_version = fields.get("Version", "unknown")
    content = deb.read_bytes()
    fields["Filename"] = "pool/main/i/insta10/" + deb.name
    fields["Size"] = str(len(content))
    for algorithm in ("md5", "sha1", "sha256"):
        fields[algorithm.upper() if algorithm != "md5" else "MD5sum"] = hashlib.new(algorithm, content).hexdigest()
    stanza = "".join(f"{key}: {value}\n" for key, value in fields.items())
    return stanza + "\n", _package_version


def write_repo(deb: Path) -> None:
    stanza, _ = make_index(deb)
    PACKAGES_PATH.parent.mkdir(parents=True, exist_ok=True)
    PACKAGES_PATH.write_text(stanza)
    packages_gzip = gzip.compress(stanza.encode(), mtime=0)
    PACKAGES_GZ_PATH.write_bytes(packages_gzip)
    # Zebra's add-source flow treats a bare URL as a flat APT source and
    # probes /Packages.{xz,bz2,gz}, so mirror the index at the URL root too.
    (DATA / "Packages").write_text(stanza)
    (DATA / "Packages.gz").write_bytes(packages_gzip)
    hashes = []
    release_root = DATA / "dists/stable"
    for file in (PACKAGES_PATH, PACKAGES_GZ_PATH):
        payload = file.read_bytes()
        relative_name = file.relative_to(release_root).as_posix()
        hashes.append(f" {hashlib.sha256(payload).hexdigest()} {len(payload):16d} {relative_name}")
    release = (
        "Origin: Insta10 Local\nLabel: Insta10\nSuite: stable\nCodename: stable\n"
        "Architectures: iphoneos-arm\nComponents: main\nDescription: Local Insta10 updates\n"
        f"Date: {datetime.now(timezone.utc).strftime('%a, %d %b %Y %H:%M:%S UTC')}\n"
        "SHA256:\n" + "\n".join(hashes) + "\n"
    )
    RELEASE_PATH.parent.mkdir(parents=True, exist_ok=True)
    RELEASE_PATH.write_text(release)
    flat_hashes = []
    for file in (DATA / "Packages", DATA / "Packages.gz"):
        payload = file.read_bytes()
        flat_hashes.append(f" {hashlib.sha256(payload).hexdigest()} {len(payload):16d} {file.name}")
    flat_release = (
        "Origin: Insta10 Local\nLabel: Insta10\nSuite: ./\nCodename: ./\n"
        "Architectures: iphoneos-arm\nDescription: Local Insta10 updates\n"
        f"Date: {datetime.now(timezone.utc).strftime('%a, %d %b %Y %H:%M:%S UTC')}\n"
        "SHA256:\n" + "\n".join(flat_hashes) + "\n"
    )
    (DATA / "Release").write_text(flat_release)


def current_package() -> Path:
    packages = sorted(POOL.glob("*.deb"), key=lambda item: item.stat().st_mtime, reverse=True)
    if not packages:
        raise FileNotFoundError("В локальном репозитории пока нет .deb")
    return packages[0]


def build_local() -> str:
    with _lock:
        env = os.environ.copy()
        env["THEOS"] = env.get("THEOS", str(Path.home() / "theos"))
        result = subprocess.run(
            ["/usr/bin/make", "clean", "package", "FINALPACKAGE=1"],
            cwd=ROOT, env=env, capture_output=True, text=True, timeout=300,
        )
        if result.returncode:
            detail = (result.stderr or result.stdout)[-3000:]
            raise RuntimeError("Сборка не прошла:\n" + detail)
        candidates = sorted((ROOT / "packages").glob("*.deb"), key=lambda item: item.stat().st_mtime, reverse=True)
        if not candidates:
            raise FileNotFoundError("Сборка завершилась, но .deb не найден")
        built = candidates[0]
        fields = package_control(built)
        if fields.get("Package") != "com.imcatsrsly.insta10":
            raise ValueError("Полученный .deb не похож на пакет Insta10")
        version = fields.get("Version", "unknown")
        POOL.mkdir(parents=True, exist_ok=True)
        final = POOL / f"insta10_{version}_iphoneos-arm.deb"
        if built.resolve() != final.resolve():
            shutil.copy2(built, final)
        for old in POOL.glob("*.deb"):
            if old != final:
                old.unlink()
        write_repo(final)
        return version


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DATA), **kwargs)

    def do_HEAD(self):
        return super().do_HEAD()

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            try:
                version = package_control(current_package()).get("Version", "unknown")
                error = ""
            except Exception as exc:
                version = _package_version
                error = f"<p class='error'>{html.escape(str(exc))}</p>"
            ip = os.environ.get("INSTA10_REPO_HOST")
            if not ip:
                try:
                    interface = subprocess.run(["/sbin/ifconfig", "en0"], check=True, capture_output=True, text=True).stdout
                    ip = next(line.split()[1] for line in interface.splitlines() if line.strip().startswith("inet "))
                except (OSError, subprocess.CalledProcessError, StopIteration):
                    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    try:
                        probe.connect(("1.1.1.1", 80))
                        ip = probe.getsockname()[0]
                    finally:
                        probe.close()
            source = f"http://{ip}:{PORT}/"
            page = f"""<!doctype html><meta name="viewport" content="width=device-width, initial-scale=1"><title>Insta10 updates</title>
<style>body{{font:16px -apple-system,BlinkMacSystemFont,sans-serif;background:#f4f4f7;color:#222;margin:0;padding:24px}}main{{max-width:520px;margin:8vh auto;background:white;border-radius:16px;padding:24px;box-shadow:0 6px 24px #0001}}h1{{margin-top:0}}button,a.btn{{display:block;box-sizing:border-box;width:100%;padding:15px;border:0;border-radius:10px;background:#3897f0;color:white;text-align:center;font:600 16px inherit;text-decoration:none;margin:14px 0}}small,.muted{{color:#777}}code{{word-break:break-all}}.error{{color:#b00}}</style>
<main><h1>Insta10 · локальные обновления</h1><p>В репозитории сейчас версия <b>{html.escape(version)}</b>.</p>{error}
<form method="post" action="/build"><button>Собрать и обновить локальный репозиторий</button></form>
<a class="btn" href="zbra://sources/add/{html.escape(source)}">Добавить источник в Zebra</a>
<p>Источник Zebra: <code>{html.escape(source)}</code></p>
<p class="muted"><b>Источник Zebra добавляется один раз.</b> Для новой сборки нажми верхнюю кнопку. После сообщения об успехе обнови список пакетов в Zebra и нажми Upgrade у Insta10. Mac должен быть включён, а эта страница — доступна по Wi‑Fi.</p>
<p><a href="/pool/main/i/insta10/">Список deb-файлов</a></p></main>"""
            body = page.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        return super().do_GET()

    def do_POST(self):
        if self.path == "/build":
            try:
                version = build_local()
                self.send_response(303)
                self.send_header("Location", "/?built=" + version)
                self.end_headers()
            except Exception as exc:
                body = ("Local build failed: " + str(exc)).encode()
                self.send_error(500, body.decode())
            return
        self.send_error(404)

    def log_message(self, format, *args):
        print("[%s] %s" % (self.log_date_time_string(), format % args), flush=True)


def main():
    cached = sorted(POOL.glob("*.deb"), key=lambda item: item.stat().st_mtime, reverse=True)
    if not cached:
        packages = sorted((ROOT / "packages").glob("*.deb"), key=lambda item: item.stat().st_mtime, reverse=True)
        if packages:
            cached = packages[:1]
            POOL.mkdir(parents=True, exist_ok=True)
            target = POOL / packages[0].name
            packages[0].replace(target)
            cached = [target]
    if not cached:
        raise FileNotFoundError("Build Insta10 first; no local .deb was found")
    _, version = make_index(cached[0])
    write_repo(cached[0])
    print(f"Serving local Insta10 {version}", flush=True)
    server = http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Insta10 repo listening on port {PORT}; open http://<Mac-IP>:{PORT}/ on the iPhone", flush=True)
    print("Keep this process running while using the local Zebra source. Ctrl+C stops it.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Stopping local repo", flush=True)


if __name__ == "__main__":
    main()
