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
        'STYLE_DIALOG',
        'ensure_dialog',
        'start_face_pick',
        'finish_face_pick',
        'cancel_face_pick',
        '@pending_base_dims',
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


RUBY22_FORBIDDEN = [
    ('&.', 'safe navigation operator (Ruby 2.3+)'),
    ('<<~', 'squiggly heredoc (Ruby 2.3+)'),
]


def check_ruby22_compat():
    errors = []
    rb_files = [
        'autocajon/main.rb',
        'autocajon/seleccion.rb',
        'autocajon/store.rb',
    ]
    for rel in rb_files:
        path = os.path.join(REPO_ROOT, rel)
        if not os.path.exists(path):
            continue
        content = read(path)
        for token, desc in RUBY22_FORBIDDEN:
            if token in content:
                errors.append(f'{rel}: sintaxis incompatible Ruby 2.2: {desc} ({token!r})')
    return errors


def check_ruby_syntax():
    import subprocess
    rb_files = [
        'autocajon/main.rb',
        'autocajon/seleccion.rb',
        'autocajon/store.rb',
    ]
    errors = []
    ruby_cmds = ['ruby']
    for candidate in (
        r'C:\Ruby22\bin\ruby.exe',
        r'C:\Ruby22-x64\bin\ruby.exe',
    ):
        if os.path.isfile(candidate):
            ruby_cmds.insert(0, candidate)
    ruby = None
    for cmd in ruby_cmds:
        try:
            subprocess.run([cmd, '-v'], capture_output=True, check=True, timeout=5)
            ruby = cmd
            break
        except (FileNotFoundError, subprocess.CalledProcessError, OSError):
            continue
    if not ruby:
        return ['ruby -c: ruby no encontrado en PATH (omitido)']
    lines = []
    for rel in rb_files:
        path = os.path.join(REPO_ROOT, rel)
        result = subprocess.run([ruby, '-c', path], capture_output=True, text=True, timeout=10)
        out = (result.stdout + result.stderr).strip()
        lines.append(f'{rel}: {out or "Syntax OK"}')
        if result.returncode != 0:
            errors.append(f'{rel}: {out}')
    return errors if errors else lines


def main():
    errors = check_repo() + check_rbz() + check_ruby22_compat()
    syntax = check_ruby_syntax()
    if errors:
        print('VERIFY FAIL')
        for item in errors:
            print(' -', item)
        sys.exit(1)
    print('VERIFY OK')
    for line in syntax:
        print(line)


if __name__ == '__main__':
    main()
