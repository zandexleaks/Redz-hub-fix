local fetcher = ...

local _ENV = (getgenv or getrenv or getfenv)()

local ReplicatedStorage = game:GetService("ReplicatedStorage");
local UserInputService = game:GetService("UserInputService");
local RunService = game:GetService("RunService");
local Players = game:GetService("Players");

local CoreGui = (gethui and gethui()) or game:GetService("CoreGui");

local DialogueEvent = ReplicatedStorage.BetweenSides.Remotes.Events.DialogueEvent;
local CombatEvent = ReplicatedStorage.BetweenSides.Remotes.Events.CombatEvent;
local ToolEvent = ReplicatedStorage.BetweenSides.Remotes.Events.ToolsEvent;

local Player = Players.LocalPlayer;

local Connections = _ENV.rz_connections or {} do
	_ENV.rz_connections = Connections
	
	for i = 1, #Connections do
		Connections[i]:Disconnect()
	end
	
	table.clear(Connections)
end

local Settings = _ENV.rz_settings or {} do
	_ENV.rz_settings = Settings;
	
	Settings.SelectedTool = "Combat";
	Settings.TweenSpeed = 150;
	Settings.SmoothMode = false;
	Settings.BringDistance = 150;
	Settings.FarmDistance = 12;
end

if type(fetcher) ~= "table" and isfile and isfile("redz-http-fetcher.lua") and readfile then
	fetcher = loadstring(readfile("redz-http-fetcher.lua"))()
end

local Options = {}
local clonedEnabled = {}
local Functions = _ENV.rz_Functions or {}
local FarmFunctions = _ENV.rz_FarmFunctions or {}

local Enabled_Toggle_Debounce = false;
local Enabled_New_Values = {};

local function UpdateEnabledOptions()
	table.clear(FarmFunctions)
	
	for index, value in pairs(Enabled_New_Values) do
		clonedEnabled[index] = value or nil;
		Enabled_New_Values[index] = nil;
	end
	
	for i = 1, #Functions do
		local funcData = Functions[i];
		if clonedEnabled[funcData.Name] then
			table.insert(FarmFunctions, funcData)
		end
	end
end

local Enabled = _ENV.rz_EnabledOptions or setmetatable({}, {
	__newindex = function(self, index, value)
		Enabled_New_Values[index] = value or false
		
		if not Enabled_Toggle_Debounce then
			Enabled_Toggle_Debounce = false
			
			task.delay(0.2, UpdateEnabledOptions)
		end
	end,
	__index = clonedEnabled
})

_ENV.rz_Functions = Functions
_ENV.rz_Settings = Settings
_ENV.rz_EnabledOptions = Enabled
_ENV.rz_FarmFunctions = FarmFunctions

local Library = fetcher.load("{Owner}Library/refs/heads/main/V5/Source.lua")()
local Module = fetcher.load("{Utils}VoxSeas/Module.luau")(Settings, Connections)

local IsAlive = Module.IsAlive;
local BringMobs = Module.BringMobs;
local EquipTool = Module.EquipTool;
local MobNameIs = Module.MobNameIs;
local GetEnemyByName = Module.GetEnemyByName;
local GetMobFromFolder = Module.GetMobFromFolder;

local PlayerTP = nil;
local Options = {};

local Managers = {} do
	Managers.QuestManager = (function()
		local QuestManager = {
			QuestsList = {};
			QuestsNPCs = {};
			EnemyList = {};
		}
		
		local CurrentQuest = nil;
		local CurrentLevel = -1;
		
		local MyLevelDisplay = Player.PlayerGui.MainUI.MainFrame.StastisticsFrame.LevelBackground.Level;
		local QuestFrame = Player.PlayerGui.MainUI.MainFrame.CurrentQuest;
		
		local QuestsDecriptions = require(ReplicatedStorage.MainModules.Essentials.QuestDescriptions);
		
		for _, QuestData in pairs(QuestsDecriptions) do
			if QuestData.Goal > 1 then
				table.insert(QuestManager.QuestsList, {
					Level = QuestData.MinLevel;
					Target = QuestData.Target;
					NpcName = QuestData.Npc;
					Id = QuestData.Id;
				})
			end
		end
		
		table.sort(QuestManager.QuestsList, function(a, b)
			return a.Level > b.Level;
		end)
		
		function QuestManager.GetCurrentQuest()
			MyLevelDisplay = Player.PlayerGui.MainUI.MainFrame.StastisticsFrame.LevelBackground.Level;
			local MyLevel = tonumber(MyLevelDisplay.Text) or CurrentLevel
			
			if MyLevel == CurrentLevel then
				return CurrentQuest;
			end
			
			for _, QuestData in pairs(QuestManager.QuestsList) do
				if QuestData.Level <= MyLevel then
					CurrentLevel, CurrentQuest = MyLevel, QuestData
					return QuestData
				end
			end
		end
		
		function QuestManager.HasQuest(EnemyName)
			QuestFrame = Player.PlayerGui.MainUI.MainFrame.CurrentQuest;
			return (QuestFrame.Visible and QuestFrame.Goal.Text:find(EnemyName));
		end
		
		function QuestManager.TakeQuest(QuestName, QuestId)
			local TargetCFrame = Module:GetQuestCFrame(QuestName)
			
			if TargetCFrame then
				DialogueEvent:FireServer("Quests", { ["NpcName"] = QuestName; ["QuestName"] = QuestId })
				PlayerTP(TargetCFrame)
			end
		end
		
		return QuestManager;
	end)()
	
	Managers.PlayerTween = (function()
		local TweenCreator = Module.RunFunctions.TweenCreator();
		local BodyVelocity = Module.TweenBodyVelocity;
		
		local function TweenStopped()
			if not BodyVelocity.Parent and IsAlive(Player.Character) then
				TweenCreator:stopTween(Player.Character:FindFirstChild("HumanoidRootPart"))
			end
		end
		
		local lastCFrame = nil;
		local lastTeleport = 0;
		
		PlayerTP = function(TargetCFrame)
			if not IsAlive(Player.Character) or not Player.Character.PrimaryPart then
				return false
			elseif (tick() - lastTeleport) <= 1 and lastCFrame == TargetCFrame then
				return false
			end
			
			local Character = Player.Character
			local Humanoid = Character.Humanoid
			local PrimaryPart = Character.PrimaryPart
			
			if Humanoid.Sit then Humanoid.Sit = false return end
			
			lastTeleport = tick()
			lastCFrame = TargetCFrame
			_ENV.OnFarm = true
			
			local teleportPosition = TargetCFrame.Position;
			local Distance = (PrimaryPart.Position - teleportPosition).Magnitude;
			
			if Distance < Settings.TweenSpeed then
				PrimaryPart.CFrame = TargetCFrame
				return TweenCreator:stopTween(PrimaryPart)
			end
			
			TweenCreator.new(PrimaryPart, Distance / Settings.TweenSpeed, "CFrame", TargetCFrame)
		end
		
		table.insert(Connections, BodyVelocity:GetPropertyChangedSignal("Parent"):Connect(TweenStopped))
	end)()
	
	Managers.EspManager = (function()
		local EspManager = {}
		EspManager.__index = EspManager
		EspManager.__newindex = function(self, index, value)
			if index == "Enabled" then
				task.spawn(self.ToggleEsp, self, value)
			else
				rawset(self, index, value)
			end
		end
		
		local CoreGuiEspFolder = Instance.new("Folder", CoreGui) do
			CoreGuiEspFolder.Name = "redzHub-EspFolder"
			
			local _EspFolder = CoreGui:FindFirstChild(CoreGuiEspFolder.Name)
			
			if _EspFolder and _EspFolder ~= CoreGuiEspFolder then
				_EspFolder:Destroy()
			end
		end
		
		local EspTemplate = Instance.new("BoxHandleAdornment") do
			local BoxHandleAdornment = EspTemplate
			BoxHandleAdornment.Size = Vector3.new(1, 0, 1, 0)
			BoxHandleAdornment.AlwaysOnTop = true
			BoxHandleAdornment.ZIndex = 10
			BoxHandleAdornment.Transparency = 0
			
			local BillboardGui = Instance.new("BillboardGui", BoxHandleAdornment)
			BillboardGui.Size = UDim2.new(0, 100, 0, 150)
			BillboardGui.StudsOffset = Vector3.new(0, 2, 0)
			BillboardGui.AlwaysOnTop = true
			
			local TextLabel = Instance.new("TextLabel", BillboardGui)
			TextLabel.BackgroundTransparency = 1
			TextLabel.Position = UDim2.new(0, 0, 0, -50)
			TextLabel.Size = UDim2.new(0, 100, 0, 100)
			TextLabel.TextSize = 10
			TextLabel.TextStrokeTransparency = 0
			TextLabel.TextYAlignment = Enum.TextYAlignment.Bottom
			TextLabel.Text = "..."
			TextLabel.ZIndex = 15
			TextLabel.RichText = true
		end
		
		local DefaultEspColor = Color3.fromRGB(255, 255, 255)
		local HumHealth = "%s<font color='rgb(160, 160, 160)'> [ %im ]</font>\n<font color='rgb(25, 240, 25)'>[%i/%i]</font>"
		local CreatedEsps = {}
		
		local function GetBasePart(Instance)
			if Instance:IsA("BasePart") then
				return Instance
			elseif Instance:IsA("Model") then
				return Instance.PrimaryPart or Instance:GetPivot()
			elseif Instance.Parent:IsA("Model") then
				return Instance.Parent.PrimaryPart or Instance.Parent:GetPivot()
			end
		end
		
		function EspManager:SetCustomEspDisplay(Action)
			self.CustomEspDisplay = Action
			return self
		end
		
		function EspManager:SetObjects(Objects)
			self.GetObjectsAction = Objects
			return self
		end
		
		function EspManager:GetInstance(Action)
			self.OnlyOneInstanceAction = Action
			return self
		end
		
		function EspManager:SetInstanceName(Instance, Name)
			self.EspsNames[Instance] = Name
			return self
		end
		
		function EspManager:SetAllInstancesName(Name)
			self.CustomInstanceName = Name
			return self
		end
		
		function EspManager:WaitChildsAdded()
			self._WaitChildsAdded = true
			return self
		end
		
		function EspManager:SetEspColor(Action)
			self.EspColor = Action
			return self
		end
		
		function EspManager:SetAlwaysValidate()
			self.AlwaysValidateInstance = true
			return self
		end
		
		function EspManager:Validator(Action)
			self.ValidateInstance = Action
			return self
		end
		
		function EspManager:ChangeEspSize(Size)
			self.EspSize = Size
			
			for i = 1, #CreatedEsps do
				for _, Esp in pairs(CreatedEsps[i].EspObjects) do
					Esp.BoxHandleAdornment.BillboardGui.TextLabel.TextSize = Size
				end
			end
			
			return self
		end
		
		function EspManager:StartRunningEsp(Esp)
			local Instance = Esp.Instance
			local BoxHandleAdornment = Esp.BoxHandleAdornment
			local TextLabel = BoxHandleAdornment.BillboardGui.TextLabel
			local Folder = self.EspFolder
			local IsModel = Instance:IsA("Model")
			local CachedBasePart = nil
			
			while task.wait(Settings.SmoothMode and 0.25 or 0) do
				if not BoxHandleAdornment or not BoxHandleAdornment.Parent then
					return self:Clear(Esp)
				elseif self.AlwaysValidateInstance and not self.ValidateInstance(Instance) then
					return self:Clear(Esp)
				elseif not Instance:IsDescendantOf(workspace) and not Instance:IsDescendantOf(ReplicatedStorage) then
					return self:Clear(Esp)
				end
				
				CachedBasePart = CachedBasePart or GetBasePart(Instance)
				
				if not CachedBasePart then
					return self:Clear(Esp)
				end
				
				local Distance = math.floor((DistanceFromMyCharacter(CachedBasePart)) / 5)
				local Humanoid = IsModel and FindFirstChildOfClass(Instance, "Humanoid")
				
				if Humanoid then
					TextLabel.Text = HumHealth:format(Instance.Name, Distance, math.floor(Humanoid.Health), math.floor(Humanoid.MaxHealth))
				elseif self.CustomEspDisplay then
					TextLabel.Text = self.CustomEspDisplay(Instance, Distance)
				else
					local Name = self.CustomInstanceName or self.EspsNames[Instance] or Instance.Name
					TextLabel.Text = ("%s < %i >"):format(Name, Distance)
				end
			end
		end
		
		function EspManager:Create(Instance)
			if self.EspObjects[Instance] then return end
			
			local Esp = {
				Instance = Instance,
				BoxHandleAdornment = nil
			}
			
			local BoxHandleAdornment = EspTemplate:Clone()
			local BillboardGui = BoxHandleAdornment.BillboardGui
			local TextLabel = BillboardGui.TextLabel
			
			BillboardGui.Adornee = (Instance:IsA("BasePart") or Instance:IsA("Model")) and Instance or Instance.Parent
			TextLabel.TextColor3 = type(self.EspColor) == "function" and self.EspColor(Instance) or self.EspColor or DefaultEspColor
			TextLabel.Text = self.CustomInstanceName or "..."
			TextLabel.TextSize = self.EspSize or TextLabel.TextSize
			BoxHandleAdornment.Parent = self.EspFolder
			
			self.EspObjects[Instance] = Esp
			Esp.BoxHandleAdornment = BoxHandleAdornment
			
			task.spawn(self.StartRunningEsp, self, Esp)
			
			return Esp
		end
		
		function EspManager:Clear(Esp)
			if Esp then
				self.EspObjects[Esp.Instance] = nil
				if Esp.BoxHandleAdornment then Esp.BoxHandleAdornment:Destroy() end
			else
				table.clear(self.EspObjects)
				self.EspFolder:ClearAllChildren()
			end
		end
		
		function EspManager:ToggleEsp(Value)
			local Environment = "redzHub_Esp_" .. self.SpecialTag
			_ENV[Environment] = Value
			
			if not Value then
				return self:Clear()
			end
			
			while _ENV[Environment] do
				local ObjectsAction = self.GetObjectsAction
				
				if self.OnlyOneInstanceAction then
					local Instance = self.OnlyOneInstanceAction()
					
					if Instance then
						self:Create(Instance)
					end
				elseif ObjectsAction then
					local Instances = typeof(ObjectsAction) == "Instance" and ObjectsAction:GetChildren() or ObjectsAction
					local Validate = self.ValidateInstance
					local CreatedEsps = self.EspObjects
					local CreatedNew = false
					
					for i = 1, #Instances do
						local Instance = Instances[i]
						
						if not CreatedEsps[Instance] and (not Validate or Validate(Instance)) then
							CreatedNew = true
							self:Create(Instance)
						end
					end
				end
				
				if not CreatedNew and self._WaitChildsAdded then
					ObjectsAction.ChildAdded:Wait()
				end
				
				task.wait(0.25)
			end
		end
		
		function EspManager.new(Tag)
			local EspFolder = Instance.new("Folder", CoreGuiEspFolder)
			EspFolder.Name = Tag
			
			local self = setmetatable({
				SpecialTag = Tag,
				EspObjects = {},
				EspsNames = {},
				EspFolder = EspFolder
			}, EspManager)
			
			table.insert(CreatedEsps, self)
			
			return self
		end
		
		return EspManager
	end)()
end

if not _ENV.loadedFarm then
	_ENV.loadedFarm = true
	
	task.spawn(Module.RunFunctions.FarmQueue, FarmFunctions)
end

if not _ENV.ExpandedHitbox then
	_ENV.ExpandedHitbox = true
	
loadstring([=[
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CombatService = require(ReplicatedStorage.Services.Combat.CombatService)
	local MainModueles = require(ReplicatedStorage.MainModules)
	
	local Player = game:GetService("Players").LocalPlayer
	
	local CreateHitbox;
	CreateHitbox = hookfunction(CombatService.IsClient.Hitbox.Call, function(self, HitboxSettings)
		HitboxSettings.BoxSize = Vector3.one * 100
		return CreateHitbox(self, HitboxSettings)
	end)
	
	local CheckCooldown;
	CheckCooldown = hookfunction(MainModueles.CombatHandler.IsCooldown, function(Name)
		local Equipped = Player.Character and Player.Character:FindFirstChildOfClass("Tool")
		
		if Equipped and Equipped.Name == Name then
			return false
		end
		
		return CheckCooldown(Name)
	end)
]=])()
end

do
	table.clear(Functions)
	
	local index = {}
	
	local function NewOptionQueue(Tag, Function, Confirm)
		if Confirm ~= false then
			local Data = { ["Name"] = Tag, ["Function"] = Function }
			
			index[ Tag ] = Function
			table.insert(Functions, Data)
		end
	end
	
	local QuestManager = Managers.QuestManager;
	
	local GetCurrentQuest = QuestManager.GetCurrentQuest;
	local TakeQuest = QuestManager.TakeQuest;
	local HasQuest = QuestManager.HasQuest;
	
	NewOptionQueue("Level", function()
		local CurrentQuest = GetCurrentQuest()
		if not CurrentQuest then return end
		
		if not HasQuest(CurrentQuest.Target) then
			TakeQuest(CurrentQuest.NpcName, CurrentQuest.Id);
			return true;
		end
		
		local Enemy = GetEnemyByName(CurrentQuest.Target)
		if not Enemy then return end
		
		local HumanoidRootPart = Enemy:FindFirstChild("HumanoidRootPart")
		if not HumanoidRootPart then return end
		
		local Equipped = EquipTool()
		
		if Equipped then
			Equipped:Activate();
			Equipped.Enabled = true;
			
			BringMobs(Enemy)
			PlayerTP(HumanoidRootPart.CFrame + Vector3.yAxis * Settings.FarmDistance)
			return true
		end
	end)
end

do
	local Logo1 = "rbxassetid://15298567397";
	local Logo2 = "rbxassetid://17382040552";
	
	local Name = "redz Hub : Vox Seas";
	local Folder = "redzHub-VoxSeas.json";
	local Credits = "by real_redz";
	local DiscordInvite = "https://discord.gg/7aR7kNVt4g";
	
	local Window = Library:MakeWindow({Name, Credits, Folder});
	local LeftControl = Enum.KeyCode.LeftControl;
	
	Window:AddMinimizeButton({
		Button = { Image = Logo1, BackgroundTransparency = 0 };
		Corner = { CornerRadius = UDim.new(0, 6) };
	});
	
	table.insert(Connections, UserInputService.InputBegan:Connect(function(Input)
		if Input.KeyCode == LeftControl then
			Window:Minimize()
		end
	end))
	
	local MainTab = Window:MakeTab({ "Main", "Home" });
	-- local StatsTab = Window:MakeTab({ "Stats", "Signal" });
	-- local StatsTab = Window:MakeTab({ "Shop", "ShoppingCart" });
	-- local Visual = Window:MakeTab({ "Visual", "User" });
	local SettingsTab = Window:MakeTab({ "Configs", "Settings" });
	
	local Plugin = Module.RunFunctions.OptionsPlugin(Enabled, Options);
	local AddToggle = Plugin.Toggle;
	
	do
		MainTab:AddSection("Main Farm")
		AddToggle(MainTab, {"Auto Farm Level"}, "Level")
	end
	
	do
		-- SettingsTab:AddToggle({"Bring Mobs", false, {Settings, "BringMobs"} })
		SettingsTab:AddSlider({"Tween Speed", 50, 200, 10, 125, {Settings, "TweenSpeed"} })
		SettingsTab:AddDropdown({"Select Tool", {"Combat"}, "Combat", {Settings, "SelectedTool"} })
	end
end
