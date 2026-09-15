"""Rebuild the local macOS launcher using the pinned Godot installation."""
from pathlib import Path
import plistlib
import shutil
import subprocess

project = Path(__file__).resolve().parents[1]
root = project.parent
engine = root / '.tools/godot-4.7.2/Godot.app'
if not engine.is_dir():
    raise SystemExit('Install Godot 4.7.2 universal into .tools/godot-4.7.2 first.')
contents = root / '方境.app/Contents'
(contents / 'MacOS').mkdir(parents=True, exist_ok=True)
(contents / 'Resources').mkdir(exist_ok=True)
info = {
    'CFBundleName': '方境', 'CFBundleDisplayName': '方境 · 探索者手记',
    'CFBundleIdentifier': 'local.explorers.handbook',
    'CFBundleVersion': '0.5.2', 'CFBundleShortVersionString': '0.5.2',
    'CFBundleExecutable': 'Launch', 'CFBundlePackageType': 'APPL',
    'CFBundleIconFile': 'Game.icns', 'NSHighResolutionCapable': True,
}
(contents / 'Info.plist').write_bytes(plistlib.dumps(info))
subprocess.run(['clang', '-O2', '-arch', 'arm64', '-arch', 'x86_64', str(project / 'tools/mac_launcher.c'), '-o', str(contents / 'MacOS/Launch')], check=True)
shutil.copyfile(engine / 'Contents/Resources/Project.icns', contents / 'Resources/Game.icns')
subprocess.run(['codesign', '--force', '--sign', '-', str(contents.parent)], check=True)
for name, option in [('开始探索.command', ''), ('打开游戏工程.command', '--editor ' )]:
    path = root / name
    path.write_text('#!/bin/zsh\nTASK_ROOT="${0:A:h}"\nexec "$TASK_ROOT/.tools/godot-4.7.2/Godot.app/Contents/MacOS/Godot" ' + option + '--path "$TASK_ROOT/explorer"\n')
    path.chmod(0o755)
print('Local launcher ready:', contents.parent)
