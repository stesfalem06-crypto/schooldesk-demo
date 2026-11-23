#!/usr/bin/env python3
"""Fail if a directory holds a private update key.

A private key is a file named *.priv, a PEM block, or a file (or a single
line, or a zip entry) whose whole contents are the base64 form of a 64-byte
ed25519 private key. A 32-byte public key is allowed.
"""

import base64
import io
import os
import re
import sys
import zipfile

# A line or a whole file that is only the base64 of 64 raw bytes.
_RAW_KEY = re.compile(rb"^[A-Za-z0-9+/_-]{86}={0,2}$")
# A real PEM block, not the header string a library uses to recognize one.
_PEM = re.compile(
    rb"-----BEGIN ((?:RSA |EC |OPENSSH |DSA )?)PRIVATE KEY-----\s+"
    rb"([A-Za-z0-9+/=\r\n]+?)\s*"
    rb"-----END \1PRIVATE KEY-----"
)

ZIP_SUFFIXES = (".zip", ".apk", ".jar", ".smsu", ".nupkg")


def is_private_key_material(data: bytes) -> bool:
    text = data.strip()
    if not _RAW_KEY.fullmatch(text):
        return False
    for decoder in (base64.b64decode, base64.urlsafe_b64decode):
        try:
            raw = decoder(text, validate=True)
        except Exception:
            continue
        if len(raw) == 64:
            return True
    return False


def pem_private_key(data: bytes) -> bool:
    for match in _PEM.finditer(data):
        body = re.sub(rb"\s+", b"", match.group(2))
        try:
            raw = base64.b64decode(body, validate=True)
        except Exception:
            continue
        if len(raw) >= 32:
            return True
    return False


def bad_name(name: str) -> bool:
    base = name.replace("\\", "/").rsplit("/", 1)[-1].lower()
    return base.endswith(".priv") or base in {"id_rsa", "id_ed25519"}


def problem_in(data: bytes) -> str:
    if is_private_key_material(data):
        return "ed25519 private key"
    if pem_private_key(data):
        return "PEM private key"
    if b"\x00" in data[:4096]:
        return ""
    sample = data if len(data) <= 2_000_000 else data[:200_000] + b"\n" + data[-200_000:]
    for line in sample.splitlines():
        if is_private_key_material(line):
            return "ed25519 private key"
    return ""


def scan_zip(data: bytes, label: str, hits: list[str]) -> None:
    try:
        archive = zipfile.ZipFile(io.BytesIO(data))
    except zipfile.BadZipFile:
        return
    for info in archive.infolist():
        if info.is_dir():
            continue
        path = f"{label}:{info.filename}"
        if bad_name(info.filename):
            hits.append(path)
            continue
        if info.file_size > 80_000_000:
            continue
        blob = archive.read(info)
        reason = problem_in(blob)
        if reason:
            hits.append(f"{path} ({reason})")
        lower = info.filename.lower()
        if lower.endswith(ZIP_SUFFIXES) or blob[:2] == b"PK":
            scan_zip(blob, path, hits)


def scan_tree(root: str) -> list[str]:
    hits: list[str] = []
    for dirpath, _, files in os.walk(root):
        for name in files:
            path = os.path.join(dirpath, name)
            if bad_name(name):
                hits.append(path)
            try:
                with open(path, "rb") as handle:
                    data = handle.read()
            except OSError as exc:
                hits.append(f"{path} ({exc})")
                continue
            reason = problem_in(data)
            if reason:
                hits.append(f"{path} ({reason})")
            lower = name.lower()
            if lower.endswith(ZIP_SUFFIXES) or data[:2] == b"PK":
                scan_zip(data, path, hits)
    return hits


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: reject_private_keys.py DIRECTORY", file=sys.stderr)
        return 2
    root = sys.argv[1]
    if not os.path.isdir(root):
        print(f"not a directory: {root}", file=sys.stderr)
        return 2
    hits = scan_tree(root)
    if hits:
        print("private key material found:")
        for hit in hits:
            print(hit)
        return 1
    print(f"no private key in {root}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
