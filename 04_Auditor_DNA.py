import os
import glob
import hashlib

def get_dna_hash(set_path):
    """Lee el archivo .set (UTF-16) y genera un hash del contenido para comparar disparidad."""
    if not os.path.exists(set_path):
        return None
    try:
        # MT5 guarda en UTF-16
        with open(set_path, 'r', encoding='utf-16') as f:
            content = f.read()
            # Limpiamos comentarios y espacios para comparar solo la lógica
            lines = [l.strip() for l in content.splitlines() if l.strip() and not l.startswith(';')]
            logic = "\n".join(sorted(lines)) # Ordenamos para que el orden de las líneas no afecte
            return hashlib.md5(logic.encode('utf-8')).hexdigest(), logic
    except Exception as e:
        return f"Error: {str(e)}", ""

def main():
    root = "." 
    portfolio_dir = os.path.join(root, "BUILD", "1_BUILDING", "03_PORTAFOLIO", "Apex_Predator_V2")
    
    if not os.path.isdir(portfolio_dir):
        print(f"No se encontró la carpeta: {portfolio_dir}")
        return

    pass_folders = glob.glob(os.path.join(portfolio_dir, "PASS_ELITE_*"))
    
    print("=" * 60)
    print("🧬 AUDITORÍA DE ADN: Apex_Predator_V2")
    print("=" * 60)
    
    dnas = {}
    
    for folder in sorted(pass_folders):
        pass_name = os.path.basename(folder)
        set_path = os.path.join(folder, "Apex_Predator_V2.set")
        
        h, logic = get_dna_hash(set_path)
        
        if h and "Error" not in h:
            if h in dnas:
                dnas[h]['count'] += 1
                dnas[h]['passes'].append(pass_name)
            else:
                dnas[h] = {
                    'count': 1,
                    'passes': [pass_name],
                    'sample_logic': logic
                }
        else:
            print(f"⚠️ {pass_name}: No se pudo leer el ADN.")

    # Informe final
    print(f"\nSe analizaron {len(pass_folders)} carpetas Élite.")
    print("-" * 60)
    
    unique_count = len(dnas)
    print(f"📊 ADNs ÚNICOS IDENTIFICADOS: {unique_count}")
    print("-" * 60)

    for i, (h, data) in enumerate(dnas.items()):
        status = "✅ ÚNICO" if data['count'] == 1 else "⚠️ DUPLICADO"
        print(f"[{i+1}] Familia Hash: {h[:8]}... | {status}")
        print(f"    Passes: {', '.join(data['passes'])}")
        
        # Mostrar un fragmento del ADN para confirmar visualmente
        first_lines = data['sample_logic'].splitlines()[:5]
        print(f"    Muestra ADN: {', '.join(first_lines)}...")
        print("")

    if unique_count == len(pass_folders):
        print("🏆 RESULTADO: Limpieza Total. Cada Pass Élite tiene su propio ADN único.")
    else:
        print(f"📢 AVISO: Se detectaron {len(pass_folders) - unique_count} duplicados tácticos.")

if __name__ == "__main__":
    main()
