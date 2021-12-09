#!/bin/bash
echo "test"
if kpackagetool5 -t Plasma/Applet --upgrade zerotier.plasmoid | grep -q 'Error: Plugin org.github.duoslow.zerotierIndicator is not installed.'; then
    kpackagetool5 -t Plasma/Applet --install zerotier.plasmoid   
    echo "installed"
fi