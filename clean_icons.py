import os
import re

dungeons = [
    "Ahnkahet.lua",
    "DrakTharonKeep.lua",
    "HallsOfLightning.lua",
    "HellfireRamparts.lua",
    "ManaTombs.lua",
    "TheBloodFurnace.lua",
    "TheSlavePens.lua",
    "UtgardeKeep.lua"
]

for d in dungeons:
    if not os.path.exists(d): continue
    with open(d, "r", encoding="utf-8") as f:
        content = f.read()
    
    # We want to remove the specific iconId line added by the user:
    # ["iconId"] = "",
    pattern = re.compile(r'^\s*\["iconId"\]\s*=\s*"",\s*?\n', re.MULTILINE)
    new_content = pattern.sub('', content)
    
    if new_content != content:
        with open(d, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"Removed manual iconId from {d}")
    else:
        print(f"No changes for {d}")
