@echo off
rem Greyfang: 5 GECE - video icin otomatik tanitim oynanisi (~2.5 dk, ESC ile cikis)
set "GODOT=C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
if not exist "%GODOT%" set "GODOT=godot"
start "" "%GODOT%" --path "%~dp0." --fullscreen -- --showcase
