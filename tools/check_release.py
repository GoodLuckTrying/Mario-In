#!/usr/bin/env python3
"""Check native-port release consistency without building or installing files.

Run the project's gameplay checks first. This helper validates their receipt's
structure/hash, not the adequacy or authenticity of the underlying tests.
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_object(path):
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    require(isinstance(value, dict), f"Expected a JSON object: {path}")
    return value


def expected_hash(document, key):
    value = document.get(key)
    require(isinstance(value, str) and re.fullmatch(r"[0-9a-fA-F]{64}", value),
            f"Missing or invalid {key}")
    return value.lower()


def apply_ips(base, patch):
    """Apply standard IPS, including RLE and optional EOF output-size field."""
    require(patch.startswith(b"PATCH"), "Invalid IPS header")
    result = bytearray(base)
    cursor = 5

    def take(count):
        nonlocal cursor
        require(cursor + count <= len(patch), "Truncated IPS record or missing EOF")
        value = patch[cursor:cursor + count]
        cursor += count
        return value

    while True:
        address_bytes = take(3)
        if address_bytes == b"EOF":
            break
        offset = int.from_bytes(address_bytes, "big")
        count = int.from_bytes(take(2), "big")
        if count:
            data = take(count)
        else:
            count = int.from_bytes(take(2), "big")
            require(count > 0, "IPS RLE record has zero length")
            data = take(1) * count
        end = offset + count
        if end > len(result):
            result.extend(bytes(end - len(result)))
        result[offset:end] = data

    remaining = len(patch) - cursor
    require(remaining in (0, 3), "Unexpected data after IPS EOF")
    if remaining == 3:
        size = int.from_bytes(take(3), "big")
        if size > len(result):
            result.extend(bytes(size - len(result)))
        else:
            del result[size:]
    return bytes(result)


def check_release(rom, manifest, receipt, *, base=None, smb=None, ips=None,
                  installed=None):
    """Return a JSON-serializable report; reject any inconsistent input."""
    rom, manifest, receipt = (Path(p).resolve() for p in (rom, manifest, receipt))
    data = rom.read_bytes()
    actual = sha256(data)
    metadata, verification = read_object(manifest), read_object(receipt)
    require(actual == expected_hash(metadata, "output_sha256"),
            "Candidate ROM differs from build manifest")
    require(actual == expected_hash(verification, "rom_sha256"),
            "Verification receipt belongs to a different ROM")
    checks = verification.get("checks")
    require(isinstance(checks, list) and len(checks) > 0,
            "Verification receipt needs a nonempty checks array")
    for index, check in enumerate(checks):
        require(isinstance(check, dict), f"Invalid check at index {index}")
        name = check.get("name")
        require(isinstance(name, str) and bool(name.strip()),
                f"Unnamed check at index {index}")
        require(check.get("passed") is True, f"Check did not pass: {name}")
    if "passed" in verification:
        aggregate = verification["passed"]
        require(aggregate is True or
                (type(aggregate) is int and aggregate == len(checks)),
                "Receipt aggregate does not report all checks passed")

    report = {"passed": True, "rom": str(rom), "rom_sha256": actual,
              "manifest": str(manifest), "receipt": str(receipt),
              "checks_passed": len(checks)}
    base_data = None
    for label, path, key in (("base", base, "base_sha256"),
                             ("smb", smb, "smb_sha256")):
        if path is not None:
            path = Path(path).resolve()
            payload = path.read_bytes()
            digest = sha256(payload)
            require(digest == expected_hash(metadata, key),
                    f"{label} ROM differs from build manifest")
            report[label] = {"path": str(path), "sha256": digest}
            if label == "base":
                require(path != rom, "Base and candidate must be separate paths")
                base_data = payload
    if ips is not None:
        require(base_data is not None, "IPS reconstruction requires --base")
        path = Path(ips).resolve()
        patch = path.read_bytes()
        require(apply_ips(base_data, patch) == data,
                "IPS does not reconstruct the candidate exactly")
        report["ips"] = {"path": str(path), "sha256": sha256(patch),
                         "reconstructs_rom": True}
    if installed is not None:
        path = Path(installed).resolve()
        require(path.read_bytes() == data, "Installed ROM differs from candidate")
        report["installed"] = {"path": str(path), "matches_candidate": True}
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("rom", "manifest", "receipt"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--base", type=Path, help="Check the original ROM hash")
    parser.add_argument("--smb", type=Path, help="Check the SMB source ROM hash")
    parser.add_argument("--ips", type=Path, help="Reconstruct from --base")
    parser.add_argument("--installed", type=Path, help="Compare installed bytes")
    parser.add_argument("--report", type=Path, help="Optionally save JSON evidence")
    args = parser.parse_args()
    if args.ips is not None and args.base is None:
        parser.error("--ips requires --base")
    if args.report is not None:
        inputs = (args.rom, args.manifest, args.receipt, args.base, args.smb,
                  args.ips, args.installed)
        if any(p is not None and args.report.resolve() == p.resolve() for p in inputs):
            parser.error("--report must not overwrite an input file")
    try:
        result = check_release(args.rom, args.manifest, args.receipt,
                               base=args.base, smb=args.smb, ips=args.ips,
                               installed=args.installed)
    except (OSError, ValueError) as error:
        result = {"passed": False, "error": str(error)}
    output = json.dumps(result, indent=2)
    if args.report is not None:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(output + "\n", encoding="utf-8")
    print(output)
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
