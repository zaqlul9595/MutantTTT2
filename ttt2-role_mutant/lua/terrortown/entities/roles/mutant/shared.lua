if SERVER then
	AddCSLuaFile()
end

function ROLE:PreInitialize()
  self.color = Color(0, 101, 51, 255)

  self.abbr = "mut" -- abbreviation
  self.surviveBonus = 0 -- bonus multiplier for every survive while another player was killed
  self.scoreKillsMultiplier = 2 -- multiplier for kill of player of another team
  self.scoreTeamKillsMultiplier = -8 -- multiplier for teamkill
  self.unknownTeam = true

  self.defaultTeam = TEAM_INNOCENT

  self.conVarData = {
    pct = 0.17, -- necessary: percentage of getting this role selected (per player)
    maximum = 1, -- maximum amount of roles in a round
    minPlayers = 6, -- minimum amount of players until this role is able to get selected
    credits = 0, -- the starting credits of a specific role
    togglable = true, -- option to toggle a role for a client if possible (F1 menu)
    random = 33,
    traitorButton = 0, -- can use traitor buttons
    shopFallback = SHOP_DISABLED
  }
end

-- now link this subrole with its baserole
function ROLE:Initialize()
  roles.SetBaseRole(self, ROLE_INNOCENT)
end

if SERVER then
   -- Give Loadout on respawn and rolechange
	function ROLE:GiveRoleLoadout(ply, isRoleChange)
		if not GetConVar("ttt2_mut_firedmg"):GetBool() then
			ply:GiveEquipmentItem("item_ttt_nofiredmg")
		end
		if not GetConVar("ttt2_mut_explosivedmg"):GetBool() then
			ply:GiveEquipmentItem("item_ttt_noexplosiondmg")
		end
		if not GetConVar("ttt2_mut_falldmg"):GetBool() then
			ply:GiveEquipmentItem("item_ttt_nofalldmg")
		end
		ply:GiveEquipmentItem("item_ttt_nopropdmg")
		--Give mutant the default status
		STATUS:AddStatus(ply, "ttt2_mut1_icon", false)
		ply.damage_taken = 0
	end

	-- Remove Loadout on death and rolechange
	function ROLE:RemoveRoleLoadout(ply, isRoleChange)
		if not GetConVar("ttt2_mut_firedmg"):GetBool() then
			ply:RemoveEquipmentItem("item_ttt_nofiredmg")
		end
		if not GetConVar("ttt2_mut_explosivedmg"):GetBool() then
			ply:RemoveEquipmentItem("item_ttt_noexplosiondmg")
		end
		if not GetConVar("ttt2_mut_falldmg"):GetBool() then
			ply:RemoveEquipmentItem("item_ttt_nofalldmg")
		end
		ply:RemoveEquipmentItem("item_ttt_nopropdmg")
		ply:SetMaxHealth(100)
		ply:RemoveEquipmentItem("item_ttt_radar")
		ply:RemoveItem("item_mut_speed")
		timer.Remove("ttt2_mut_regen_timer")
		STATUS:RemoveStatus(ply, "ttt2_mut1_icon")
		STATUS:RemoveStatus(ply, "ttt2_mut2_icon")
		STATUS:RemoveStatus(ply, "ttt2_mut3_icon")
		STATUS:RemoveStatus(ply, "ttt2_mut4_icon")
		ply.damage_taken = 0
	end
end

--does the math to determine what buffs to give, and what status to give
function computeBuffs(mutant_ply)
	if mutant_ply.damage_taken >= 50 and not mutant_ply:HasEquipmentItem("item_ttt_radar") then
		mutant_ply:GiveEquipmentItem("item_ttt_radar")
		mutant_ply:PrintMessage(HUD_PRINTTALK, "50 Damage Taken! You now have a radar.")
		if mutant_ply.damage_taken <= 74 then
			STATUS:RemoveStatus(mutant_ply, "ttt2_mut1_icon")
			STATUS:AddStatus(mutant_ply, "ttt2_mut2_icon", false)
		end
	end
	if mutant_ply.damage_taken >= 75 and mutant_ply:GetMaxHealth() <= 100 then
		mutant_ply:SetMaxHealth(150)
		mutant_ply:PrintMessage(HUD_PRINTTALK, "75 Damage Taken! You now have 150 max health")
		if mutant_ply.damage_taken <= 99 then
			STATUS:RemoveStatus(mutant_ply, "ttt2_mut1_icon")
			STATUS:RemoveStatus(mutant_ply, "ttt2_mut2_icon")
			STATUS:AddStatus(mutant_ply, "ttt2_mut3_icon", false)
		end
	end
	if mutant_ply.damage_taken >= 100 and not mutant_ply:HasEquipmentItem("item_mut_speed") then
		mutant_ply:GiveItem("item_mut_speed")
		mutant_ply:PrintMessage(HUD_PRINTTALK, "100 Damage Taken! You are faster.")
		STATUS:RemoveStatus(mutant_ply, "ttt2_mut1_icon")
		STATUS:RemoveStatus(mutant_ply, "ttt2_mut2_icon")
		STATUS:RemoveStatus(mutant_ply, "ttt2_mut3_icon")
		STATUS:AddStatus(mutant_ply, "ttt2_mut4_icon", false)
	end
	--for every 10 dmg the mutant takes after taking 100 damage, increase its health by 1
	if mutant_ply:HasEquipmentItem("item_mut_speed") then
		if(mutant_ply.damage_taken - 100) / 10 >= 1 then 
			local computeNewHealth = math.floor(150 + (mutant_ply.damage_taken - 100) / 10)
			mutant_ply:PrintMessage(HUD_PRINTTALK, "Max Health increased by " .. (computeNewHealth - mutant_ply:GetMaxHealth()))
			mutant_ply:SetMaxHealth(computeNewHealth)
		end
	end
end

--calls this hook when someone takes damage
--if the player that took damage is the mutant, only add damage to that player, then run the compute buffs function
hook.Add("EntityTakeDamage", "ttt2_mut_damage_taken", function(target,dmginfo)
	if not IsValid(target) or not target:IsPlayer() then return end
	if target:GetSubRole() ~= ROLE_MUTANT then return end
	local dmgtaken =  dmginfo:GetDamage()
	--End function if damage is fire/explosive/fall with cvar
	if not GetConVar("ttt2_mut_firedmg"):GetBool() and dmginfo:IsDamageType( 8 ) then return end
	if not GetConVar("ttt2_mut_explosivedmg"):GetBool() and dmginfo:IsDamageType( 64 ) then return end
	if not GetConVar("ttt2_mut_falldmg"):GetBool() and dmginfo:IsDamageType( 32 ) then return end
	if dmginfo:IsDamageType( 1 ) then return end
	--round float to nearest integer
	dmgtaken = math.floor(dmgtaken + 0.5)
	target.damage_taken = target.damage_taken + dmgtaken
	target:PrintMessage(HUD_PRINTTALK, "Total Dmg: " .. target.damage_taken)
	computeBuffs(target)
	--no healing for 5 seconds after taking damage
	heal_time = (CurTime() + 5)
end)

if CLIENT then
	hook.Add("TTTBeginRound", "MutantBeginRound", function()
		local client = LocalPlayer()
		if client:GetSubRole() ~= ROLE_MUTANT then return end
		if not IsValid(client) or not client:IsPlayer() then return end
		client.damage_taken = 0
	end)
	hook.Add("TTTEndRound", "MutantEndRound", function()
		local client = LocalPlayer()
		if client:GetSubRole() ~= ROLE_MUTANT then return end
		if not IsValid(client) or not client:IsPlayer() then return end
		client.damage_taken = 0
	end)
end

-- -- -- -- --
-- STATUSES -- 
-- -- -- -- --
if CLIENT then
	hook.Add("Initialize", "ttt2_mut_init", function()
		
		STATUS:RegisterStatus("ttt2_mut1_icon", {
			hud = Material("vgui/ttt/icons/icon_mut1.png"),
			type = "good",
			name = "Mutant",
			sidebarDescription = "status_mut1_icon"
		})
		
		STATUS:RegisterStatus("ttt2_mut2_icon", {
			hud = Material("vgui/ttt/icons/icon_mut2.png"),
			type = "good",
			name = "Mutant",
			sidebarDescription = "status_mut2_icon"
		})
		
		STATUS:RegisterStatus("ttt2_mut3_icon", {
			hud = Material("vgui/ttt/icons/icon_mut3.png"),
			type = "good",
			name = "Mutant",
			sidebarDescription = "status_mut3_icon"
		})
		
		STATUS:RegisterStatus("ttt2_mut4_icon", {
			hud = Material("vgui/ttt/icons/icon_mut4.png"),
			type = "good",
			name = "Mutant",
			sidebarDescription = "status_mut4_icon"
		})
		
	end)
end

-- -- -- -- -
-- CONVARS --
-- -- -- -- -
CreateConVar("ttt2_mut_healing_interval", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY})
CreateConVar("ttt2_mut_healing_amount", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY})
CreateConVar("ttt2_mut_speed_multiplier", "1.2", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
CreateConVar("ttt2_mut_firedmg", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY})
CreateConVar("ttt2_mut_explosivedmg", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY})
CreateConVar("ttt2_mut_falldmg", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY})

--Adds convars to the F1 menu
if CLIENT then
  function ROLE:AddToSettingsMenu(parent)
    local form = vgui.CreateTTT2Form(parent, "header_roles_additional")
	
    form:MakeSlider({
      serverConvar = "ttt2_mut_healing_interval",
      label = "label_mut_healing_interval",
      min = 1,
      max = 10,
      decimal = 0
	})
	
	form:MakeSlider({
      serverConvar = "ttt2_mut_healing_amount",
      label = "label_mut_healing_amount",
      min = 1,
      max = 10,
      decimal = 0
	})
	
	form:MakeSlider({
      serverConvar = "ttt2_mut_speed_multiplier",
      label = "label_mut_speed_multiplier",
      min = 1.0,
      max = 2.0,
      decimal = 2
	})
	
	form:MakeCheckBox({
      serverConvar = "ttt2_mut_firedmg",
      label = "label_mut_firedmg"
    })
	
	form:MakeCheckBox({
      serverConvar = "ttt2_mut_explosivedmg",
      label = "label_mut_explosivedmg"
    })
	
	form:MakeCheckBox({
      serverConvar = "ttt2_mut_falldmg",
      label = "label_mut_falldmg"
    })
	
  end
end
