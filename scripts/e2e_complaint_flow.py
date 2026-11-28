#!/usr/bin/env python3
"""DenuPe end-to-end citizen complaint, AI and business-rule checks."""
import base64, json, os, sys, uuid
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse
import requests

BASE = os.environ.get("DENUPE_API_URL", "https://denupe-backend.onrender.com").rstrip("/")
EMAIL = os.environ["DENUPE_TEST_EMAIL"]
PASSWORD = os.environ["DENUPE_TEST_PASSWORD"]
SECOND_EMAIL = os.environ.get("DENUPE_TEST_SECOND_EMAIL", "")
SECOND_PASSWORD = os.environ.get("DENUPE_TEST_SECOND_PASSWORD", "")
LAT = float(os.environ.get("DENUPE_TEST_LATITUDE", "-12.0464"))
LON = float(os.environ.get("DENUPE_TEST_LONGITUDE", "-77.0428"))
S = requests.Session()
TOKEN = ""
RESULTS = []
COMPLAINT_ID = ""

def record(name, ok, detail=""):
    RESULTS.append({"test": name, "result": "PASS" if ok else "FAIL", "detail": str(detail)[:500]})
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f": {detail}" if detail else ""), flush=True)

def call(method, path, *, token=None, expected=(200,), **kwargs):
    headers = kwargs.pop("headers", {})
    active = TOKEN if token is None else token
    if active:
        headers["Authorization"] = f"Bearer {active}"
    r = S.request(method, BASE + "/api/v1" + path, headers=headers, timeout=45, **kwargs)
    if r.status_code not in expected:
        raise AssertionError(f"{method} {path}: HTTP {r.status_code}, esperado {expected}: {r.text[:900]}")
    return r

def body(r):
    try: return r.json()
    except ValueError: raise AssertionError(f"Respuesta no JSON: {r.text[:300]}")

def find_value(value, keys):
    if isinstance(value, dict):
        for k in keys:
            if value.get(k) is not None and str(value[k]).strip(): return str(value[k]).strip()
        for v in value.values():
            found = find_value(v, keys)
            if found: return found
    if isinstance(value, list):
        for v in value:
            found = find_value(v, keys)
            if found: return found
    return None

def run():
    global TOKEN, COMPLAINT_ID
    if not SECOND_EMAIL or not SECOND_PASSWORD:
        raise AssertionError("Configura DENUPE_TEST_SECOND_EMAIL y DENUPE_TEST_SECOND_PASSWORD para validar el aislamiento entre usuarios.")
    h = S.get(BASE + "/health", timeout=45)
    if h.status_code != 200: raise AssertionError(f"API health HTTP {h.status_code}: {h.text[:300]}")
    record("API disponible", True, BASE)

    auth = body(call("POST", "/auth/login", token="", json={"email": EMAIL, "password": PASSWORD}))
    TOKEN = auth.get("access_token", "")
    if not TOKEN: raise AssertionError("Login sin access_token")
    record("Login ciudadano", True, EMAIL)

    me = body(call("GET", "/auth/me"))
    profile = me.get("profile") or {}
    record("Sesión y rol ciudadano", profile.get("role") == "citizen", profile.get("role"))
    dni = str(profile.get("dni") or "")
    if not profile.get("full_name") or len(dni) != 8 or not dni.isdigit() or not profile.get("phone"):
        raise AssertionError("El usuario de prueba requiere nombre, DNI válido de 8 dígitos y teléfono.")

    title = "E2E_AUTOMATED " + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + " " + uuid.uuid4().hex[:6]
    description = ("Prueba automatizada ficticia de DenuPe: luminaria pública apagada en una vía peatonal. "
                   "Requiere revisión municipal. No representa un incidente real ni solicita emergencia.")

    # Todas las funciones IA publicadas por el backend principal.
    ai_category = body(call("POST", "/ia/sugerir-categoria", json={
        "titulo": "Luminaria pública apagada en vía peatonal", "descripcion": description}))
    record("IA: sugerencia de categoría", isinstance(ai_category, dict) and ai_category.get("sugerida") is True
           and bool(ai_category.get("categoria")), json.dumps(ai_category, ensure_ascii=False)[:300])

    territory = body(call("GET", "/ia/territorio/catalogo-distrital", params={"latitud": LAT, "longitud": LON}))
    record("IA: catálogo territorial", isinstance(territory, (dict, list)), json.dumps(territory, ensure_ascii=False)[:300])
    ubigeo = find_value(territory, ("ubigeo", "district_ubigeo"))
    district = find_value(territory, ("distrito", "district", "nombre_distrito")) or "Lima"

    resolved = body(call("GET", "/ia/territorio/resolver-distrito",
                         params={"latitud": LAT, "longitud": LON, **({"ubigeo": ubigeo} if ubigeo else {})}))
    record("IA: resolución territorial por GPS", isinstance(resolved, (dict, list)), json.dumps(resolved, ensure_ascii=False)[:300])

    categories = body(call("GET", "/catalogos/categorias"))
    if not isinstance(categories, list) or not categories:
        raise AssertionError("Catálogo de categorías vacío: no se puede crear la denuncia.")
    ai_category_name = str(ai_category.get("categoria") or "").strip() if isinstance(ai_category, dict) else ""
    matched_category = next((x for x in categories if ai_category_name and
        ai_category_name.casefold() in {str(x.get("code", "")).casefold(), str(x.get("name", "")).casefold()}), None)
    record("IA: categoría sugerida corresponde al catálogo oficial",
           matched_category is not None, f"sugerencia={ai_category_name}; coincidencia={matched_category is not None}")
    category = matched_category or categories[0]
    category_id = category["id"]
    category_code = category.get("code") or category.get("name") or "alumbrado"

    available = body(call("GET", "/ia/entidades/disponibles", params={
        "categoria": category_code, "latitud": LAT, "longitud": LON,
        **({"ubigeo": ubigeo} if ubigeo else {})}))
    record("IA: entidades disponibles por categoría y GPS", isinstance(available, (dict, list)),
           json.dumps(available, ensure_ascii=False)[:300])

    suggestion = body(call("POST", "/ia/sugerir-entidad", json={
        "categoria": category_code,
        "departamento": find_value(territory, ("departamento", "department")) or "Lima",
        "provincia": find_value(territory, ("provincia", "province")) or "Lima",
        "distrito": district, "titulo": "Luminaria pública apagada en vía peatonal",
        "descripcion": description, "latitud": LAT, "longitud": LON}))
    record("IA: sugerencia de entidad responsable",
           isinstance(suggestion, dict) and "sugerida" in suggestion,
           json.dumps(suggestion, ensure_ascii=False)[:300])

    payload = {"category_id": category_id, "title": title, "description": description,
               "address": "Ubicación ficticia de prueba automatizada, " + district,
               "latitude": LAT, "longitude": LON}
    if ubigeo and len(ubigeo) == 6: payload["district_ubigeo"] = ubigeo

    invalid = call("POST", "/denuncias", json={**payload, "title": "abc", "description": "corta"}, expected=(422,))
    record("Regla: rechazar campos obligatorios inválidos", invalid.status_code == 422, "HTTP 422")
    invalid_category = call("POST", "/denuncias", json={**payload, "category_id": str(uuid.uuid4())}, expected=(422,))
    record("Regla: rechazar categoría inexistente", invalid_category.status_code == 422, "HTTP 422")

    created = body(call("POST", "/denuncias", json=payload, expected=(201,)))
    COMPLAINT_ID = str(created.get("id") or "")
    if not COMPLAINT_ID: raise AssertionError("La creación no devolvió ID: " + str(created)[:500])
    record("Crear denuncia ficticia", created.get("status") == "recibida",
           f"id={COMPLAINT_ID}; estado={created.get('status')}")

    detail = body(call("GET", "/denuncias/" + COMPLAINT_ID))
    record("Consultar denuncia y verificar propietario",
           detail.get("id") == COMPLAINT_ID and detail.get("user_id") == me.get("id"))
    listing = body(call("GET", "/denuncias", params={"limit": 100}))
    record("Denuncia visible en listado propio",
           isinstance(listing, list) and any(str(x.get("id")) == COMPLAINT_ID for x in listing))
    history = body(call("GET", "/denuncias/" + COMPLAINT_ID + "/historial"))
    record("Historial inicial recibido",
           isinstance(history, list) and any(x.get("status") == "recibida" for x in history))

    # Exercise the exact presigned storage flow used by Flutter. A failure is recorded,
    # but the remaining business-rule checks still run and appear in the report.
    try:
        png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j4S8AAAAASUVORK5CYII=")
        up = body(call("POST", f"/denuncias/{COMPLAINT_ID}/adjuntos/upload-url",
                       json={"filename": "e2e-synthetic.png", "mime_type": "image/png", "size_bytes": len(png)}))
        url, key, headers = up.get("upload_url"), up.get("storage_key"), up.get("headers")
        if not url or not key or not isinstance(headers, dict):
            raise AssertionError("Contrato upload-url incompleto: " + str(up)[:600])
        if urlparse(url).scheme != "https": raise AssertionError("La URL de subida no usa HTTPS.")
        put = S.put(url, headers={str(k): str(v) for k, v in headers.items()}, data=png, timeout=60)
        if put.status_code not in (200, 201, 204):
            raise AssertionError(f"PUT de evidencia HTTP {put.status_code}: {put.text[:300]}")
        confirmed = body(call("POST", f"/denuncias/{COMPLAINT_ID}/adjuntos/confirm",
                              json={"storage_key": key}))
        record("Evidencia: URL presignada + PUT + confirmación",
               bool(confirmed.get("id") or confirmed.get("storage_key")), key)
        attachments = body(call("GET", f"/denuncias/{COMPLAINT_ID}/adjuntos"))
        record("Evidencia asociada a la denuncia",
               isinstance(attachments, list) and any(x.get("storage_key") == key for x in attachments))
    except Exception as evidence_error:
        record("Evidencia: URL presignada + PUT + confirmación", False, str(evidence_error))

    status_result = call("PATCH", f"/denuncias/{COMPLAINT_ID}/estado",
                         json={"status": "en_revision", "note": "prueba automatizada"},
                         expected=(401, 403))
    record("Regla: ciudadano no puede cambiar el estado", status_result.status_code in (401, 403),
           f"HTTP {status_result.status_code}")

    bad_route = call("POST", "/denuncias", json={**payload, "title": title + " ruta inválida",
                      "ruta_territorial_code": "E2E_RUTA_INEXISTENTE"}, expected=(422,))
    record("Regla: rechazar ruta territorial inexistente", bad_route.status_code == 422, "HTTP 422")

    if SECOND_EMAIL and SECOND_PASSWORD:
        second = body(call("POST", "/auth/login", token="",
                           json={"email": SECOND_EMAIL, "password": SECOND_PASSWORD}))
        second_token = second.get("access_token")
        if not second_token: raise AssertionError("Segundo usuario sin access_token.")
        foreign = call("GET", "/denuncias/" + COMPLAINT_ID, token=second_token, expected=(403, 404))
        record("Regla: impedir lectura de denuncia ajena", foreign.status_code in (403, 404))
        foreign_up = call("POST", f"/denuncias/{COMPLAINT_ID}/adjuntos", token=second_token,
                          json={"storage_key": f"complaints/{COMPLAINT_ID}/{me.get('id')}/foreign.png",
                                "media_type": "image", "mime_type": "image/png"},
                          expected=(403,))
        record("Regla: impedir adjuntar evidencia a denuncia ajena", foreign_up.status_code == 403)
    else:
        record("Regla: aislamiento entre usuarios", False,
               "Faltan DENUPE_TEST_SECOND_EMAIL y DENUPE_TEST_SECOND_PASSWORD.")

    final = body(call("GET", "/denuncias/" + COMPLAINT_ID))
    record("Integridad final: estado recibido y propietario intacto",
           final.get("status") == "recibida" and final.get("user_id") == me.get("id"),
           f"estado={final.get('status')}; propietario={final.get('user_id')}")

def main():
    try:
        run()
    except Exception as exc:
        RESULTS.append({"test": "Ejecución completa", "result": "FAIL", "detail": str(exc)})
        print(f"::error::{exc}", file=sys.stderr)
        raise
    finally:
        report = {"base_url": BASE, "executed_at": datetime.now(timezone.utc).isoformat(),
                  "synthetic_record": True, "complaint_id": COMPLAINT_ID,
                  "passed": sum(x["result"] == "PASS" for x in RESULTS),
                  "failed": sum(x["result"] == "FAIL" for x in RESULTS), "results": RESULTS}
        Path("e2e-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps(report, ensure_ascii=False, indent=2))
    if any(x["result"] == "FAIL" for x in RESULTS): sys.exit(1)

if __name__ == "__main__": main()
