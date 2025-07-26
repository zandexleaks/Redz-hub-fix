local Settings, Connections = ...

local _ENV = (getgenv or getrenv or getfenv)()

local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage");
local CollectionService: CollectionService = game:GetService("CollectionService");
local TweenService: TweenService = game:GetService("TweenService");
local RunService: RunService = game:GetService("RunService");
local Players: Players = game:GetService("Players");

local QuestsNpcs = workspace.IgnoreList.Int.NPCs.Quests;
local Enemys = workspace.Playability.Enemys;

local Player = Players.LocalPlayer;

local Module = {};
local MobsFolders = {};

Module.RunFunctions = {} do
	local function ShowErrorMessage(ErrorMessage)
		_ENV.loadedFarm = false
		_ENV.OnFarm = false
		
		local text = (`redz-Hub error [ { Settings.RunningOption or "Null" } ] { ErrorMessage }`)
		
		if _ENV.rz_error_message then
			_ENV.rz_error_message.Text ..= `\n\n{ text }`
			return nil
		end
		
		local Message = Instance.new("Message", workspace)
		_ENV.rz_error_message = Message
		Message.Text = text
	end
	
	Module.RunFunctions.FarmQueue = function(Options)
		local Success, ErrorMessage = pcall(function()
			local function GetQueue()
				for _, Option in Options do
					Settings.RunningOption = Option.Name
					local Method = Option.Function()
					
					if Method then
						if type(Method) == "string" then
							Settings.RunningMethod = Method
						end
						return Method
					end
				end
				
				Settings.RunningOption, Settings.RunningMethod = nil, nil
			end
			
			while task.wait(Settings.SmoothMode and 0.25 or 0) do
				if _ENV.teleporting then
					_ENV.OnFarm = true
				elseif Settings.FixOverflow then
					local Success, Response = pcall(GetQueue)
					
					_ENV.OnFarm = (not Success and _ENV.OnFarm) or Response
				else
					_ENV.OnFarm = if GetQueue() then true else false
				end
			end
		end)
		
		ShowErrorMessage(ErrorMessage)
	end
	
	Module.RunFunctions.TweenCreator = function()
		local TweenCreator = {}
		TweenCreator.__index = TweenCreator
		
		local tweens = {}
		local EasingStyle = Enum.EasingStyle.Linear
		
		function TweenCreator.new(obj: Instance, time: number, prop: string, value: any): TweenCreator
			local self = setmetatable({}, TweenCreator)
			
			self.tween = TweenService:Create(obj, TweenInfo.new(time, EasingStyle), { [prop] = value })
			self.tween:Play()
			self.value = value
			self.object = obj
			
			if tweens[obj] then
				tweens[obj]:destroy()
			end
			
			tweens[obj] = self
			return self
		end
		
		function TweenCreator:destroy(): (nil)
			self.tween:Pause()
			self.tween:Destroy()
			
			tweens[self.object] = nil
			setmetatable(self, nil)
		end
		
		function TweenCreator:stopTween(obj: Instance): (nil)
			if obj and tweens[obj] then
				tweens[obj]:destroy()
			end
		end
		
		return TweenCreator
	end
	
	Module.RunFunctions.OptionsPlugin = function(EnabledOptions, Options)
		local Plugin = {}
		
		function Plugin.Toggle(Tab, Settings, Flag)
			Options[Flag] = Tab:AddToggle({
				Name = Settings[1],
				Default = if type(Settings[2]) ~= "string" then Settings[2] else nil,
				Description = Settings[if type(Settings[2]) == "string" then 2 else 3],
				Callback = function(Value) EnabledOptions[Flag] = Value end,
				Flag = Flag,
			})
		end
		
		return Plugin
	end
end

local function IsAlive(Character: Model): boolean?
	if Character then
		local Humanoid = Character:FindFirstChildOfClass("Humanoid", true);
		return Humanoid and Humanoid.Health > 0;
	end
end

local function BringMobs(BaseMob: Model): (nil)
	local OriginalName = BaseMob:GetAttribute("OriginalName");
	local EnemyRootPart = BaseMob.HumanoidRootPart;
	local BringPosition = EnemyRootPart.Position;
	
	pcall(sethiddenproperty, Player, "SimulationRadius", 1250);
	
	for _, Enemy in BaseMob.Parent:GetChildren() do
		if not IsAlive(Enemy) then continue end;
		if Enemy:GetAttribute("OriginalName") ~= OriginalName then continue end;
		local RootPart = Enemy:FindFirstChild("HumanoidRootPart");
		
		if RootPart and (BringPosition - RootPart.Position).Magnitude <= Settings.BringDistance then
			if not RootPart:FindFirstChild("BodyVelocity") then
				local BV = Instance.new("BodyVelocity", RootPart)
				BV.Velocity = Vector3.zero;
				BV.MaxForce = Vector3.one * math.huge;
			end
			
			RootPart.Size = Vector3.one * 50;
			RootPart.CFrame = EnemyRootPart.CFrame;
			RootPart.CanCollide = false
		end
	end
end

local function CanAttackMob(Enemy: Model): boolean
	return (Enemy:GetAttribute("Respawned") and Enemy:GetAttribute("Ready")) or false
end

local function MobNameIs(Enemy: Model, Name: string): boolean
	return Enemy:GetAttribute("OriginalName") == Name
end

local function GetMobFromFolder(Folder: Folder, Name: string): Model
	for _, Enemy in Folder:GetChildren() do
		if CanAttackMob(Enemy) and MobNameIs(Enemy, Name) then
			return Enemy;
		end
	end
end

local function GetEnemyByName(Name: string): Model?
	local EnemyFolder = MobsFolders[Name]
	
	if EnemyFolder then
		return GetMobFromFolder(EnemyFolder, Name)
	end
	
	for _, Folder in Enemys:GetChildren() do
		for _, Enemy in Folder:GetChildren() do
			if not MobNameIs(Enemy, Name) then continue end
			
			MobsFolders[Name] = Folder
			return GetMobFromFolder(Folder, Name)
		end
	end
end

local function IsSelectedTool(Tool: Tool): unknown
	return Tool:GetAttribute(`{Settings.SelectedTool}Type`);
end

local function EquipTool(): Tool?
	if not IsAlive(Player.Character) then return end
	
	if EquippedTool and IsSelectedTool(EquippedTool) then
		if EquippedTool.Parent == Player.Backpack then
			Player.Character.Humanoid:EquipTool(EquippedTool)
		elseif EquippedTool.Parent ~= Player.Character then
			EquippedTool = nil;
		end
		
		return EquippedTool
	end
	
	local Equipped = Player.Character:FindFirstChildOfClass("Tool")
	
	if Equipped and IsSelectedTool(Equipped) then
		EquippedTool = Equipped
	else
		for _, Tool in ipairs(Player.Backpack:GetChildren()) do
			if not Tool:IsA("Tool") or not IsSelectedTool(Tool) then continue end
			
			EquippedTool = Tool
			break
		end
	end
	
	return EquippedTool;
end

Module.TweenBodyVelocity = (function()
	local BodyVelocity = Instance.new("BodyVelocity")
	BodyVelocity.Velocity = Vector3.zero
	BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	BodyVelocity.P = 1000
	
	if _ENV.tween_bodyvelocity then
		_ENV.tween_bodyvelocity:Destroy()
	end
	
	_ENV.tween_bodyvelocity = BodyVelocity
	
	local CanCollideObjects = {}
	
	local function AddObjectToBaseParts(Object)
		if Object:IsA("BasePart") and Object.CanCollide then
			table.insert(CanCollideObjects, Object)
		end
	end
	
	local function RemoveObjectsFromBaseParts(BasePart)
		local index = table.find(CanCollideObjects, BasePart)
		
		if index then
			table.remove(CanCollideObjects, index)
		end
	end
	
	local function NewCharacter(Character)
		if not Character then return end
		
		table.clear(CanCollideObjects)
		
		for _, Object in Character:GetDescendants() do AddObjectToBaseParts(Object) end
		Character.DescendantAdded:Connect(AddObjectToBaseParts)
		Character.DescendantRemoving:Connect(RemoveObjectsFromBaseParts)
	end
	
	table.insert(Connections, Player.CharacterAdded:Connect(NewCharacter))
	task.spawn(NewCharacter, Player.Character)
	
	local function NoClipOnStepped(Character)
		if _ENV.OnFarm then
			for i = 1, #CanCollideObjects do
				CanCollideObjects[i].CanCollide = false
			end
		elseif Character.PrimaryPart and not Character.PrimaryPart.CanCollide then
			for i = 1, #CanCollideObjects do
				CanCollideObjects[i].CanCollide = true
			end
		end
	end
	
	local function UpdateVelocityOnStepped(Character)
		local BasePart = Character:FindFirstChild("UpperTorso")
		local Humanoid = Character:FindFirstChild("Humanoid")
		local BodyVelocity = _ENV.tween_bodyvelocity
		
		if _ENV.OnFarm and BasePart and Humanoid and Humanoid.Health > 0 then
			if BodyVelocity.Parent ~= BasePart then
				BodyVelocity.Parent = BasePart
			end
		elseif BodyVelocity.Parent then
			BodyVelocity.Parent = nil
		end
		
		if BodyVelocity.Velocity ~= Vector3.zero and (not Humanoid or not Humanoid.SeatPart or not _ENV.OnFarm) then
			BodyVelocity.Velocity = Vector3.zero
		end
	end
	
	table.insert(Connections, RunService.Stepped:Connect(function()
		local Character = Player.Character;
		
		if IsAlive(Character) then
			UpdateVelocityOnStepped(Character)
			NoClipOnStepped(Character)
		end
	end))
	
	return BodyVelocity
end)()

function Module:GetQuestCFrame(QuestName: string): CFrame?
	local Target = QuestsNpcs:FindFirstChild(QuestName, true)
	
	if Target and Target.PrimaryPart then
		return Target.PrimaryPart.CFrame
	end
end

Module.IsAlive = IsAlive;
Module.EquipTool = EquipTool;
Module.BringMobs = BringMobs;
Module.MobNameIs = MobNameIs;
Module.GetEnemyByName = GetEnemyByName;
Module.GetMobFromFolder = GetMobFromFolder;

return Module;
