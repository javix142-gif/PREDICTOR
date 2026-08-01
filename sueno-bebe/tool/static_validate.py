#!/usr/bin/env python3
"""Validaciones estructurales sin sustituir flutter analyze ni flutter test."""

from __future__ import annotations

import re
import sqlite3
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = ROOT.parent
WORKFLOW_PATH = REPOSITORY_ROOT / '.github/workflows/sueno-bebe-redesign.yml'
WORKFLOW_LABEL = '../.github/workflows/sueno-bebe-redesign.yml'
REQUIRED_FILES = {
    'pubspec.yaml',
    'analysis_options.yaml',
    'README.md',
    'AGENTS.md',
    'PROJECT_STATE.md',
    'lib/main.dart',
    'lib/app.dart',
    'lib/data/app_database.dart',
    'lib/services/statistics_service.dart',
    'lib/services/prediction_service.dart',
    'lib/services/notification_service.dart',
    'test/statistics_service_test.dart',
    'test/prediction_service_test.dart',
    'test/sleep_event_validation_test.dart',
    'android/app/src/main/AndroidManifest.xml',
}


def fail(message: str, errors: list[str]) -> None:
    errors.append(message)


def validate_required_files(errors: list[str]) -> None:
    for relative in sorted(REQUIRED_FILES):
        path = ROOT / relative
        if not path.is_file():
            fail(f'Falta archivo requerido: {relative}', errors)
    if not WORKFLOW_PATH.is_file():
        fail(f'Falta workflow ejecutable en la raíz: {WORKFLOW_LABEL}', errors)


def validate_yaml_xml(errors: list[str]) -> None:
    yaml_files = (
        (ROOT / 'pubspec.yaml', 'pubspec.yaml'),
        (ROOT / 'analysis_options.yaml', 'analysis_options.yaml'),
        (WORKFLOW_PATH, WORKFLOW_LABEL),
    )
    for path, label in yaml_files:
        try:
            yaml.safe_load(path.read_text(encoding='utf-8'))
        except Exception as error:  # noqa: BLE001
            fail(f'YAML inválido en {label}: {error}', errors)
    for path in ROOT.glob('android/app/src/**/*.xml'):
        try:
            ET.parse(path)
        except Exception as error:  # noqa: BLE001
            fail(f'XML inválido en {path.relative_to(ROOT)}: {error}', errors)


def validate_relative_imports(errors: list[str]) -> None:
    for path in [*ROOT.glob('lib/**/*.dart'), *ROOT.glob('test/**/*.dart')]:
        text = path.read_text(encoding='utf-8')
        for match in re.finditer(r"import\s+['\"]([^'\"]+)['\"]", text):
            imported = match.group(1)
            if imported.startswith('.') and not (path.parent / imported).resolve().is_file():
                fail(
                    f'Import relativo inexistente en {path.relative_to(ROOT)}: {imported}',
                    errors,
                )


def validate_balanced_delimiters(errors: list[str]) -> None:
    pairs = {')': '(', ']': '[', '}': '{'}
    for path in [*ROOT.glob('lib/**/*.dart'), *ROOT.glob('test/**/*.dart')]:
        text = path.read_text(encoding='utf-8')
        stack: list[tuple[str, int]] = []
        state = 'code'
        quote = ''
        triple = False
        line = 1
        index = 0
        while index < len(text):
            current = text[index]
            following = text[index + 1] if index + 1 < len(text) else ''
            if current == '\n':
                line += 1
            if state == 'code':
                if current == '/' and following == '/':
                    state = 'line_comment'
                    index += 2
                    continue
                if current == '/' and following == '*':
                    state = 'block_comment'
                    index += 2
                    continue
                if current in "'\"":
                    quote = current
                    triple = text[index:index + 3] == current * 3
                    state = 'string'
                    index += 3 if triple else 1
                    continue
                if current in '([{':
                    stack.append((current, line))
                elif current in ')]}':
                    if not stack or stack[-1][0] != pairs[current]:
                        fail(
                            f'Delimitador inesperado {current} en '
                            f'{path.relative_to(ROOT)}:{line}',
                            errors,
                        )
                        break
                    stack.pop()
                index += 1
                continue
            if state == 'line_comment':
                if current == '\n':
                    state = 'code'
                index += 1
                continue
            if state == 'block_comment':
                if current == '*' and following == '/':
                    state = 'code'
                    index += 2
                else:
                    index += 1
                continue
            if current == '\\':
                index += 2
            elif triple and text[index:index + 3] == quote * 3:
                state = 'code'
                index += 3
            elif not triple and current == quote:
                state = 'code'
                index += 1
            else:
                index += 1
        if stack:
            fail(
                f'Delimitador sin cerrar en {path.relative_to(ROOT)}: {stack[-1]}',
                errors,
            )


def dart_string_literals(expression: str) -> str:
    values: list[str] = []
    index = 0
    while index < len(expression):
        if expression[index] not in "'\"":
            index += 1
            continue
        quote = expression[index]
        triple = expression[index:index + 3] == quote * 3
        index += 3 if triple else 1
        output: list[str] = []
        while index < len(expression):
            if triple and expression[index:index + 3] == quote * 3:
                index += 3
                break
            if not triple and expression[index] == quote:
                index += 1
                break
            if expression[index] == '\\' and index + 1 < len(expression):
                following = expression[index + 1]
                output.append({'n': '\n', 'r': '\r', 't': '\t'}.get(following, following))
                index += 2
            else:
                output.append(expression[index])
                index += 1
        values.append(''.join(output))
    return ''.join(values)


def database_execute_blocks() -> list[str]:
    source = (ROOT / 'lib/data/app_database.dart').read_text(encoding='utf-8')
    needle = 'await db.execute('
    position = 0
    result: list[str] = []
    while True:
        start = source.find(needle, position)
        if start < 0:
            break
        cursor = start + len(needle)
        expression_start = cursor
        depth = 1
        quote: str | None = None
        triple = False
        escaped = False
        while cursor < len(source) and depth:
            current = source[cursor]
            if quote is not None:
                if escaped:
                    escaped = False
                elif current == '\\':
                    escaped = True
                elif triple and source[cursor:cursor + 3] == quote * 3:
                    quote = None
                    cursor += 2
                elif not triple and current == quote:
                    quote = None
            else:
                if current in "'\"":
                    quote = current
                    triple = source[cursor:cursor + 3] == current * 3
                    if triple:
                        cursor += 2
                elif current == '(':
                    depth += 1
                elif current == ')':
                    depth -= 1
            cursor += 1
        result.append(dart_string_literals(source[expression_start:cursor - 1]).strip())
        position = cursor
    return result


def validate_database(errors: list[str]) -> None:
    try:
        database = sqlite3.connect(':memory:')
        database.execute('PRAGMA foreign_keys = ON')
        statements = database_execute_blocks()
        for statement in statements:
            database.execute(statement)
        database.execute(
            "INSERT INTO baby_profiles VALUES "
            "('baby','Bebé','2026-01-01',NULL,NULL,'UTC',1,1)",
        )
        database.execute(
            "INSERT INTO sleep_events VALUES "
            "('open-1','baby',10,NULL,'siesta','abierto','exacta','manual',"
            "NULL,'UTC',1,1)",
        )
        try:
            database.execute(
                "INSERT INTO sleep_events VALUES "
                "('open-2','baby',20,NULL,'siesta','abierto','exacta','manual',"
                "NULL,'UTC',1,1)",
            )
            fail('El índice de un único evento abierto no rechazó el segundo evento.', errors)
        except sqlite3.IntegrityError:
            pass
        database.execute("DELETE FROM baby_profiles WHERE id = 'baby'")
        remaining = database.execute('SELECT COUNT(*) FROM sleep_events').fetchone()[0]
        if remaining != 0:
            fail('La eliminación en cascada del perfil no funcionó.', errors)
        expected_indexes = {
            'idx_sleep_events_baby_start',
            'idx_one_open_sleep_per_baby',
            'idx_predictions_baby_generated',
            'idx_predictions_evaluation',
        }
        indexes = {
            row[0]
            for row in database.execute(
                "SELECT name FROM sqlite_master "
                "WHERE type = 'index' AND name NOT LIKE 'sqlite_%'",
            )
        }
        if indexes != expected_indexes:
            fail(f'Índices SQLite inesperados: {sorted(indexes)}', errors)
    except Exception as error:  # noqa: BLE001
        fail(f'El esquema SQLite no pudo ejecutarse: {error}', errors)


def validate_android_manifest(errors: list[str]) -> None:
    path = ROOT / 'android/app/src/main/AndroidManifest.xml'
    tree = ET.parse(path)
    namespace = '{http://schemas.android.com/apk/res/android}'
    permissions = {
        element.attrib[f'{namespace}name']
        for element in tree.getroot().findall('uses-permission')
    }
    expected = {
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.RECEIVE_BOOT_COMPLETED',
    }
    if permissions != expected:
        fail(f'Permisos Android inesperados: {sorted(permissions)}', errors)
    text = path.read_text(encoding='utf-8')
    forbidden = (
        'ACCESS_FINE_LOCATION',
        'ACCESS_COARSE_LOCATION',
        'SCHEDULE_EXACT_ALARM',
        'USE_EXACT_ALARM',
        'READ_CONTACTS',
    )
    for token in forbidden:
        if token in text:
            fail(f'Permiso prohibido en AndroidManifest: {token}', errors)


def validate_no_placeholders_or_secrets(errors: list[str]) -> None:
    marker_pattern = re.compile(
        r'\b(TODO|FIXME|HACK|XXX|UnimplementedError|NotImplementedError)\b',
    )
    secret_pattern = re.compile(
        r'(-----BEGIN (?:RSA|EC|OPENSSH) PRIVATE KEY-----|sk-[A-Za-z0-9_-]{20,}|'
        r'(?i:api[_-]?key|password|passwd)\s*[:=]\s*["\'][^"\']+["\'])',
    )
    for path in [*ROOT.glob('lib/**/*.dart'), *ROOT.glob('test/**/*.dart')]:
        text = path.read_text(encoding='utf-8')
        if marker_pattern.search(text):
            fail(f'Marcador pendiente en {path.relative_to(ROOT)}', errors)
        if secret_pattern.search(text):
            fail(f'Posible secreto en {path.relative_to(ROOT)}', errors)
        if not text.strip():
            fail(f'Archivo Dart vacío: {path.relative_to(ROOT)}', errors)


def main() -> int:
    errors: list[str] = []
    validate_required_files(errors)
    validate_yaml_xml(errors)
    validate_relative_imports(errors)
    validate_balanced_delimiters(errors)
    validate_database(errors)
    validate_android_manifest(errors)
    validate_no_placeholders_or_secrets(errors)
    if errors:
        print('VALIDACIÓN ESTÁTICA: FALLIDA')
        for error in errors:
            print(f'- {error}')
        return 1
    print('VALIDACIÓN ESTÁTICA: APROBADA')
    print('- Archivos requeridos: OK')
    print('- Workflow ejecutable en la raíz: OK')
    print('- YAML/XML: OK')
    print('- Imports relativos y delimitadores Dart: OK')
    print('- Esquema, índices y restricciones SQLite: OK')
    print('- Permisos Android: OK')
    print('- Marcadores pendientes y secretos en código: no detectados')
    return 0


if __name__ == '__main__':
    sys.exit(main())
