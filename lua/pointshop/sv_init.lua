--[[
	pointshop/sv_init.lua
	first file included serverside.
]]--

include "sh_init.lua"
include "sv_player_extension.lua"
include "sv_manifest.lua"

-- net hooks

net.Receive('PS_BuyItem', function(length, ply)
	ply:PS_BuyItem(net.ReadString())
end)

net.Receive('PS_SellItem', function(length, ply)
	ply:PS_SellItem(net.ReadString())
end)

net.Receive('PS_EquipItem', function(length, ply)
	ply:PS_EquipItem(net.ReadString())
end)

net.Receive('PS_HolsterItem', function(length, ply)
	ply:PS_HolsterItem(net.ReadString())
end)

net.Receive('PS_ModifyItem', function(length, ply)
	ply:PS_ModifyItem(net.ReadString(), net.ReadTable())
end)

-- admin items

net.Receive('PS_GiveItem', function(length, ply)
	local other = net.ReadEntity()
	local item_id = net.ReadString()
	
	if not PS.Config.AdminCanAccessAdminTab and not PS.Config.SuperAdminCanAccessAdminTab then return end
	
	local admin_allowed = PS.Config.AdminCanAccessAdminTab and ply:IsAdmin()
	local super_admin_allowed = PS.Config.SuperAdminCanAccessAdminTab and ply:IsSuperAdmin()
	
	if (admin_allowed or super_admin_allowed) and other and item_id and PS.Items[item_id] and IsValid(other) and other:IsPlayer() and not other:PS_HasItem(item_id) then
		other:PS_GiveItem(item_id)
	end
end)

net.Receive('PS_TakeItem', function(length, ply)
	local other = net.ReadEntity()
	local item_id = net.ReadString()
	
	if not PS.Config.AdminCanAccessAdminTab and not PS.Config.SuperAdminCanAccessAdminTab then return end
	
	local admin_allowed = PS.Config.AdminCanAccessAdminTab and ply:IsAdmin()
	local super_admin_allowed = PS.Config.SuperAdminCanAccessAdminTab and ply:IsSuperAdmin()
	
	if (admin_allowed or super_admin_allowed) and other and item_id and PS.Items[item_id] and IsValid(other) and other:IsPlayer() and other:PS_HasItem(item_id) then
		-- holster it first without notificaiton
		other.PS_Items[item_id].Equipped = false
	
		local ITEM = PS.Items[item_id]
		ITEM:OnHolster(other)
		other:PS_TakeItem(item_id)
	end
end)

-- hooks
hook.Add('PlayerSpawn', 'PS_PlayerSpawn', function(ply) ply:PS_PlayerSpawn() end)
hook.Add('PlayerDeath', 'PS_PlayerDeath', function(ply) ply:PS_PlayerDeath() end)
hook.Add('PlayerInitialSpawn', 'PS_PlayerInitialSpawn', function(ply) ply:PS_PlayerInitialSpawn() end)
hook.Add('PlayerDisconnected', 'PS_PlayerDisconnected', function(ply) ply:PS_PlayerDisconnected() end)

-- ugly networked strings
util.AddNetworkString('PS_Items')
util.AddNetworkString('PS_BuyItem')
util.AddNetworkString('PS_SellItem')
util.AddNetworkString('PS_EquipItem')
util.AddNetworkString('PS_HolsterItem')
util.AddNetworkString('PS_ModifyItem')
util.AddNetworkString('PS_GiveItem')
util.AddNetworkString('PS_TakeItem')
util.AddNetworkString('PS_AddClientsideModel')
util.AddNetworkString('PS_RemoveClientsideModel')
util.AddNetworkString('PS_SendClientsideModels')
util.AddNetworkString('PS_SendNotification')
util.AddNetworkString('PS_ToggleMenu')

-- version checker

PS.CurrentBuild = 0
PS.LatestBuild = 0
PS.BuildOutdated = false

local function CompareVersions()
	if PS.CurrentBuild < PS.LatestBuild then
		MsgN('PointShop is out of date!')
		MsgN('Local version: ' .. PS.CurrentBuild .. ', Latest version: ' .. PS.LatestBuild)

		PS.BuildOutdated = true
	else
		MsgN('PointShop is on the latest version.')
	end
end

function PS:GetPlayerData(ply, callback)
	return callback(util.JSONToTable(ply:GetPData('PS_Items', '{}')))
end

function PS:SetPlayerData(ply, items)
	ply:SetPData('PS_Items', util.TableToJSON(items))
end

function PS:SavePlayerItem(ply, item_id, data)
	self:GivePlayerItem(ply, item_id, data)
end

function PS:GivePlayerItem(ply, item_id, data)
	local tmp = table.Copy(ply.PS_Items)
	tmp[item_id] = data
	ply:SetPData('PS_Items', util.TableToJSON(tmp))
end

function PS:TakePlayerItem(ply, item_id)
	local tmp = util.JSONToTable(ply:GetPData('PS_Items', '{}'))
	tmp[item_id] = nil
	ply:SetPData('PS_Items', util.TableToJSON(tmp))
end
