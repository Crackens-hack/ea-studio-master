"""
3_Clear.py - Limpia carpetas de RESULTADOS con confirmaciones.

Opciones al ejecutar:
  1) Borrar Reportes-Analizados
  2) Borrar Reportes-Normalizados
  3) Borrar Reportes-SinProcesar (pregunta dos veces porque es la data cruda de la instancia)
  4) Borrar TODO lo anterior (incluye confirmación especial para datos crudos)

Notas:
- Los datos crudos viven en la carpeta real de reportes de la instancia activa.
  La ruta se lee de 00_setup/Instancias/credencial_en_uso.json (rutas.reports).
- El symlink Reportes-SinProcesar siempre se elimina si se elige la opción 3 o 4
  (salvo que se cancele la confirmación especial, en cuyo caso se mantiene).
"""

from __future__ import annotations

import json
import shutil
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
RESULTADOS_ROOT = REPO_ROOT / "RESULTADOS"
ANALIZADOS = RESULTADOS_ROOT / "Reportes-Analizados"
NORMALIZADOS = RESULTADOS_ROOT / "Reportes-Normalizados"
SIN_PROCESAR = RESULTADOS_ROOT / "Reportes-SinProcesar"
CRED_PATH = REPO_ROOT / "00_setup" / "Instancias" / "credencial_en_uso.json"


def _ask(msg: str) -> bool:
    resp = input(f"{msg} (s/n): ").strip().lower()
    return resp.startswith("s")


def _delete_path(path: Path) -> None:
    if not path.exists():
        print(f"[INFO] No existe: {path} (posible borrado previo o aún no creado)")
        return
    try:
        if path.is_symlink() or path.is_file():
            path.unlink()
        elif path.is_dir():
            shutil.rmtree(path)
        else:  # fallback
            path.unlink()
        print(f"[OK] Eliminado: {path}")
    except Exception as e:
        # Si rmtree falla por symlink tratado como dir (caso Windows junction)
        if "symlink" in str(e).lower():
            try:
                path.unlink()
                print(f"[OK] Eliminado (unlink): {path}")
                return
            except Exception as e2:
                print(f"[ERROR] No pude eliminar {path}: {e2}")
        else:
            print(f"[ERROR] No pude eliminar {path}: {e}")


def _empty_dir(dir_path: Path) -> None:
    if not dir_path.exists():
        print(f"[INFO] No existe: {dir_path} (posible borrado previo o aún no creado)")
        return
    if not dir_path.is_dir():
        print(f"[WARN] No es carpeta: {dir_path}")
        return
    for child in dir_path.iterdir():
        try:
            if child.is_dir() and not child.is_symlink():
                shutil.rmtree(child)
            else:
                child.unlink()
        except Exception as e:
            print(f"[ERROR] No pude borrar {child}: {e}")
    print(f"[OK] Carpeta vaciada: {dir_path}")


def _reports_real_path() -> Path | None:
    if not CRED_PATH.exists():
        print("[WARN] No se encontró credencial_en_uso.json; no se puede ubicar reports crudo.")
        return None
    try:
        data = json.loads(CRED_PATH.read_text(encoding="utf-8"))
        rp = data.get("rutas", {}).get("reports")
        return Path(rp) if rp else None
    except Exception as e:
        print(f"[WARN] No pude leer credencial_en_uso.json: {e}")
        return None


def main() -> None:
    while True:
        print("=== Limpieza de RESULTADOS ===")
        print("1) Borrar Reportes-Analizados")
        print("2) Borrar Reportes-Normalizados")
        print("3) Borrar Reportes-SinProcesar (crudos de la instancia)")
        print("4) Borrar TODO")
        choice = input("Elegí opción (1-4, Q para salir): ").strip().lower()
        if choice in {"q", ""}:
            print("Sin cambios.")
            return
        if choice not in {"1", "2", "3", "4"}:
            print("Opción inválida. Intenta de nuevo.\n")
            continue

        borrar_analizados = choice in {"1", "4"}
        borrar_normalizados = choice in {"2", "4"}
        borrar_crudos = choice in {"3", "4"}

        if borrar_analizados:
            _delete_path(ANALIZADOS)
        if borrar_normalizados:
            _delete_path(NORMALIZADOS)

        if borrar_crudos:
            rp = _reports_real_path()
            if not rp:
                print("[WARN] No se puede borrar crudos: ruta de reports desconocida.")
                proceed_crudos = False
            else:
                msg = (
                    "\n--- Confirmación de borrado de crudos ---\n"
                    f"Ruta real : {rp}\n"
                    "Contenido : reportes sin procesar de la instancia activa\n"
                    "Acción    : vaciará todos los archivos/carpetas dentro de esa ruta\n"
                    "------------------------------------------\n"
                    "¿Proceder con el borrado?"
                )
                proceed_crudos = _ask(msg)
                if proceed_crudos:
                    _empty_dir(rp)
                else:
                    print("[CANCEL] Datos crudos preservados.")
            # Mantenemos el enlace Reportes-SinProcesar (lo recrea el instalador si falta); no se borra aquí.
            if proceed_crudos:
                print("[INFO] Enlace Reportes-SinProcesar conservado.")

        print("Listo.\n")


if __name__ == "__main__":
    main()
