# Zerotier KDE Widget  
## This Widget Shows Zerotier Network Members
### I can't continue developing because I don't have time
## Features (V1.1)
- Show online member count on icon
- Click to copy zerotier ip 
- Updates members status on intervals  
- Multiple network selection window
- Only show online members option

## TODO (V1.2)
- [ ] Sorting system (Feature) [WIP]
- [x] Select all networks (Feature) 
- [x] Context menu on icon (Feature) 
- [ ] Content auto windows height (Feature)
- [ ] Change emojis to png (Improvement)
- [ ] Network selector theme fix (Improvement)
- [ ] Update interval 30s,1min+++ (improvement)
- [ ] Sometimes after reboot have duplicate list (idk why but it gets fixed when updates the list) (BUG) 

## TODO (v1.3)
- [ ] Managing (create-update network, member operations,etc,all available API features) (Feature)
- [ ] Network specific icon color (Feature)
- [ ] Notification (online-offline,copy)(Feature)

## Installation
There are three ways to install this widget in your KDE Plasma.

1. Head over to the Plasma Add-On installer by going to: `Right click on Desktop,Dock or Panel -> Add Widgets -> Get New Widgets -> Search "Zerotier KDE Widget" and Install`.
2. Download the `zerotier.plasmoid` file shared in this repo's [release section](https://github.com/Duoslow/zerotierIndicator/releases/latest) or from the widget's KDE Store [link](https://store.kde.org/p/1666827). After this, you can just do this: `Right Click on Desktop -> Add Widgets -> Install from local file -> Point to the downloaded zerotier.plasmoid file`.
3. Download the `zerotier.plasmoid` file shared in this repo's [release section](https://github.com/Duoslow/zerotierIndicator/releases/latest) and run this `
kpackagetool5 -t Plasma/Applet --install zerotier.plasmoid `

## Widget GUI and Indicator
![ex](https://i.imgur.com/MYQDika.png)![a](https://i.imgur.com/y92VmYu.png)

## Settings
![settings](https://i.imgur.com/Owxf7E2.png)
