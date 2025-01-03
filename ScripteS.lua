local Notification = loadstring(game:HttpGet("https://api.irisapp.ca/Scripts/IrisBetterNotifications.lua"))()

local games = {
    [9292879820] = "https://raw.githubusercontent.com/Bolox102911/ScripteS/refs/heads/main/scripts/GrassCutting.lua",
    [5938036553] = "https://raw.githubusercontent.com/Bolox102911/ScripteS/refs/heads/main/scripts/Frontlines.lua",
    [15277359883] = "https://raw.githubusercontent.com/Bolox102911/ScripteS/refs/heads/main/scripts/GrassCuttingSim/Script.lua"
}

for ids, url in next, games do
    if table.find(ids, game.PlaceId) then
        Notification.Notify("ScripteS", "Loading ...","rbxassetid://4483345998");
        loadstring(game:HttpGet(url))()
        break
    end
end
