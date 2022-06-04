# HitSounds
SourceMod plugin for playing hitsounds. **Made and tested for CS:GO only!** I have not tested other games so no comment on compatability.

# Normal vs Lite?
Normal version has 3 different sounds for zombies and then one for bosses. Unfortunately, this is still a WIP where I intend on adding option to change hitsounds to your liking, but for now, you'll have to use `_Lite` version if you only want one sound *(make sure to modify the source code to the sound you wish relative to sourcemod folder!)*

*Note: Compiled in `SM 1.11.6882`*

# Features:
- Separate hitsounds for hitting body shots, head shots, and kills
- `sm_hsvol` feature to control volume of hitsounds

# Installation:
1. Download this repository as a `.zip` file by pressing the `Code` button in the top right
2. Drag and drop all the files into your CS:GO files
3. **Make sure to add the files to your server's FastDL**
4. Make sure to change map so sounds are properly cached

# Credits:
- [Original plugin by nano/maxim1907](https://gitlab.com/counterstrikesource/sm-plugins/hitmarker)
- [tilgep](https://steamcommunity.com/id/tilgep/) for adding `sm_hsvol` feature

# Changelogs
## Version 1
- Port from CSS and removed all hitmarkers related files and code
- Added `sm_hsvol` and volume control to plugin
## Version 2
- **2.0**
    - Added multiple sound files for different hitgroups and kills
    - Moved plugin messages to a translation file
- **2.0 Lite**
    - Revert back to old plugin with just 1 hitsound *(CoD Hitmarker)*
- **2.1**
    - Added client option to toggle between detailed and simple hitsound modes