-- =================================
-- NADMOD PP - Prop Protection
-- By Nebual@nebtown.info 2012
-- Menus designed after SpaceTech's Simple Prop Protection
-- =================================
local string_sub = string.sub
local ipairs = ipairs
local IsValid = IsValid

if not NADMOD then
	NADMOD = {}
	NADMOD.PropOwners = {}
	NADMOD.PropNames = {}
	NADMOD.PPConfig = {}
	NADMOD.Friends = {}
end

local Props = NADMOD.PropOwners
local PropNames = NADMOD.PropNames
net.Receive("nadmod_propowners", function()
	local nameMap = {}
	for i = 1, net.ReadUInt(8) do
		nameMap[i] = {SteamID = net.ReadString(), Name = net.ReadString()}
	end
	for _ = 1, net.ReadUInt(32) do
		local id, owner = net.ReadUInt(16), nameMap[net.ReadUInt(8)]
		if owner.SteamID == "-" then Props[id] = nil PropNames[id] = nil
		elseif owner.SteamID == "W" then PropNames[id] = "World"
		elseif owner.SteamID == "O" then PropNames[id] = "Ownerless"
		else
			Props[id] = owner.SteamID
			PropNames[id] = owner.Name
		end
	end
end)

function NADMOD.GetPropOwner(ent)
	local id = Props[ent:EntIndex()]
	return id and player.GetBySteamID(id)
end

function NADMOD.PlayerCanTouch(ply, ent)
	-- If PP is off or the ent is worldspawn, let them touch it
	if not tobool(NADMOD.PPConfig["toggle"]) then return true end
	if ent:IsWorld() then return ent:GetClass() == "worldspawn" end
	if not IsValid(ent) or not IsValid(ply) or ent:IsPlayer() or not ply:IsPlayer() then return false end

	local index = ent:EntIndex()
	if not Props[index] then
		return false
	end

	-- Ownerless props can be touched by all
	if PropNames[index] == "Ownerless" then return true end
	-- Admins can touch anyones props + world
	if NADMOD.PPConfig["adminall"] and NADMOD.IsPPAdmin(ply) then return true end
	-- Players can touch their own props
	local plySteam = ply:SteamID()
	if Props[index] == plySteam then return true end
	-- Friends can touch LocalPlayer()'s props
	if Props[index] == LocalPlayer():SteamID() and NADMOD.Friends[plySteam] then return true end

	return false
end

-- Does your admin mod not seem to work with Nadmod PP? Try overriding this function!
function NADMOD.IsPPAdmin(ply)
	if NADMOD.HasPermission then
		return NADMOD.HasPermission(ply, "PP_All")
	else
		-- If the admin mod NADMOD isn't present, just default to using IsAdmin
		return ply:IsAdmin()
	end
end

do
	local draw_RoundedBox = draw.RoundedBox
	local draw_SimpleText = draw.SimpleText
	local surface_GetTextSize = surface.GetTextSize
	local math_Max = math.Max
	local string_Explode = string.Explode
	local table_remove = table.remove
	local CurTime = CurTime
	local math_Round = math.Round

	local nadmod_overlay_convar = CreateClientConVar("nadmod_overlay", 2, true, false, "0 - Disables NPP Overlay. 1 - Minimal overlay of just owner info. 2 - Includes model, entityID, class, speed", 0, 2)
	local font = "ChatFont"
	local boxColor = Color(0, 0, 0, 150)
	local textColor = Color(255, 255, 255, 255)
	local refreshDelay = 0.2
	local refreshTime = CurTime() + refreshDelay
	local text4 = ""

	hook.Add("HUDPaint", "NADMOD.HUDPaint", function()
		local nadmod_overlay_setting = nadmod_overlay_convar:GetInt()
		if nadmod_overlay_setting == 0 then return end
		local tr = LocalPlayer():GetEyeTrace()
		if not tr.HitNonWorld then return end
		local ent = tr.Entity
		if not IsValid( ent ) or ent:IsPlayer() then return end

		local text = "Owner: " .. (PropNames[ent:EntIndex()] or "N/A")
		surface.SetFont(font)
		local Width, Height = surface_GetTextSize(text)
		local boxWidth = Width + 25
		local boxHeight = Height + 16
		local scrW = ScrW()
		local scrH = ScrH() / 2 - 200

		if nadmod_overlay_setting == 2 then
			local text2 = "'" .. string_sub(table_remove(string_Explode("/", ent:GetModel() or "?")), 1, -5) .. "' [" .. ent:EntIndex() .. "]"
			local text3 = ent:GetClass()
			if refreshTime < CurTime() + refreshDelay then
				text4 = "Speed: " .. math_Round(ent:GetVelocity():Length()) .. " u/s"
				refreshTime = CurTime() + refreshDelay
			end
			local w2, h2 = surface_GetTextSize(text2)
			local w3, h3 = surface_GetTextSize(text3)
			local w4, h4 = surface_GetTextSize(text4)
			boxWidth = math_Max(Width, w2, w3) + 25
			boxHeight = boxHeight + h2 + h3 + h4
			draw_RoundedBox(4, scrW - (boxWidth + 4), scrH - 16, boxWidth, boxHeight, boxColor)
			draw_SimpleText(text, font, scrW - (Width / 2) - 20, scrH, textColor, 1, 1)
			draw_SimpleText(text2, font, scrW - (w2 / 2) - 20, scrH + Height, textColor, 1, 1)
			draw_SimpleText(text3, font, scrW - (w3 / 2) - 20, scrH + Height + h2, textColor, 1, 1)
			draw_SimpleText(text4, font, scrW - (w4 / 2) - 20, scrH + Height + h2 + h3, textColor, 1, 1)
		else
			draw_RoundedBox(4, scrW - (boxWidth + 4), scrH - 16, boxWidth, boxHeight, boxColor)
			draw_SimpleText(text, font, scrW - (Width / 2) - 20, scrH, textColor, 1, 1)
		end
	end)
end

function NADMOD.CleanCLRagdolls()
	for _, v in ipairs(ents.FindByClass("class C_ClientRagdoll")) do v:SetNoDraw(true) end
	for _, v in ipairs(ents.FindByClass("class C_BaseAnimating")) do v:SetNoDraw(true) end
end
net.Receive("nadmod_cleanclragdolls", NADMOD.CleanCLRagdolls)

-- =============================
-- NADMOD PP CPanels
-- =============================
net.Receive("nadmod_ppconfig",function()
	NADMOD.PPConfig = net.ReadTable()
	for k,v in pairs(NADMOD.PPConfig) do
		local val = v
		if isbool(v) then val = v and "1" or "0" end

		CreateClientConVar("npp_" .. k, val, false, false)
		RunConsoleCommand("npp_" .. k, val)
	end
	NADMOD.AdminPanel(NADMOD.AdminCPanel, true)
end)

concommand.Add("npp_apply",function()
	for k,v in pairs(NADMOD.PPConfig) do
		if isbool(v) then NADMOD.PPConfig[k] = GetConVar("npp_" .. k):GetBool()
		elseif isnumber(v) then NADMOD.PPConfig[k] = GetConVar("npp_" .. k):GetInt()
		else NADMOD.PPConfig[k] = GetConVar("npp_" .. k):GetString()
		end
	end
	net.Start("nadmod_ppconfig")
		net.WriteTable(NADMOD.PPConfig)
	net.SendToServer()
end)

function NADMOD.AdminPanel(Panel, runByNetReceive)
	if Panel and not NADMOD.AdminCPanel then
		NADMOD.AdminCPanel = Panel
	end

	Panel:ClearControls()

	local nonadmin_help = Panel:Help("")
	nonadmin_help:SetAutoStretchVertical(false)
	if not runByNetReceive then
		RunConsoleCommand("npp_refreshconfig")
		timer.Create("NADMOD.AdminPanelCheckFail",0.75,1,function()
			nonadmin_help:SetText("Waiting for the server to say you're an admin...")
		end)
		if not NADMOD.PPConfig then return end
	else
		timer.Remove("NADMOD.AdminPanelCheckFail")
	end
	Panel:SetName("NADMOD PP Admin Panel")

	Panel:CheckBox("Main PP Power Switch", "npp_toggle")
	Panel:CheckBox("Admins can touch anything", "npp_adminall")
	local use_protection = Panel:CheckBox("Use (E) Protection", "npp_use")
	use_protection:SetTooltip("Stop nonfriends from entering vehicles, pushing buttons/doors")

	local txt = Panel:Help("Autoclean Disconnected Players?")
	txt:SetAutoStretchVertical(false)
	txt:SetContentAlignment( TEXT_ALIGN_CENTER )
	local autoclean_admins = Panel:CheckBox("Autoclean Admins", "npp_autocdpadmins")
	autoclean_admins:SetTooltip("Should Admin Props also be autocleaned?")
	local autoclean_timer = Panel:NumSlider("Autoclean Timer", "npp_autocdp", 0, 1200, 0 )
	autoclean_timer:SetTooltip("0 disables autocleaning")
	Panel:Button("Apply Settings", "npp_apply")

	local pnlTxt = Panel:Help("                     Cleanup Panel")
	pnlTxt:SetContentAlignment( TEXT_ALIGN_CENTER )
	pnlTxt:SetFont("DermaDefaultBold")
	pnlTxt:SetAutoStretchVertical(false)

	local counts = {}
	for _, v in ipairs(NADMOD.PropOwners) do
		counts[v] = (counts[v] or 0) + 1
	end
	local dccount = 0
	for k,v in pairs(counts) do
		if k ~= "World" and k ~= "Ownerless" then dccount = dccount + v end
	end
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) then
			local steamid = ply:SteamID()
			Panel:Button( ply:Nick() .. " (" .. (counts[steamid] or 0) .. ")", "nadmod_cleanupprops", ply:EntIndex() )
			dccount = dccount - (counts[steamid] or 0)
		end
	end

	Panel:Help(""):SetAutoStretchVertical(false) -- Spacer
	Panel:Button("Cleanup Disconnected Players Props (" .. dccount .. ")", "nadmod_cdp")
	Panel:Button("Cleanup All NPCs", 			"nadmod_cleanclass", "npc_*")
	Panel:Button("Cleanup All Ragdolls", 		"nadmod_cleanclass", "prop_ragdol*")
	Panel:Button("Cleanup Clientside Ragdolls", "nadmod_cleanclragdolls")
	Panel:Button("Cleanup World Ropes", "nadmod_cleanworldropes")
end

local metaply = FindMetaTable("Player")
local metaent = FindMetaTable("Entity")

-- Wrapper function as Bots return nothing clientside for their SteamID64
function metaply:SteamID64bot()
	if not IsValid( self ) then return end
	if self:IsBot() then
		-- Calculate Bot's SteamID64 according to gmod wiki
		return 90071996842377216 + tonumber( string_sub( self:Nick(), 4) ) - 1
	else
		return self:SteamID64()
	end
end

net.Receive("nadmod_ppfriends",function()
	NADMOD.Friends = net.ReadTable()
	for _, tar in ipairs(player.GetAll()) do
		CreateClientConVar("npp_friend_" .. tar:SteamID64bot(),NADMOD.Friends[tar:SteamID()] and "1" or "0", false, false)
		RunConsoleCommand("npp_friend_" .. tar:SteamID64bot(),NADMOD.Friends[tar:SteamID()] and "1" or "0")
	end
end)

concommand.Add("npp_applyfriends",function()
	for _, tar in ipairs(player.GetAll()) do
		NADMOD.Friends[tar:SteamID()] = GetConVar("npp_friend_" .. tar:SteamID64bot()):GetBool()
	end
	net.Start("nadmod_ppfriends")
		net.WriteTable(NADMOD.Friends)
	net.SendToServer()
end)

function NADMOD.ClientPanel(Panel)
	RunConsoleCommand("npp_refreshfriends")
	Panel:ClearControls()
	if not NADMOD.ClientCPanel then NADMOD.ClientCPanel = Panel end
	Panel:SetName("NADMOD - Client Panel")

	Panel:Button("Cleanup Props", "nadmod_cleanupprops")
	Panel:Button("Clear Clientside Ragdolls", "nadmod_cleanclragdolls")

	local txt = Panel:Help("                     Friends Panel")
	txt:SetContentAlignment( TEXT_ALIGN_CENTER )
	txt:SetFont("DermaDefaultBold")
	txt:SetAutoStretchVertical(false)

	local Players = player.GetAll()
	if table.Count(Players) == 1 then
		Panel:Help("No Other Players Are Online")
	else
		for _, tar in ipairs(Players) do
			if IsValid(tar) and tar ~= LocalPlayer() then
				Panel:CheckBox(tar:Nick(), "npp_friend_" .. tar:SteamID64bot())
			end
		end
		Panel:Button("Apply Friends", "npp_applyfriends")
	end
end

function NADMOD.SpawnMenuOpen()
	if NADMOD.AdminCPanel then
		NADMOD.AdminPanel(NADMOD.AdminCPanel)
	end
	if NADMOD.ClientCPanel then
		NADMOD.ClientPanel(NADMOD.ClientCPanel)
	end
end
hook.Add("SpawnMenuOpen", "NADMOD.SpawnMenuOpen", NADMOD.SpawnMenuOpen)

function NADMOD.PopulateToolMenu()
	spawnmenu.AddToolMenuOption("Utilities", "NADMOD Prop Protection", "Admin", "Admin", "", "", NADMOD.AdminPanel)
	spawnmenu.AddToolMenuOption("Utilities", "NADMOD Prop Protection", "Client", "Client", "", "", NADMOD.ClientPanel)
end
hook.Add("PopulateToolMenu", "NADMOD.PopulateToolMenu", NADMOD.PopulateToolMenu)

net.Receive("nadmod_notify", function()
	local text = net.ReadString()
	notification.AddLegacy(text, NOTIFY_GENERIC, 5)
	surface.PlaySound("ambient/water/drip" .. math.random(1, 4) .. ".wav")
	print(text)
end)

CPPI = {}

function CPPI:GetName() return "Nadmod Prop Protection" end
function CPPI:GetVersion() return "" end
function metaply:CPPIGetFriends() return {} end
function metaent:CPPIGetOwner() return NADMOD.GetPropOwner(self) end
function metaent:CPPICanTool(ply) return NADMOD.PlayerCanTouch(ply,self) end
function metaent:CPPICanPhysgun(ply) return NADMOD.PlayerCanTouch(ply,self) end
function metaent:CPPICanPickup(ply) return NADMOD.PlayerCanTouch(ply,self) end
function metaent:CPPICanPunt(ply) return NADMOD.PlayerCanTouch(ply,self) end