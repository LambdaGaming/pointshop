PS.Config = {}

-- Edit below
PS.Config.AdminCanAccessAdminTab = true -- Can Admins access the Admin tab?
PS.Config.SuperAdminCanAccessAdminTab = true -- Can SuperAdmins access the Admin tab?
PS.Config.DisplayPreviewInMenu = true -- Can players see the preview of their items in the menu?
PS.Config.SortItemsBy = 'Name' -- How are items sorted? Set to 'Price' to sort by price.

-- Edit below if you know what you're doing
PS.Config.CalculateBuyPrice = function(ply, item)
	-- You can do different calculations here to return how much an item should cost to buy.
	-- There are a few examples below, uncomment them to use them.
	
	-- Everything half price for admins:
	-- if ply:IsAdmin() then return math.Round(item.Price * 0.5) end
	
	-- 25% off for the 'donators' group
	-- if ply:IsUserGroup('donators') then return math.Round(item.Price * 0.75) end
	
	return item.Price
end

PS.Config.CalculateSellPrice = function(ply, item)
	return math.Round(item.Price * 0.75) -- 75% or 3/4 (rounded) of the original item price
end
