import os
import re
import zipfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read_version():
    registrator = os.path.join(REPO_ROOT, 'autocajon.rb')
    with open(registrator, encoding='utf-8') as handle:
        content = handle.read()
    match = re.search(r"@extension\.version\s*=\s*'([^']+)'", content)
    if not match:
        raise SystemExit('No se pudo leer @extension.version de autocajon.rb')
    return match.group(1)


def build_rbz():
    version = read_version()
    output_dir = os.path.join(REPO_ROOT, 'instalable')
    os.makedirs(output_dir, exist_ok=True)
    output = os.path.join(output_dir, f'AutoCajon_v{version}.rbz')

    files = [
        ('autocajon.rb', 'autocajon.rb'),
        ('autocajon/main.rb', 'autocajon/main.rb'),
        ('autocajon/geometria.rb', 'autocajon/geometria.rb'),
        ('autocajon/seleccion.rb', 'autocajon/seleccion.rb'),
        ('autocajon/store.rb', 'autocajon/store.rb'),
        ('autocajon/dialog.html', 'autocajon/dialog.html'),
        ('autocajon/dialog.css', 'autocajon/dialog.css'),
        ('autocajon/dialog.js', 'autocajon/dialog.js'),
    ]

    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as zf:
        for local_name, arcname in files:
            local_path = os.path.join(REPO_ROOT, local_name)
            if not os.path.exists(local_path):
                print(f'ERROR: No existe {local_path}')
                return
            zf.write(local_path, arcname)
            print(f'  + {arcname}')

    size_kb = os.path.getsize(output) / 1024
    print(f'\nGenerado: {output} ({size_kb:.1f} KB)')


if __name__ == '__main__':
    build_rbz()
