# Zerotier KDE Widget  
## This Widget Shows Zerotier Network Members
#### I had to stop using Linux due to school and work. yes dual boot etc. I could continue to use Linux, but I don't have time to deal with it and using Linux is time-consuming and I don't have the time to spare for it right now. That's why I can't continue developing it, I want to write it from scratch in the future. because this code is really shitty. The more I look at the code, the more I want to delete it, so I can't continue developing it right now. 
#### 28/02/2024
## Features (V1.1)
- Show online member count on icon
- Click to copy zerotier ip 
- Updates members status on intervals  
- Multiple network selection window
- Only show online members option

## TODO (V2.0)
- [ ] Sorting system [WIP]
- [x] Select all networks 
- [x] Context menu on icon 
- [ ] Content auto windows height 
- [ ] Change emojis to png (emoji system on kde is suck)
- [ ] Network selector theme fix 
- [ ] Update interval 30s,1min+++ 
- [ ] Sometimes after reboot have duplicate list (idk why but it gets fixed when updates the list) (BUG) 

## TODO (v3.0)
- [ ] Managing (create-update network, member operations,etc,all available API features) 
- [ ] Network specific icon color 
- [ ] Notification (online-offline,copy)

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
