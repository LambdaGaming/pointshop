PS_ITEM_EQUIP = 1
PS_ITEM_HOLSTER = 2
PS_ITEM_MODIFY = 3

local Player = FindMetaTable('Player')

function Player:PS_PlayerSpawn()
	if not self:PS_CanPerformAction() then return end

	-- TTT ( and others ) Fix
	if TEAM_SPECTATOR != nil and self:Team() == TEAM_SPECTATOR then return end
	if TEAM_SPEC != nil and self:Team() == TEAM_SPEC then return end

	-- Murder Spectator Fix (they don't specify the above enums when making teams)
	-- https://github.com/mechanicalmind/murder/blob/master/gamemode/sv_spectate.lua#L15
	if self.Spectating then return end

	timer.Simple(1, function()
		if !IsValid(self) then return end
		for item_id, item in pairs(self.PS_Items) do
			local ITEM = PS.Items[item_id]
			if item.Equipped then
				ITEM:OnEquip(self, item.Modifiers)
			end
		end
	end)
end

function Player:PS_PlayerDeath()
	for item_id, item in pairs(self.PS_Items) do
		if item.Equipped then
			local ITEM = PS.Items[item_id]
			ITEM:OnHolster(self, item.Modifiers)
		end
	end
end

function Player:PS_PlayerInitialSpawn()
	self.PS_Items = {}

	-- Send stuff
	timer.Simple(1, function()
		if !IsValid(self) then return end
		self:PS_LoadData()
		self:PS_SendClientsideModels()
	end)
end

function Player:PS_PlayerDisconnected()
	PS.ClientsideModels[self] = nil
end

function Player:PS_Save()
	PS:SetPlayerData(self, self.PS_Items)
end

function Player:PS_LoadData()
	self.PS_Items = {}

	PS:GetPlayerData(self, function(items)
		self.PS_Items = items
		self:PS_SendItems()
	end)
end

function Player:PS_CanPerformAction(itemname)
	local allowed = true
	local itemexcept = false
	if itemname then itemexcept = PS.Items[itemname].Except end

	if (self.IsSpec and self:IsSpec()) and not itemexcept then allowed = false end
	if not self:Alive() and not itemexcept then allowed = false end

	if not allowed then
		DarkRP.notify( self, 1, 6, "You're not allowed to do that at the moment!" )
	end

	return allowed
end

-- give/take items

function Player:PS_GiveItem(item_id)
	if not PS.Items[item_id] then return false end

	self.PS_Items[item_id] = { Modifiers = {}, Equipped = false }

	PS:GivePlayerItem(self, item_id, self.PS_Items[item_id])

	self:PS_SendItems()

	return true
end

function Player:PS_TakeItem(item_id)
	if not PS.Items[item_id] then return false end
	if not self:PS_HasItem(item_id) then return false end

	self.PS_Items[item_id] = nil

	PS:TakePlayerItem(self, item_id)

	self:PS_SendItems()

	return true
end

-- buy/sell items

function Player:PS_BuyItem(item_id)
	local ITEM = PS.Items[item_id]
	if not ITEM then return false end

	local price = PS.Config.CalculateBuyPrice(self, ITEM)

	if not self:canAfford( price ) then return false end
	if not self:PS_CanPerformAction(item_id) then return end

	if ITEM.AdminOnly and not self:IsAdmin() then
		DarkRP.notify( self, 1, 6, "This item is admin only!" )
		return false
	end

	if ITEM.AllowedUserGroups and #ITEM.AllowedUserGroups > 0 then
		if not table.HasValue(ITEM.AllowedUserGroups, self:PS_GetUsergroup()) then
			DarkRP.notify( self, 1, 6, "You're not in the right group to buy this item!" )
			return false
		end
	end

	local cat_name = ITEM.Category
	local CATEGORY = PS:FindCategoryByName(cat_name)

	if CATEGORY.AllowedUserGroups and #CATEGORY.AllowedUserGroups > 0 then
		if not table.HasValue(CATEGORY.AllowedUserGroups, self:PS_GetUsergroup()) then
			DarkRP.notify( self, 1, 6, "You're not in the right group to buy this item!" )
			return false
		end
	end

	if CATEGORY.CanPlayerSee then
		if not CATEGORY:CanPlayerSee(self) then
			DarkRP.notify( self, 1, 6, "You're not allowed to buy this item!" )
			return false
		end
	end

	if ITEM.CanPlayerBuy then -- should exist but we'll check anyway
		local allowed, message
		if ( type(ITEM.CanPlayerBuy) == "function" ) then
			allowed, message = ITEM:CanPlayerBuy(self)
		elseif ( type(ITEM.CanPlayerBuy) == "boolean" ) then
			allowed = ITEM.CanPlayerBuy
		end

		if not allowed then
			DarkRP.notify( self, 1, 6, message or "You're not allowed to buy this item!" )
			return false
		end
	end

	self:addMoney( -price )
	DarkRP.notify( self, 0, 6, "Bought "..ITEM.Name.." for "..DarkRP.formatMoney( price ) )

	ITEM:OnBuy(self)
	
	hook.Call( "PS_ItemPurchased", nil, self, item_id )

	if ITEM.SingleUse then
		DarkRP.notify( self, 0, 6, "Single use item. You'll have to buy this item again next time!" )
		return
	end

	self:PS_GiveItem(item_id)
	self:PS_EquipItem(item_id)
end

function Player:PS_SellItem(item_id)
	if not PS.Items[item_id] then return false end
	if not self:PS_HasItem(item_id) then return false end

	local ITEM = PS.Items[item_id]

	if ITEM.CanPlayerSell then -- should exist but we'll check anyway
		local allowed, message
		if ( type(ITEM.CanPlayerSell) == "function" ) then
			allowed, message = ITEM:CanPlayerSell(self)
		elseif ( type(ITEM.CanPlayerSell) == "boolean" ) then
			allowed = ITEM.CanPlayerSell
		end

		if not allowed then
			DarkRP.notify( self, 1, 6, message or "You're not allowed to sell this item!" )
			return false
		end
	end

	local price = PS.Config.CalculateSellPrice(self, ITEM)
	self:addMoney( price )

	ITEM:OnHolster(self)
	ITEM:OnSell(self)
	
	hook.Call( "PS_ItemSold", nil, self, item_id )
	DarkRP.notify( self, 1, 6, "Sold "..Item.Name.." for "..DarkRP.formatMoney( price ) )

	return self:PS_TakeItem(item_id)
end

function Player:PS_HasItem(item_id)
	return self.PS_Items[item_id] or false
end

function Player:PS_HasItemEquipped(item_id)
	if not self:PS_HasItem(item_id) then return false end

	return self.PS_Items[item_id].Equipped or false
end

function Player:PS_NumItemsEquippedFromCategory(cat_name)
	local count = 0

	for item_id, item in pairs(self.PS_Items) do
		local ITEM = PS.Items[item_id]
		if ITEM.Category == cat_name and item.Equipped then
			count = count + 1
		end
	end

	return count
end

-- equip/hoster items

function Player:PS_EquipItem(item_id)
	if not PS.Items[item_id] then return false end
	if not self:PS_HasItem(item_id) then return false end
	if not self:PS_CanPerformAction(item_id) then return false end

	local ITEM = PS.Items[item_id]

	if type(ITEM.CanPlayerEquip) == 'function' then
		allowed, message = ITEM:CanPlayerEquip(self)
	elseif type(ITEM.CanPlayerEquip) == 'boolean' then
		allowed = ITEM.CanPlayerEquip
	end

	if not allowed then
		DarkRP.notify( self, 1, 6, message or "You're not allowed to equip this item!" )
		return false
	end

	local cat_name = ITEM.Category
	local CATEGORY = PS:FindCategoryByName(cat_name)

	if CATEGORY and CATEGORY.AllowedEquipped > -1 then
		if self:PS_NumItemsEquippedFromCategory(cat_name) + 1 > CATEGORY.AllowedEquipped then
			DarkRP.notify( self, 1, 6, "Only "..CATEGORY.AllowedEquipped.." item"..( CATEGORY.AllowedEquipped == 1 and '' or 's' ).." can be equipped from this category!" )
			return false
		end
	end

	if PS.Items[item_id].Slot then
		for id, item in pairs(self.PS_Items) do
			if item_id != id and PS.Items[id].Slot and PS.Items[id].Slot == PS.Items[item_id].Slot and self.PS_Items[id].Equipped then
				self:PS_HolsterItem(id)
			end
		end
	end


	if CATEGORY.SharedCategories then
		local ConCatCats = CATEGORY.Name
		for p, c in pairs( CATEGORY.SharedCategories ) do
			if p ~= #CATEGORY.SharedCategories then
				ConCatCats = ConCatCats .. ', ' .. c
			else
				if #CATEGORY.SharedCategories ~= 1 then
					ConCatCats = ConCatCats .. ', and ' .. c
				else
					ConCatCats = ConCatCats .. ' and ' .. c
				end
			end
		end
		local NumEquipped = self.PS_NumItemsEquippedFromCategory
		for id, item in pairs(self.PS_Items) do
			if not self:PS_HasItemEquipped(id) then continue end
			local CatName = PS.Items[id].Category
			local Cat = PS:FindCategoryByName( CatName )
			if not Cat.SharedCategories then continue end
			for _, SharedCategory in pairs( Cat.SharedCategories ) do
				if SharedCategory == CATEGORY.Name then
					if Cat.AllowedEquipped > -1 and CATEGORY.AllowedEquipped > -1 then
						if NumEquipped(self,CatName) + NumEquipped(self,CATEGORY.Name) + 1 > Cat.AllowedEquipped then
							DarkRP.notify( self, 1, 6, "Only "..Cat.AllowedEquipped.." item"..(Cat.AllowedEquipped == 1 and '' or 's').." can be equipped over "..ConCatCats.."!" )
							return false
						end
					end
				end
			end
		end
	end

	self.PS_Items[item_id].Equipped = true
	ITEM:OnEquip(self, self.PS_Items[item_id].Modifiers)
	DarkRP.notify( self, 0, 6, "Equipped "..ITEM.Name )
	hook.Call( "PS_ItemUpdated", nil, self, item_id, PS_ITEM_EQUIP )
	PS:SavePlayerItem(self, item_id, self.PS_Items[item_id])
	self:PS_SendItems()
end

function Player:PS_HolsterItem(item_id)
	if not PS.Items[item_id] then return false end
	if not self:PS_HasItem(item_id) then return false end
	if not self:PS_CanPerformAction(item_id) then return false end

	self.PS_Items[item_id].Equipped = false

	local ITEM = PS.Items[item_id]

	if type(ITEM.CanPlayerHolster) == 'function' then
		allowed, message = ITEM:CanPlayerHolster(self)
	elseif type(ITEM.CanPlayerHolster) == 'boolean' then
		allowed = ITEM.CanPlayerHolster
	end

	if not allowed then
		DarkRP.notify( self, 1, 6, message or "You're not allowed to holster this item!" )
		return false
	end

	ITEM:OnHolster(self)
	DarkRP.notify( self, 0, 6, "Holstered "..ITEM.Name )
	hook.Call( "PS_ItemUpdated", nil, self, item_id, PS_ITEM_HOLSTER )
	PS:SavePlayerItem(self, item_id, self.PS_Items[item_id])
	self:PS_SendItems()
end


local function Sanitize( modifications ) -- used as a default if an item is missing the SanitizeTable function. Catches colors/text
	local out = {}
	if isstring(modifications.text) then out.text = modifications.text end
	if modifications.color then
		out.color = Color(modifications.color.r or 255, modifications.color.g or 255, modifications.color.b or 255)
	end
	return out
end

function Player:PS_ModifyItem(item_id, modifications)
	if not PS.Items[item_id] then return false end
	if not self:PS_HasItem(item_id) then return false end
	if not type(modifications) == "table" then return false end
	if not self:PS_CanPerformAction(item_id) then return false end
	
	local ITEM = PS.Items[item_id]

	-- This if block helps prevent someone from sending a table full of random junk that will fill up the server's RAM, be networked to every player, and be stored in the database
	if ITEM.SanitizeTable then 
		modifications = ITEM:SanitizeTable(modifications)
	else
		modifications = Sanitize(modifications)
	end

	for key, value in pairs(modifications) do
		self.PS_Items[item_id].Modifiers[key] = value
	end

	ITEM:OnModify(self, self.PS_Items[item_id].Modifiers)

	hook.Call( "PS_ItemUpdated", nil, self, item_id, PS_ITEM_MODIFY, modifications )
	
	PS:SavePlayerItem(self, item_id, self.PS_Items[item_id])

	self:PS_SendItems()
end

-- clientside Models

function Player:PS_AddClientsideModel(item_id)
	if not PS.Items[item_id] then return false end
	if not self:PS_HasItem(item_id) then return false end

	net.Start('PS_AddClientsideModel')
		net.WriteEntity(self)
		net.WriteString(item_id)
	net.Broadcast()

	if not PS.ClientsideModels[self] then PS.ClientsideModels[self] = {} end

	PS.ClientsideModels[self][item_id] = item_id
end

function Player:PS_RemoveClientsideModel(item_id)
	if not PS.Items[item_id] then return false end
	if not self:PS_HasItem(item_id) then return false end
	if not PS.ClientsideModels[self] or not PS.ClientsideModels[self][item_id] then return false end

	net.Start('PS_RemoveClientsideModel')
		net.WriteEntity(self)
		net.WriteString(item_id)
	net.Broadcast()

	PS.ClientsideModels[self][item_id] = nil
end

-- menu stuff

function Player:PS_ToggleMenu(show)
	net.Start('PS_ToggleMenu')
	net.Send(self)
end

-- send stuff
function Player:PS_SendItems()
	net.Start('PS_Items')
		net.WriteEntity(self)
		net.WriteTable(self.PS_Items)
	net.Broadcast()
end

function Player:PS_SendClientsideModels()
	net.Start('PS_SendClientsideModels')
		net.WriteTable(PS.ClientsideModels)
	net.Send(self)
end
