local BASE_URL = "https://raw.githubusercontent.com/Jxl-v/schematica/main/"

local function require_module(module) return loadstring(game:HttpGet(string.format("%sdependencies/%s", BASE_URL, module)))() end
--local function require_module(module) return loadstring(readfile(string.format("schematica-script-workspace/dependencies/%s", module)))() end

local Serializer = require_module("serializer.lua")
local Builder = require_module("builder.lua")
local Printer = require_module("printer.lua")
local Library = require_module("venyx.lua")

if game.CoreGui:FindFirstChild("Schematica") then game.CoreGui.Schematica:Destroy() end
if not isfolder("builds") then makefolder("builds") end

local Fetch = request or http_request or syn and syn.request
local Http = game:GetService("HttpService")
local Env = Http:JSONDecode(game:HttpGet(BASE_URL .. "env.json"))

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()

local Schematica = Library.new("Schematica")

local GlobalToggles = {}

local function Toggle(Name)
    for i, v in next, GlobalToggles do
        if i ~= Name then   
            v.toggle(false)
        end
    end
end

do
    local Build = Schematica:addPage("Build")
    local round = math.round

    local Flags = {
        ChangingPosition = false,
        BuildId = '0',
        ShowPreview = true,
        Visibility = 0.5,
        DragCF = 0
    }

    local Indicator = Instance.new("Part")
    Indicator.Size = Vector3.new(3.1, 3.1, 3.1)
    Indicator.Transparency = 0.5
    Indicator.Anchored = true
    Indicator.CanCollide = false
    Indicator.BrickColor = BrickColor.new("Bright green")
    Indicator.TopSurface = Enum.SurfaceType.Smooth
    Indicator.Parent = workspace

    local Handles = Instance.new("Handles")
    Handles.Style = Enum.HandlesStyle.Movement
    Handles.Adornee = Indicator
    Handles.Visible = false
    Handles.Parent = game.CoreGui

    Handles.MouseButton1Down:Connect(function()
        Flags.DragCF = Handles.Adornee.CFrame
    end)

    Handles.MouseDrag:Connect(function(Face, Distance)
        if Indicator.Parent.ClassName == "Model" then
            Indicator.Parent:SetPrimaryPartCFrame(Flags.DragCF + Vector3.FromNormalId(Face) * (round(Distance / 3) * 3))
        else
            Indicator.CFrame = Flags.DragCF + Vector3.FromNormalId(Face) * (round(Distance / 3) * 3)
        end
    end)

    local SelectSection = Build:addSection("Selecting Build")

    SelectSection:addTextbox("Build ID", "0", function(buildId)
        Flags.BuildId = buildId:gsub("%s", "")
    end)

    Flags.Download = SelectSection:addButton("Download / Load", function()
        SelectSection:updateButton(Flags.Download, "Please wait ...")

        if isfile("builds/" .. Flags.BuildId .. ".s") then
            if Flags.Build then 
                Indicator.Parent = workspace
                Flags.Build:Destroy()
            end
            local Data = Http:JSONDecode(readfile("builds/" .. Flags.BuildId .. ".s"))
            Flags.Build = Builder.new(Data)
            SelectSection:updateButton(Flags.Download, "File loaded!")
        else
            local Response = Http:JSONDecode(game:HttpGet(Env.get .. Flags.BuildId))
            if Response.success == true then
                if Flags.Build then 
                    Indicator.Parent = workspace
                    Flags.Build:Destroy()
                end
                Flags.Build = Builder.new(Response.data)
                SelectSection:updateButton(Flags.Download, "Downloaded!")
                writefile("builds/" .. Flags.BuildId .. ".s", game.HttpService:JSONEncode(Response.data))
            else
                if Response.status == 404 then
                    SelectSection:updateButton(Flags.Download, "Not found")
                elseif Response.status == 400 then
                    SelectSection:updateButton(Flags.Download, "Error")
                end
            end
        end
        wait(1)
        SelectSection:updateButton(Flags.Download, "Download")
    end)

    local PositionSettings = Build:addSection("Position Settings")

    GlobalToggles.ChangePositionToggle = PositionSettings:addToggle("Change Position", false, function(willChange)
        Flags.ChangingPosition = willChange
    end)

    Mouse.Button1Down:Connect(function()
        if Mouse.Target then
            if Flags.ChangingPosition then
                if Mouse.Target.Parent.Name == "Blocks" or Mouse.Target.Parent.Parent.Name == "Blocks" then
                    local Part = Mouse.Target.Parent.Name == "Blocks" and Mouse.Target or Mouse.Target.Parent.Parent.Name == "Blocks" and Mouse.Target.Parent
                    Handles.Visible = Flags.ShowPreview
                    if Indicator.Parent and Indicator.Parent.ClassName == "Model" then
                        Indicator.Parent:SetPrimaryPartCFrame(CFrame.new(Part.Position))
                    else
                        Indicator.CFrame = CFrame.new(Part.Position)
                    end
                end
            end
        end
    end)

    print("click connection loaded")

    PositionSettings:addButton("Load Model", function()
        if Indicator and Flags.Build then
            if Flags.Build.Model then
                Indicator.Parent = workspace
                Flags.Build.Model:Destroy()
            end

            Flags.ChangingPosition = false
            --PositionSettings:updateToggle(GlobalToggles.ChangePositionToggle, "Change Position", false)
            Toggle()

            Flags.Build:Init()
            Flags.Build:SetVisibility(Flags.Visibility)
            Flags.Build:Render(Flags.ShowPreview)
            Flags.Build:SetCFrame(Indicator.CFrame)    
            
            Indicator.Parent = Flags.Build.Model
            Flags.Build.Model.PrimaryPart = Indicator
        end
    end)

    print("load preview button loaded")

    local Rotate = Build:addSection("Rotation")

    Rotate:addButton("Rotate on X", function()
        if Flags.Build then
            Flags.Build:SetCFrame(Indicator.CFrame * CFrame.Angles(math.rad(90), 0, 0))
        end
    end)

    Rotate:addButton("Rotate on Y", function()
        if Flags.Build then
            Flags.Build:SetCFrame(Indicator.CFrame * CFrame.Angles(0, math.rad(90), 0))
        end
    end)

    Rotate:addButton("Rotate on Z", function()
        if Flags.Build then
            Flags.Build:SetCFrame(Indicator.CFrame * CFrame.Angles(0, 0, math.rad(90)))
        end
    end)

    print("rotation loaded")

    local BuildSection = Build:addSection("Build")
    BuildSection:addToggle("Show Build", true, function(willShow)
        Flags.ShowPreview = willShow
        Indicator.Transparency = willShow and 0.5 or 1
        Handles.Parent = willShow and game.CoreGui or game.ReplicatedStorage

        if Flags.Build then
            if Flags.Build.Model then
                Flags.Build:Render(Flags.ShowPreview)
            end
        end
    end)

    print("show build toggle loaded")

    BuildSection:addTextbox("Block transparency", "0.5", function(newTransparency, lost)
        if lost and tonumber(newTransparency) then
            Flags.Visibility = tonumber(newTransparency)
            if Flags.Build then
                Flags.Build:SetVisibility(Flags.Visibility)
            end
        end
    end)

    print("dropdown loaded")
    BuildSection:addButton("Start Building", function()
        if Flags.Build and Flags.Build.Model then
            local OriginalPosition = Player.Character.HumanoidRootPart.CFrame
            Flags.Build:Build({
                Start = function()
                    Velocity = Instance.new("BodyVelocity", Player.Character.HumanoidRootPart)
                    Velocity.Velocity = Vector3.new(0, 0, 0)
                end;
                Build = function(CF)
                    Player.Character.HumanoidRootPart.CFrame = CF + Vector3.new(10, 10, 10)
                end;
                End = function()
                    Velocity:Destroy()
                    Player.Character.HumanoidRootPart.CFrame = OriginalPosition
                end;
            })
        else
            Schematica:Notify("Error", "The model is not loaded yet, load it by pressing on Load Model")
        end
    end)

    print("start build button loaded")

    BuildSection:addButton("Abort", function()
        if Flags.Build then
            Flags.Build.Abort = true
        end
    end)
end

print("build section done")

do
    local round = math.round
    local Save = Schematica:addPage("Save Builds")

    local Flags = {
        ChangeStart = false,
        ChangeEnd = false,
        ShowOutline = true,
        BuildName = "Untitled",
        Private = "Public",
        CF1 = 0,
        CF2 = 0
    }

    local Points = Save:addSection("Set Points")

    GlobalToggles.SavePoint1 = Points:addToggle("Change Start Point", false, function(willChange)
        Flags.ChangeStart = willChange
        if willChange then
            Toggle("SavePoint1")
            --Points:updateToggle(GlobalToggles.SavePoint2, "Change End Point", false)
            Flags.ChangeEnd = false
        end
    end)

    GlobalToggles.SavePoint2 = Points:addToggle("Change End Point", false, function(willChange)
        Flags.ChangeEnd = willChange
        if willChange then
            Toggle("SavePoint2")
            --Points:updateToggle(GlobalToggles.SavePoint1, "Change Start Point", false)
            Flags.ChangeStart = false
        end
    end)

    print("points loaded")

    local Model = Instance.new("Model")

    local SelectionBox = Instance.new("SelectionBox")
    SelectionBox.Adornee = Model
    SelectionBox.SurfaceColor3 = Color3.new(1, 0, 0)
    SelectionBox.Color3 = Color3.new(1, 1, 1)
    SelectionBox.LineThickness = 0.1
    SelectionBox.SurfaceTransparency = 0.8
    SelectionBox.Visible = false
    SelectionBox.Parent = Model

    local IndicatorStart = Instance.new("Part")
    IndicatorStart.Size = Vector3.new(3.1, 3.1, 3.1)
    IndicatorStart.Transparency = 1
    IndicatorStart.Anchored = true
    IndicatorStart.CanCollide = false
    IndicatorStart.BrickColor = BrickColor.new("Really red")
    IndicatorStart.Material = "Plastic"
    IndicatorStart.TopSurface = Enum.SurfaceType.Smooth
    IndicatorStart.Parent = Model

    local IndicatorEnd = Instance.new("Part")
    IndicatorEnd.Size = Vector3.new(3.1, 3.1, 3.1)
    IndicatorEnd.Transparency = 1
    IndicatorEnd.Anchored = true
    IndicatorEnd.CanCollide = false
    IndicatorEnd.BrickColor = BrickColor.new("Really blue")
    IndicatorEnd.Material = "Plastic"
    IndicatorEnd.TopSurface = Enum.SurfaceType.Smooth
    IndicatorEnd.Parent = Model

    local StartHandles = Instance.new("Handles")

    StartHandles.Style = Enum.HandlesStyle.Movement
    StartHandles.Adornee = IndicatorStart
    StartHandles.Visible = false
    StartHandles.Parent = game.CoreGui

    local EndHandles = Instance.new("Handles")

    EndHandles.Style = Enum.HandlesStyle.Movement
    EndHandles.Adornee = IndicatorEnd
    EndHandles.Visible = false
    EndHandles.Parent = game.CoreGui

    print("instances loaded")

    StartHandles.MouseButton1Down:Connect(function()
        Flags.CF1 = StartHandles.Adornee.CFrame
    end)

    StartHandles.MouseDrag:Connect(function(Face, Distance)
        StartHandles.Adornee.CFrame = Flags.CF1 + Vector3.FromNormalId(Face) * (round(Distance / 3) * 3)
    end)

    EndHandles.MouseButton1Down:Connect(function()
        Flags.CF2 = EndHandles.Adornee.CFrame
    end)

    EndHandles.MouseDrag:Connect(function(Face, Distance)
        EndHandles.Adornee.CFrame = Flags.CF2 + Vector3.FromNormalId(Face) * (round(Distance / 3) * 3)
    end)

    print("connections loaded")

    Model.Parent = workspace
    
    Points:addToggle("Show Outline", true, function(willShow)
        Flags.ShowOutline = willShow

        IndicatorStart.Transparency = willShow and 0.5 or 1
        IndicatorEnd.Transparency = willShow and 0.5 or 1
        StartHandles.Visible = willShow
        EndHandles.Visible = willShow

        Model.Parent = willShow and workspace or game.ReplicatedStorage
    end)

     Mouse.Button1Down:Connect(function()
        if Mouse.Target then
            if Flags.ChangeStart or Flags.ChangeEnd then
                local ToChange = Flags.ChangeStart and "Start" or "End"
                if Mouse.Target.Parent.Name == "Blocks" or Mouse.Target.Parent.Parent.Name == "Blocks" then
                    local Part = Mouse.Target.Parent.Name == "Blocks" and Mouse.Target or Mouse.Target.Parent.Parent.Name == "Blocks" and Mouse.Target.Parent
                    Flags[ToChange] = Part.Position

                    if ToChange == "Start" then
                        StartHandles.Visible =  Flags.ShowOutline
                        IndicatorStart.Transparency = Flags.ShowOutline and 0.5 or 1
                    elseif ToChange == "End" then
                        EndHandles.Visible =  Flags.ShowOutline
                        IndicatorEnd.Transparency = Flags.ShowOutline and 0.5 or 1
                    end

                    if Flags.Start and Flags.End then
                        SelectionBox.Visible =  Flags.ShowOutline
                        if ToChange == "Start" then
                            IndicatorStart.Position = Part.Position
                        elseif ToChange == "End" then
                            IndicatorEnd.Position = Part.Position
                        end
                    else
                        IndicatorStart.Position = Part.Position
                        IndicatorEnd.Position = Part.Position
                    end
                end
            end
        end
    end)

    print("click con added")
    local Final = Save:addSection("Save")

    Final:addTextbox("Custom Name", "", function(name)
        Flags.BuildName = name
    end)

    Final:addToggle("Unlisted", false, function(isPrivate)
        Flags.Private = isPrivate and "Private" or "Public"
    end)

    Final:addButton("Save Area", function()
        local Serialize = Serializer.new(IndicatorStart.Position, IndicatorEnd.Position)
        local Data = Serialize:Serialize()

        local Response = Fetch({
            Url = Env.post;
            Body = game.HttpService:JSONEncode(Data);
            Headers = {
                ["Content-Type"] = "application/json",
                ["Build-Name"] = Flags.BuildName == "" and "Untitled" or Flags.BuildName;
                ["Private"] = Flags.Private
            };
            Method = "POST"
        })

        local JSONResponse = Http:JSONDecode(Response.Body)
        if JSONResponse.status == "success" then
            writefile("builds/" .. JSONResponse.output .. ".s", game.HttpService:JSONEncode(Data))
            setclipboard(JSONResponse.output)
            Schematica:Notify("Build Uploaded", "Copied to clipboard")
        else
            Schematica:Notify("Error", JSONResponse.status)
        end
    end)
    print("click and stuff added")
end

print("saving added")
do
    local Print = Schematica:addPage("Printer")

    local round = math.round
    
    local Flags = {
        ChangeStart = false,
        ChangeEnd = false,
        ShowOutline = true,
        CF1 = 0,
        CF2 = 0
    }

    local SetPoints = Print:addSection("Set Points")
    GlobalToggles.PrinterStart = SetPoints:addToggle("Change Start Point", false, function(willChange)
        Flags.ChangeStart = willChange
        if willChange then
            Flags.ChangeEnd = false
            Toggle("PrinterStart")
            --SetPoints:updateToggle(GlobalToggles.PrinterEnd, "Change End Point", false)
        end
    end)

    GlobalToggles.PrinterEnd = SetPoints:addToggle("Change End Point", false, function(willChange)
        Flags.ChangeEnd = willChange
        if willChange then
            Flags.ChangeStart = false
            Toggle("PrinterEnd")
            --SetPoints:updateToggle(GlobalToggles.PrinterStart, "Change Start Point", false)
        end
    end)

    local Model = Instance.new("Model")

    local SelectionBox = Instance.new("SelectionBox")
    SelectionBox.SurfaceColor3 = Color3.new(0, 1, 0)
    SelectionBox.Color3 = Color3.new(1, 1, 1)
    SelectionBox.LineThickness = 0.1
    SelectionBox.SurfaceTransparency = 0.8
    SelectionBox.Visible = false
    SelectionBox.Adornee = Model
    SelectionBox.Parent = Model

    local IndicatorStart = Instance.new("Part")
    IndicatorStart.Size = Vector3.new(3.1, 3.1, 3.1)
    IndicatorStart.Transparency = 1
    IndicatorStart.Anchored = true
    IndicatorStart.CanCollide = false
    IndicatorStart.BrickColor = BrickColor.new("Really red")
    IndicatorStart.Material = "Plastic"
    IndicatorStart.TopSurface = Enum.SurfaceType.Smooth
    IndicatorStart.Parent = Model

    local IndicatorEnd = Instance.new("Part")
    IndicatorEnd.Size = Vector3.new(3.1, 3.1, 3.1)
    IndicatorEnd.Transparency = 1
    IndicatorEnd.Anchored = true
    IndicatorEnd.CanCollide = false
    IndicatorEnd.BrickColor = BrickColor.new("Really blue")
    IndicatorEnd.Material = "Plastic"
    IndicatorEnd.TopSurface = Enum.SurfaceType.Smooth
    IndicatorEnd.Parent = Model

    local StartHandles = Instance.new("Handles")

    StartHandles.Style = Enum.HandlesStyle.Movement
    StartHandles.Visible = false
    StartHandles.Adornee = IndicatorStart
    StartHandles.Parent = game.CoreGui

    local EndHandles = Instance.new("Handles")

    EndHandles.Style = Enum.HandlesStyle.Movement
    EndHandles.Visible = false
    EndHandles.Adornee = IndicatorEnd
    EndHandles.Parent = game.CoreGui

    Model.Parent = workspace

    StartHandles.MouseButton1Down:Connect(function()
        Flags.CF1 = StartHandles.Adornee.CFrame
    end)

    StartHandles.MouseDrag:Connect(function(Face, Distance)
        StartHandles.Adornee.CFrame = Flags.CF1 + Vector3.FromNormalId(Face) * (round(Distance / 3) * 3)
    end)

    EndHandles.MouseButton1Down:Connect(function()
        Flags.CF2 = EndHandles.Adornee.CFrame
    end)

    EndHandles.MouseDrag:Connect(function(Face, Distance)
        EndHandles.Adornee.CFrame = Flags.CF2 + Vector3.FromNormalId(Face) * (round(Distance / 3) * 3)
    end)

    Mouse.Button1Down:Connect(function()
        if Mouse.Target then
            if Flags.ChangeStart or Flags.ChangeEnd then
                local ToChange = Flags.ChangeStart and "Start" or "End"
                if Mouse.Target.Parent.Name == "Blocks" or Mouse.Target.Parent.Parent.Name == "Blocks" then
                    local Part = Mouse.Target.Parent.Name == "Blocks" and Mouse.Target or Mouse.Target.Parent.Parent.Name == "Blocks" and Mouse.Target.Parent
                    Flags[ToChange] = Part.Position

                    if ToChange == "Start" then
                        StartHandles.Visible =  Flags.ShowOutline
                        IndicatorStart.Transparency = Flags.ShowOutline and 0.5 or 1
                    elseif ToChange == "End" then
                        EndHandles.Visible =  Flags.ShowOutline
                        IndicatorEnd.Transparency = Flags.ShowOutline and 0.5 or 1
                    end

                    if Flags.Start and Flags.End then
                        SelectionBox.Visible =  Flags.ShowOutline
                        if ToChange == "Start" then
                            IndicatorStart.Position = Part.Position
                        elseif ToChange == "End" then
                            IndicatorEnd.Position = Part.Position
                        end
                    else
                        IndicatorStart.Position = Part.Position
                        IndicatorEnd.Position = Part.Position
                    end
                end
            end
        end
    end)

    local Final = Print:addSection("Build")
    Final:addToggle("Show Outline", true, function(willShow)
        Flags.ShowOutline = willShow
        IndicatorStart.Transparency = willShow and 0.5 or 1
        IndicatorEnd.Transparency = willShow and 0.5 or 1

        if Flags.Start then
            StartHandles.Visible = willShow
        end

        if Flags.End then
            EndHandles.Visible = willShow
        end

        SelectionBox.Visible = willShow
    end)

    Final:addButton("Print Area", function()
        Toggle()
        if Flags.Start and Flags.End then
            if Player.Character:FindFirstChildOfClass("Tool") then
                local OriginalPosition = Player.Character.HumanoidRootPart.CFrame
                local BlockType = Player.Character:FindFirstChildOfClass("Tool").Name:gsub("Seeds", "")

                Flags.Printing = Printer.new(IndicatorStart.Position, IndicatorEnd.Position)
                Flags.Printing:SetBlock(BlockType)

                Flags.Printing:Build({
                    Start = function()
                        Velocity = Instance.new("BodyVelocity", Player.Character.HumanoidRootPart)
                        Velocity.Velocity = Vector3.new(0, 0, 0)
                    end;
                    Build = function(Pos)
                        Player.Character.HumanoidRootPart.CFrame = CFrame.new(Pos + Vector3.new(10, 10, 10))
                    end;
                    End = function()
                        Velocity:Destroy()
                        Player.Character.HumanoidRootPart.CFrame = OriginalPosition
                    end;
                })
            else
                Schematica:Notify("Error", "Please hold a block")
            end
        else
            Schematica:Notify("Error", "Please set the two points")
        end
    end)

    Final:addButton("Destroy Area", function()
        Toggle()
        local OriginalPosition = Player.Character.HumanoidRootPart.CFrame
        Flags.Printing = Printer.new(IndicatorStart.Position, IndicatorEnd.Position)

        Flags.Printing:Reverse({
            Start = function()
                Velocity = Instance.new("BodyVelocity", Player.Character.HumanoidRootPart)
                Velocity.Velocity = Vector3.new(0, 0, 0)
            end;
            Build = function(Pos)
                Player.Character.HumanoidRootPart.CFrame = CFrame.new(Pos + Vector3.new(5, 5, 5))
            end;
            End = function()
                Velocity:Destroy()
                Player.Character.HumanoidRootPart.CFrame = OriginalPosition
            end;
        })
    end)

    Final:addButton("Abort", function()
        Flags.Printing.Abort = true
    end)
end

do
    local Players = game.Players
    local Cache = {}

    local function closestIsland()local b=workspace:WaitForChild("Islands"):GetChildren()local c=Player.Character.HumanoidRootPart.Position for d=1,#b do local b=b[d]if b:FindFirstChild("Root")and math.abs(b.PrimaryPart.Position.X-c.X)<=1000 and math.abs(b.PrimaryPart.Position.Z-c.Z)<=1000 then return b end end return workspace.Islands:FindFirstChild(tostring(Player.UserId).."-island")end
    local function getUsernameFromUserId(b)if Cache[b]then return Cache[b]end local c=Players:GetPlayerByUserId(b)if c then Cache[b]=c.Name return c.Name end local c pcall(function()c=Players:GetNameFromUserIdAsync(b)end)Cache[b]=c return c end
    local function strArray(b)local c={}for b,d in next,b do c[b]=tonumber(d)end return c end

    local Other = Schematica:addPage("File Stuff")
    local ConvertOldSection = Other:addSection("Convert Old Build")

    local Flags = {
        Private = "Public",
        File = "",
        ToUpload = "",
        UploadPrivate = "Public"
    }

    ConvertOldSection:addTextbox("File", "", function(File)
        Flags.File = File .. ".s"
    end)

    local ClosestIslandSave = Other:addSection("Save Closest Island")
    ClosestIslandSave:addToggle("Unlisted", false, function(isPrivate)
        Flags.Private = isPrivate and "Private" or "Public"
    end)

    ClosestIslandSave:addButton("Save", function()
        local Closest = closestIsland()
        if Closest then
            local Username = getUsernameFromUserId(Closest.UserId.Value) or "An unknown person"
            local Center, Size = Closest:GetBoundingBox()

            local Serialize = Serializer.new(Center.Position - Size / 2, Center.Position + Size / 2)
            local Data = Serialize:Serialize()

            local Response = Fetch({
                Url = Env.post;
                Body = game.HttpService:JSONEncode(Data);
                Headers = {
                    ["Content-Type"] = "application/json";
                    ["Build-Name"] = Username .. "'s Island";
                    ["Private"] = Flags.Private and "Private" or "Public";
                };
                Method = "POST"
            })

            local JSONResponse = Http:JSONDecode(Response.Body)
            if JSONResponse.status == "success" then
                writefile("builds/" .. JSONResponse.output .. ".s", game.HttpService:JSONEncode(Data))
                setclipboard(JSONResponse.output)
                Schematica:Notify("Build Uploaded", "Copied to clipboard")
            else
                Schematica:Notify("Error", JSONResponse.status)
            end
        end
    end)

    ConvertOldSection:addButton("Convert", function()
        if isfile("builds/" .. Flags.File) then
            local Data = Http:JSONDecode(readfile("builds/" .. Flags.File))
            local Output = {}
            Output.Blocks = {}

            local LowX, LowY, LowZ = 0, 0, 0
            local HighX, HighY, HighZ = 3, 3, 3

            for Block, Array in next, Data do
                Output.Blocks[Block] = {}
                for i, v in next, Array do
                    local Split = strArray(v:split(","))
                    if Split[1] < LowX then
                        LowX = Split[1]
                    elseif Split[1] > HighX then
                        HighX = Split[1]
                    end

                    if Split[2] < LowY then
                        LowY = Split[2]
                    elseif Split[2] > HighY then
                        HighY = Split[2]
                    end

                    if Split[3] < LowZ then
                        LowZ = Split[3]
                    elseif Split[3] > HighZ then
                        HighZ = Split[3]
                    end

                    table.insert(Output.Blocks[Block], {
                        C = strArray(Split)
                    })
                end
            end

            Output.Size = {HighX - LowX, HighY - LowY, HighZ - LowZ}

            local FileName = Flags.File .. "-" .. tostring(os.time())
            writefile(string.format("builds/%s", FileName) .. ".s", Http:JSONEncode(Output))
            setclipboard(FileName)
            Schematica:Notify("Converted!", "Saved file as " .. FileName)
        end
    end)

    local UploadFile = Other:addSection("Upload File")
    UploadFile:addTextbox("File", "", function(File)
        Flags.ToUpload = File .. ".s"
    end)

    UploadFile:addToggle("Unlisted", false, function(isPrivate)
        Flags.UploadPrivate = isPrivate and "Private" or "Public"
    end)

    UploadFile:addButton("Upload", function()
        if isfile("builds/" .. Flags.ToUpload) then
            local Response = Fetch({
                Url = Env.post;
                Body = readfile("builds/" .. Flags.ToUpload);
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["Build-Name"] = Flags.ToUpload:gsub("%.(.+)", ""),
                    ["Private"] = Flags.UploadPrivate
                };
                Method = "POST"
            })

            local JSONResponse = Http:JSONDecode(Response.Body)
            if JSONResponse.status == "success" then
                writefile("builds/" .. JSONResponse.output, game.HttpService:JSONEncode(Data))
                setclipboard(JSONResponse.output)
                Schematica:Notify("Build Uploaded", "Copied to clipboard")
            else
                Schematica:Notify("Error", JSONResponse.status)
            end
        end
    end)
end

do
    local function getDisplayName(b)for c,c in pairs(game.ReplicatedStorage.Tools:GetChildren())do if c.Name:lower()==b:lower()and c:FindFirstChild("DisplayName")then return c:FindFirstChild("DisplayName").Value end end end

    local Utilities = Schematica:addPage("Utilities")
    local RequiredMats = Utilities:addSection("View Required Materials")

    local Flags = {
        Id = "0"
    }

    RequiredMats:addTextbox("Build ID", "0", function(Id)
        Flags.Id = Id
    end)

    local CurrentLabels = {}

    local Materials = Utilities:addSection("Materials")
    RequiredMats:addButton("View Materials", function()
        if isfile("builds/" .. Flags.Id .. ".s") then
            local Data = Http:JSONDecode(readfile("builds/" .. Flags.Id .. ".s"))

            for i, v in next, CurrentLabels do
                table.remove(Materials.modules, table.find(Materials.modules, v))
                v:Destroy()
            end

            for i, v in next, Data.Blocks do
                table.insert(CurrentLabels, Materials:addLabel(getDisplayName(i) .. " : " .. #v))
            end

            Materials:Resize()
        else
            local Response = Http:JSONDecode(game:HttpGet(Env.get .. Flags.Id))
            if Response.success == true then
                local Data = Response.data
                writefile("builds/" .. Flags.Id .. ".s", game.HttpService:JSONEncode(Data))

                for i, v in next, CurrentLabels do
                    table.remove(Materials.modules, table.find(Materials.modules, v))
                    v:Destroy()
                end

                for i, v in next, Data.Blocks do
                    table.insert(currentElements, Materials:addLabel(getDisplayName(i) .. " : " .. #v))
                end
                Materials:Resize()
            end
        end
    end)
end
