ITEM.Name = 'Santa Hat'
ITEM.Price = 1000
ITEM.Model = 'models/santa/santa.mdl'
ITEM.Attachment = 'eyes'

function ITEM:OnEquip(ply, modifications)
	ply:PS_AddClientsideModel(self.ID)
end

function ITEM:OnHolster(ply)
	ply:PS_RemoveClientsideModel(self.ID)
end

function ITEM:ModifyClientsideModel(ply, model, pos, ang)
	pos = pos + (ang:Forward() * -5)
	pos = pos + (ang:Up() * -2)
	
	return model, pos, ang
end

function ITEM:CanPlayerBuy(ply)
	return os.date("%m") == "12" and true or false, 'It\'s not winter!'
end

-- Credit for santa hat model to Shane at http://www.facepunch.com/showthread.php?t=860165
