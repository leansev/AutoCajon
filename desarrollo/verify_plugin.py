import os
import sys
import zipfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

REQUIRED = [
    'autocajon.rb',
    'autocajon/main.rb',
    'autocajon/seleccion.rb',
    'autocajon/store.rb',
    'autocajon/dialog.js',
    'autocajon/dialog.html',
    'autocajon/icons/autocajon_24.png',
    'autocajon/icons/autocajon_32.png',
]

PATTERNS = {
    'autocajon/main.rb': [
        'STYLE_WINDOW',
        'start_face_pick',
        'finish_face_pick',
        'cancel_face_pick',
    ],
    'autocajon/seleccion.rb': [
        'pick_face',
        'PICK_APERTURE',
        'face_dimensions_mm',
    ],
    'autocajon/store.rb': [
        'def run_script',
        'payload.inspect',
    ],
    'autocajon/dialog.js': [
        'btnPickBase',
        'escJsStr',
        'applyBaseData',
        'resetFormFull',
        'console.error("[AutoCajon] callback no disponible:',
    ],
    'autocajon/dialog.html': [
        'id="btnPickBase"',
    ],
}


def read(path):
    with open(path, encoding='utf-8') as handle:
        return handle.read()


def check_repo():
    errors = []
    for rel in REQUIRED:
        path = os.path.join(REPO_ROOT, rel)
        if not os.path.exists(path):
            errors.append(f'Falta archivo: {rel}')

    for rel, needles in PATTERNS.items():
        path = os.path.join(REPO_ROOT, rel)
        if not os.path.exists(path):
            continue
        content = read(path)
        for needle in needles:
            if needle not in content:
                errors.append(f'{rel}: falta "{needle}"')

    return errors


def check_rbz():
    rbz_path = os.path.join(REPO_ROOT, 'instalable', 'AutoCajon_v1.0.0.rbz')
    if not os.path.exists(rbz_path):
        return [f'Falta instalable: {rbz_path}']

    errors = []
    with zipfile.ZipFile(rbz_path) as zf:
        names = set(zf.namelist())
        for rel in REQUIRED:
            if rel not in names:
                errors.append(f'RBZ sin entrada: {rel}')
        if 'autocajon.rb' not in names:
            errors.append('RBZ sin autocajon.rb en raiz')
    return errors


def main():
    errors = check_repo() + check_rbz()
    if errors:
        print('VERIFY FAIL')
        for item in errors:
            print(' -', item)
        sys.exit(1)
    print('VERIFY OK')


if __name__ == '__main__':
    main()
