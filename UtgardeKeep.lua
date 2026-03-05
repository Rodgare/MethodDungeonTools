local dungeonIndex = 1
local nerfMultiplier = 1
local pi = math.pi

MethodDungeonTools.dungeonTotalCount[dungeonIndex] = {normal = 100, teeming = 100, teemingEnabled = false}

MethodDungeonTools.dungeonBosses[dungeonIndex] = {
    [1] = {
        [1] = {
            ["name"] = "Принц Келесет",
            -- ["encounterID"] = 1502,
            ["id"] = 23953,
            ["displayId"] = 23953,
            ["health"] = 90276936,
            ["x"] = 400, -- Map coordinates (0-840)
            ["y"] = -200, -- Map coordinates (0-555)
        },
    }
}

-- 3. Enemy Data
MethodDungeonTools.dungeonEnemies[dungeonIndex] = {
    [1] = { -- First enemy type
        ["name"] = "Порабощенный протодракон",
        ["health"] = 130330,
        ["level"] = 80,
        ["creatureType"] = "Дракон",
        ["id"] = 24849,
        ["displayId"] = 24083,
        ["count"] = 3.61, -- Enemy count for the progress bar
        ["scale"] = 2,
        ["color"] = {r=1,g=1,b=1,a=0.8},
        ["clones"] = {
            -- subLevel matches the floor index, g is the pull group
            [1] = {x = 500, y = -300, sublevel = 1, g = 1}, 
            [2] = {x = 510, y = -310, sublevel = 1, g = 1},
        },
    },
}
