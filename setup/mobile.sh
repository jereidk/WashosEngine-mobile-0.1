#!/bin/bash
cd ..
echo Making the main haxelib and setuping folder in same time..
mkdir -p ~/haxelib && haxelib setup ~/haxelib 2>/dev/null || true
echo Installing dependencies...
echo This might take a few moments depending on your internet speed.

# Skip lime if already installed to avoid interactive prompts
if haxelib list 2>/dev/null | grep -q "^lime "; then
    echo "Lime already installed, skipping"
else
    echo "Installing lime..."
    haxelib install lime 8.2.0 --quiet 2>/dev/null || haxelib install lime --quiet 2>/dev/null || true
fi

# Install other dependencies only if not already installed
haxelib install hxcpp --quiet 2>/dev/null || haxelib git hxcpp https://github.com/mcagabe19-stuff/hxcpp --quiet 2>/dev/null || true
haxelib install openfl 9.3.3 --quiet 2>/dev/null || true
haxelib install flixel 5.6.0 --quiet 2>/dev/null || haxelib git flixel https://github.com/MobilePorting/flixel 5.6.1 --quiet 2>/dev/null || true
haxelib install flixel-addons 3.2.2 --quiet 2>/dev/null || true
haxelib install hscript-iris 1.1.3 --quiet 2>/dev/null || true
haxelib install tjson 1.4.0 --quiet 2>/dev/null || true
haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate --quiet 2>/dev/null || true
haxelib install linc_luajit --quiet 2>/dev/null || haxelib git linc_luajit https://github.com/MobilePorting/linc_luajit-0.7plus --quiet 2>/dev/null || true
haxelib install hxdiscord_rpc 1.2.4 --quiet --skip-dependencies 2>/dev/null || true
haxelib install hxvlc 2.0.1 --quiet --skip-dependencies 2>/dev/null || true
haxelib git funkin.vis https://github.com/FunkinCrew/funkVis --quiet --skip-dependencies 2>/dev/null || true
haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio.git --quiet 2>/dev/null || true

echo Setup complete!
haxelib git extension-androidtools https://github.com/MAJigsaw77/extension-androidtools --quiet --skip-dependencies 2>/dev/null || true
echo Finished!
