"""Zero Return - Open Cloud model upload (runs inside Blender's Python on the dev PC).

Reads the API key from ~/efb_opencloud_key.txt (never printed, never stored in the repo).
Uploads .fbx/.glb files as Roblox Model assets owned by the developer account and records
results in assets/upload_manifest.json keyed by asset key + file hash, so unchanged files are skipped.
Usage inside Blender:  g = {}; exec(open(PATH).read(), g); g["upload_model"](fbx_path, "ZR_KEY")
"""
import hashlib, json, os, time, uuid, urllib.error, urllib.request

ROOT = os.path.join(os.path.expanduser("~"), "Documents", "EscapeFromBloxov")
KEY_PATH = os.path.join(os.path.expanduser("~"), "efb_opencloud_key.txt")
MANIFEST = os.path.join(ROOT, "assets", "upload_manifest.json")
API = "https://apis.roblox.com/assets/v1"
USER_ID = "5437527887"
CTYPES = {".fbx": "model/fbx", ".glb": "model/gltf-binary", ".gltf": "model/gltf+json", ".ogg": "audio/ogg", ".wav": "audio/wav", ".mp3": "audio/mpeg", ".png": "image/png"}


def _key():
    with open(KEY_PATH, "r", encoding="utf-8-sig") as f:
        k = f.read().strip()
    if len(k) < 20:
        raise RuntimeError("API key file missing or too short: " + KEY_PATH)
    return k


def _request(method, url, data=None, ctype=None):
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("x-api-key", _key())
    if ctype:
        req.add_header("Content-Type", ctype)
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            return resp.status, json.loads(resp.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        return e.code, {"error": e.read().decode(errors="replace")[:500]}


def _multipart(fields, files):
    b = uuid.uuid4().hex
    body = bytearray()
    for name, value in fields.items():
        body += f'--{b}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode()
    for name, (fname, ctype, data) in files.items():
        body += f'--{b}\r\nContent-Disposition: form-data; name="{name}"; filename="{fname}"\r\nContent-Type: {ctype}\r\n\r\n'.encode()
        body += data + b"\r\n"
    body += f"--{b}--\r\n".encode()
    return bytes(body), "multipart/form-data; boundary=" + b


def load_manifest():
    if os.path.exists(MANIFEST):
        with open(MANIFEST, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_manifest(m):
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(m, f, indent=1, sort_keys=True)


def upload_model(path, key, description="Zero Return original asset (Blender pipeline)", force=False, asset_type="Model"):
    with open(path, "rb") as f:
        data = f.read()
    digest = hashlib.sha1(data).hexdigest()
    man = load_manifest()
    prev = man.get(key)
    if prev and prev.get("sha1") == digest and prev.get("assetId") and not force:
        return {"ok": True, "assetId": prev["assetId"], "skipped": True}
    meta = {"assetType": asset_type, "displayName": key[:50], "description": description,
            "creationContext": {"creator": {"userId": USER_ID}}}
    body, ct = _multipart({"request": json.dumps(meta)},
                          {"fileContent": (os.path.basename(path), CTYPES[os.path.splitext(path)[1].lower()], data)})
    status, res = _request("POST", API + "/assets", body, ct)
    if status >= 300:
        return {"ok": False, "status": status, "res": res}
    op = res.get("operationId") or res.get("path", "").split("/")[-1]
    for i in range(40):
        if res.get("done"):
            break
        time.sleep(min(1 + i * 0.5, 4))
        status, res = _request("GET", f"{API}/operations/{op}")
        if status >= 300:
            return {"ok": False, "status": status, "res": res, "op": op}
    asset_id = (res.get("response") or {}).get("assetId")
    if not asset_id:
        return {"ok": False, "op": op, "res": res}
    man[key] = {"assetId": str(asset_id), "sha1": digest, "file": os.path.relpath(path, ROOT),
                "uploaded": time.strftime("%Y-%m-%d %H:%M:%S")}
    save_manifest(man)
    return {"ok": True, "assetId": str(asset_id)}


def upload_audio_dir(folder, prefix="ZR_SFX_"):
    """Upload every .ogg in folder as an Audio asset (skips unchanged files via the manifest)."""
    out = {}
    for name in sorted(os.listdir(folder)):
        if name.startswith(prefix) and name.endswith(".ogg"):
            key = name[:-4]
            out[key] = upload_model(os.path.join(folder, name), key, "Zero Return original synthesized sound effect", asset_type="Audio")
    return out
