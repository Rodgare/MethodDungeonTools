local dungeonIndex = 1
local nerfMultiplier = 1
local pi = math.pi

MethodDungeonTools.dungeonTotalCount[dungeonIndex] = {normal = 100, teeming = 100, teemingEnabled = false}

MethodDungeonTools.dungeonBosses[dungeonIndex] = {
    [1] = {
        [1] = {
            ["name"] = "Принц Келесет",
            ["encounterID"] = 1502,
            ["id"] = 23953,
            ["displayId"] = 96756,
            ["health"] = 90276936,
            ["x"] = 400, -- Map coordinates (0-840)
            ["y"] = 300, -- Map coordinates (0-555)
        },
    }
}

-- 3. Enemy Data
MethodDungeonTools.dungeonEnemies[dungeonIndex] = {
    [1] = { -- First enemy type
        ["name"] = "Anub'ar Warrior",
        ["health"] = 150000,
        ["level"] = 80,
        ["creatureType"] = "Humanoid",
        ["id"] = 29023,
        ["displayId"] = 25801,
        ["count"] = 4, -- Enemy count for the progress bar
        ["scale"] = 1,
        ["color"] = {r=1,g=1,b=1,a=0.8},
        ["clones"] = {
            -- subLevel matches the floor index, g is the pull group
            [1] = {x = 500, y = 300, sublevel = 1, g = 1}, 
            [2] = {x = 510, y = 310, sublevel = 1, g = 1},
        },
    },
}
