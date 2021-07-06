Citizen.CreateThread(function()
	SetMapName('San Andreas')
	SetGameType('Roleplay')
end)

RegisterNetEvent('myx:onPlayerJoined')
AddEventHandler('myx:onPlayerJoined', function()
	if not MYX.Players[source] then
		onPlayerJoined(source)
	end
end)

function onPlayerJoined(playerId)
	local identifier

	for k,v in ipairs(GetPlayerIdentifiers(playerId)) do
		if string.match(v, 'steam:') then
			identifier = v
			break
		end
	end
	print(identifier)
	if identifier then
		if MYX.GetPlayerFromIdentifier(identifier) then
			DropPlayer(playerId, ('there was an error loading your character!\nError code: identifier-active-ingame\n\nThis error is caused by a player on this server who has the same identifier as you have. Make sure you are not playing on the same Rockstar account.\n\nYour Rockstar identifier: %s'):format(identifier))
		else
			MySQL.Async.fetchScalar('SELECT 1 FROM users WHERE identifier = @identifier', {
				['@identifier'] = identifier
			}, function(result)
				if result then
					loadMYXPlayer(identifier, playerId)
				else
					local accounts = {}

					for account,money in pairs(Config.StartingAccountMoney) do
						accounts[account] = money
					end

					MySQL.Async.execute('INSERT INTO users (accounts, identifier) VALUES (@accounts, @identifier)', {
						['@accounts'] = json.encode(accounts),
						['@identifier'] = identifier
					}, function(rowsChanged)
						loadMYXPlayer(identifier, playerId)
					end)
				end
			end)
		end
	else
		DropPlayer(playerId, 'there was an error loading your character!\nError code: identifier-missing-ingame\n\nThe cause of this error is not known, your identifier could not be found. Please come back later or report this problem to the server administration team.')
	end
end

AddEventHandler('playerConnecting', function(name, setCallback, deferrals)
	deferrals.defer()
	local playerId, identifier = source
	Citizen.Wait(100)

	for k,v in ipairs(GetPlayerIdentifiers(playerId)) do
		if string.match(v, 'license:') then
			identifier = string.sub(v, 9)
			break
		end
	end

	if identifier then
		if MYX.GetPlayerFromIdentifier(identifier) then
			deferrals.done(('There was an error loading your character!\nError code: identifier-active\n\nThis error is caused by a player on this server who has the same identifier as you have. Make sure you are not playing on the same Rockstar account.\n\nYour Rockstar identifier: %s'):format(identifier))
		else
			deferrals.done()
		end
	else
		deferrals.done('There was an error loading your character!\nError code: identifier-missing\n\nThe cause of this error is not known, your identifier could not be found. Please come back later or report this problem to the server administration team.')
	end
end)


function loadMYXPlayer(identifier, playerId)
	local tasks = {}

	local userData = {
		accounts = {},
		inventory = {},
		job = {},
		loadout = {},
		playerName = GetPlayerName(playerId),
		weight = 0
	}

	table.insert(tasks, function(cb)
		MySQL.Async.fetchAll('SELECT accounts, job, job_grade, `group`, loadout, position, inventory FROM users WHERE identifier = @identifier', {
			['@identifier'] = identifier
		}, function(result)
			local job, grade, jobObject, gradeObject = result[1].job, tostring(result[1].job_grade)
			local foundAccounts, foundItems = {}, {}

			-- Accounts
			if result[1].accounts and result[1].accounts ~= '' then
				local accounts = json.decode(result[1].accounts)

				for account,money in pairs(accounts) do
					foundAccounts[account] = money
				end
			end

			for account,label in pairs(Config.Accounts) do
				table.insert(userData.accounts, {
					name = account,
					money = foundAccounts[account] or Config.StartingAccountMoney[account] or 0,
					label = label
				})
			end

			-- Job
			if MYX.DoesJobExist(job, grade) then
				jobObject, gradeObject = MYX.Jobs[job], MYX.Jobs[job].grades[grade]
			else
				print(('[es_extended] [^3WARNING^7] Ignoring invalid job for %s [job: %s, grade: %s]'):format(identifier, job, grade))
				job, grade = 'unemployed', '0'
				jobObject, gradeObject = MYX.Jobs[job], MYX.Jobs[job].grades[grade]
			end

			userData.job.id = jobObject.id
			userData.job.name = jobObject.name
			userData.job.label = jobObject.label

			userData.job.grade = tonumber(grade)
			userData.job.grade_name = gradeObject.name
			userData.job.grade_label = gradeObject.label
			userData.job.grade_salary = gradeObject.salary

			userData.job.skin_male = {}
			userData.job.skin_female = {}

			if gradeObject.skin_male then userData.job.skin_male = json.decode(gradeObject.skin_male) end
			if gradeObject.skin_female then userData.job.skin_female = json.decode(gradeObject.skin_female) end

			-- Inventory
			if result[1].inventory and result[1].inventory ~= '' then
				local inventory = json.decode(result[1].inventory)

				for name,count in pairs(inventory) do
					local item = MYX.Items[name]

					if item then
						foundItems[name] = count
					else
						print(('[es_extended] [^3WARNING^7] Ignoring invalid item "%s" for "%s"'):format(name, identifier))
					end
				end
			end

			for name,item in pairs(MYX.Items) do
				local count = foundItems[name] or 0
				if count > 0 then userData.weight = userData.weight + (item.weight * count) end

				table.insert(userData.inventory, {
					name = name,
					count = count,
					label = item.label,
					weight = item.weight,
					usable = MYX.UsableItemsCallbacks[name] ~= nil,
					rare = item.rare,
					canRemove = item.canRemove
				})
			end

			table.sort(userData.inventory, function(a, b)
				return a.label < b.label
			end)

			-- Group
			if result[1].group then
				userData.group = result[1].group
			else
				userData.group = 'user'
			end

			-- Loadout
			if result[1].loadout and result[1].loadout ~= '' then
				local loadout = json.decode(result[1].loadout)

				for name,weapon in pairs(loadout) do
					local label = MYX.GetWeaponLabel(name)

					if label then
						if not weapon.components then weapon.components = {} end
						if not weapon.tintIndex then weapon.tintIndex = 0 end

						table.insert(userData.loadout, {
							name = name,
							ammo = weapon.ammo,
							label = label,
							components = weapon.components,
							tintIndex = weapon.tintIndex
						})
					end
				end
			end

			-- Position
			if result[1].position and result[1].position ~= '' then
				userData.coords = json.decode(result[1].position)
			else
				print('[es_extended] [^3WARNING^7] Column "position" in "users" table is missing required default value. Using backup coords, fix your database.')
				userData.coords = {x = -269.4, y = -955.3, z = 31.2, heading = 205.8}
			end

			cb()
		end)
	end)

	Async.parallel(tasks, function(results)
		local xPlayer = CreateExtendedPlayer(playerId, identifier, userData.group, userData.accounts, userData.inventory, userData.weight, userData.job, userData.loadout, userData.playerName, userData.coords)
		MYX.Players[playerId] = xPlayer
		TriggerEvent('myx:playerLoaded', playerId, xPlayer)

		xPlayer.triggerEvent('myx:playerLoaded', {
			accounts = xPlayer.getAccounts(),
			coords = xPlayer.getCoords(),
			identifier = xPlayer.getIdentifier(),
			inventory = xPlayer.getInventory(),
			job = xPlayer.getJob(),
			loadout = xPlayer.getLoadout(),
			maxWeight = xPlayer.getMaxWeight(),
			money = xPlayer.getMoney()
		})

		xPlayer.triggerEvent('myx:createMissingPickups', MYX.Pickups)
		xPlayer.triggerEvent('myx:registerSuggestions', MYX.RegisteredCommands)
		print(('[es_extended] [^2INFO^7] A player with name "%s^7" has connected to the server with assigned player id %s'):format(xPlayer.getName(), playerId))
	end)
end

AddEventHandler('chatMessage', function(playerId, author, message)
	if message:sub(1, 1) == '/' and playerId > 0 then
		CancelEvent()
		local commandName = message:sub(1):gmatch("%w+")()
		TriggerClientEvent('chat:addMessage', playerId, {args = {'^1SYSTEM', _U('commanderror_invalidcommand', commandName)}})
	end
end)

AddEventHandler('playerDropped', function(reason)
	local playerId = source
	local xPlayer = MYX.GetPlayerFromId(playerId)

	if xPlayer then
		TriggerEvent('myx:playerDropped', playerId, reason)

		MYX.SavePlayer(xPlayer, function()
			MYX.Players[playerId] = nil
		end)
	end
end)

RegisterNetEvent('myx:updateCoords')
AddEventHandler('myx:updateCoords', function(coords)
	local xPlayer = MYX.GetPlayerFromId(source)

	if xPlayer then
		xPlayer.updateCoords(coords)
	end
end)

RegisterNetEvent('myx:updateWeaponAmmo')
AddEventHandler('myx:updateWeaponAmmo', function(weaponName, ammoCount)
	local xPlayer = MYX.GetPlayerFromId(source)

	if xPlayer then
		xPlayer.updateWeaponAmmo(weaponName, ammoCount)
	end
end)

RegisterNetEvent('myx:giveInventoryItem')
AddEventHandler('myx:giveInventoryItem', function(target, type, itemName, itemCount)
	local playerId = source
	local sourceXPlayer = MYX.GetPlayerFromId(playerId)
	local targetXPlayer = MYX.GetPlayerFromId(target)

	if type == 'item_standard' then
		local sourceItem = sourceXPlayer.getInventoryItem(itemName)

		if itemCount > 0 and sourceItem.count >= itemCount then
			if targetXPlayer.canCarryItem(itemName, itemCount) then
				sourceXPlayer.removeInventoryItem(itemName, itemCount)
				targetXPlayer.addInventoryItem   (itemName, itemCount)

				sourceXPlayer.showNotification(_U('gave_item', itemCount, sourceItem.label, targetXPlayer.name))
				targetXPlayer.showNotification(_U('received_item', itemCount, sourceItem.label, sourceXPlayer.name))
			else
				sourceXPlayer.showNotification(_U('ex_inv_lim', targetXPlayer.name))
			end
		else
			sourceXPlayer.showNotification(_U('imp_invalid_quantity'))
		end
	elseif type == 'item_account' then
		if itemCount > 0 and sourceXPlayer.getAccount(itemName).money >= itemCount then
			sourceXPlayer.removeAccountMoney(itemName, itemCount)
			targetXPlayer.addAccountMoney   (itemName, itemCount)

			sourceXPlayer.showNotification(_U('gave_account_money', MYX.Math.GroupDigits(itemCount), Config.Accounts[itemName], targetXPlayer.name))
			targetXPlayer.showNotification(_U('received_account_money', MYX.Math.GroupDigits(itemCount), Config.Accounts[itemName], sourceXPlayer.name))
		else
			sourceXPlayer.showNotification(_U('imp_invalid_amount'))
		end
	elseif type == 'item_weapon' then
		if sourceXPlayer.hasWeapon(itemName) then
			local weaponLabel = MYX.GetWeaponLabel(itemName)

			if not targetXPlayer.hasWeapon(itemName) then
				local _, weapon = sourceXPlayer.getWeapon(itemName)
				local _, weaponObject = MYX.GetWeapon(itemName)
				itemCount = weapon.ammo

				sourceXPlayer.removeWeapon(itemName)
				targetXPlayer.addWeapon(itemName, itemCount)

				if weaponObject.ammo and itemCount > 0 then
					local ammoLabel = weaponObject.ammo.label
					sourceXPlayer.showNotification(_U('gave_weapon_withammo', weaponLabel, itemCount, ammoLabel, targetXPlayer.name))
					targetXPlayer.showNotification(_U('received_weapon_withammo', weaponLabel, itemCount, ammoLabel, sourceXPlayer.name))
				else
					sourceXPlayer.showNotification(_U('gave_weapon', weaponLabel, targetXPlayer.name))
					targetXPlayer.showNotification(_U('received_weapon', weaponLabel, sourceXPlayer.name))
				end
			else
				sourceXPlayer.showNotification(_U('gave_weapon_hasalready', targetXPlayer.name, weaponLabel))
				targetXPlayer.showNotification(_U('received_weapon_hasalready', sourceXPlayer.name, weaponLabel))
			end
		end
	elseif type == 'item_ammo' then
		if sourceXPlayer.hasWeapon(itemName) then
			local weaponNum, weapon = sourceXPlayer.getWeapon(itemName)

			if targetXPlayer.hasWeapon(itemName) then
				local _, weaponObject = MYX.GetWeapon(itemName)

				if weaponObject.ammo then
					local ammoLabel = weaponObject.ammo.label

					if weapon.ammo >= itemCount then
						sourceXPlayer.removeWeaponAmmo(itemName, itemCount)
						targetXPlayer.addWeaponAmmo(itemName, itemCount)

						sourceXPlayer.showNotification(_U('gave_weapon_ammo', itemCount, ammoLabel, weapon.label, targetXPlayer.name))
						targetXPlayer.showNotification(_U('received_weapon_ammo', itemCount, ammoLabel, weapon.label, sourceXPlayer.name))
					end
				end
			else
				sourceXPlayer.showNotification(_U('gave_weapon_noweapon', targetXPlayer.name))
				targetXPlayer.showNotification(_U('received_weapon_noweapon', sourceXPlayer.name, weapon.label))
			end
		end
	end
end)

RegisterNetEvent('myx:removeInventoryItem')
AddEventHandler('myx:removeInventoryItem', function(type, itemName, itemCount)
	local playerId = source
	local xPlayer = MYX.GetPlayerFromId(source)

	if type == 'item_standard' then
		if itemCount == nil or itemCount < 1 then
			xPlayer.showNotification(_U('imp_invalid_quantity'))
		else
			local xItem = xPlayer.getInventoryItem(itemName)

			if (itemCount > xItem.count or xItem.count < 1) then
				xPlayer.showNotification(_U('imp_invalid_quantity'))
			else
				xPlayer.removeInventoryItem(itemName, itemCount)
				local pickupLabel = ('~y~%s~s~ [~b~%s~s~]'):format(xItem.label, itemCount)
				MYX.CreatePickup('item_standard', itemName, itemCount, pickupLabel, playerId)
				xPlayer.showNotification(_U('threw_standard', itemCount, xItem.label))
			end
		end
	elseif type == 'item_account' then
		if itemCount == nil or itemCount < 1 then
			xPlayer.showNotification(_U('imp_invalid_amount'))
		else
			local account = xPlayer.getAccount(itemName)

			if (itemCount > account.money or account.money < 1) then
				xPlayer.showNotification(_U('imp_invalid_amount'))
			else
				xPlayer.removeAccountMoney(itemName, itemCount)
				local pickupLabel = ('~y~%s~s~ [~g~%s~s~]'):format(account.label, _U('locale_currency', MYX.Math.GroupDigits(itemCount)))
				MYX.CreatePickup('item_account', itemName, itemCount, pickupLabel, playerId)
				xPlayer.showNotification(_U('threw_account', MYX.Math.GroupDigits(itemCount), string.lower(account.label)))
			end
		end
	elseif type == 'item_weapon' then
		itemName = string.upper(itemName)

		if xPlayer.hasWeapon(itemName) then
			local _, weapon = xPlayer.getWeapon(itemName)
			local _, weaponObject = MYX.GetWeapon(itemName)
			local components, pickupLabel = MYX.Table.Clone(weapon.components)
			xPlayer.removeWeapon(itemName)

			if weaponObject.ammo and weapon.ammo > 0 then
				local ammoLabel = weaponObject.ammo.label
				pickupLabel = ('~y~%s~s~ [~g~%s~s~ %s]'):format(weapon.label, weapon.ammo, ammoLabel)
				xPlayer.showNotification(_U('threw_weapon_ammo', weapon.label, weapon.ammo, ammoLabel))
			else
				pickupLabel = ('~y~%s~s~'):format(weapon.label)
				xPlayer.showNotification(_U('threw_weapon', weapon.label))
			end

			MYX.CreatePickup('item_weapon', itemName, weapon.ammo, pickupLabel, playerId, components, weapon.tintIndex)
		end
	end
end)

RegisterNetEvent('myx:useItem')
AddEventHandler('myx:useItem', function(itemName)
	local xPlayer = MYX.GetPlayerFromId(source)
	local count = xPlayer.getInventoryItem(itemName).count

	if count > 0 then
		MYX.UseItem(source, itemName)
	else
		xPlayer.showNotification(_U('act_imp'))
	end
end)

RegisterNetEvent('myx:onPickup')
AddEventHandler('myx:onPickup', function(pickupId)
	local pickup, xPlayer, success = MYX.Pickups[pickupId], MYX.GetPlayerFromId(source)

	if pickup then
		if pickup.type == 'item_standard' then
			if xPlayer.canCarryItem(pickup.name, pickup.count) then
				xPlayer.addInventoryItem(pickup.name, pickup.count)
				success = true
			else
				xPlayer.showNotification(_U('threw_cannot_pickup'))
			end
		elseif pickup.type == 'item_account' then
			success = true
			xPlayer.addAccountMoney(pickup.name, pickup.count)
		elseif pickup.type == 'item_weapon' then
			if xPlayer.hasWeapon(pickup.name) then
				xPlayer.showNotification(_U('threw_weapon_already'))
			else
				success = true
				xPlayer.addWeapon(pickup.name, pickup.count)
				xPlayer.setWeaponTint(pickup.name, pickup.tintIndex)

				for k,v in ipairs(pickup.components) do
					xPlayer.addWeaponComponent(pickup.name, v)
				end
			end
		end

		if success then
			MYX.Pickups[pickupId] = nil
			TriggerClientEvent('myx:removePickup', -1, pickupId)
		end
	end
end)

MYX.RegisterServerCallback('myx:getPlayerData', function(source, cb)
	local xPlayer = MYX.GetPlayerFromId(source)

	cb({
		identifier   = xPlayer.identifier,
		accounts     = xPlayer.getAccounts(),
		inventory    = xPlayer.getInventory(),
		job          = xPlayer.getJob(),
		loadout      = xPlayer.getLoadout(),
		money        = xPlayer.getMoney()
	})
end)

MYX.RegisterServerCallback('myx:getOtherPlayerData', function(source, cb, target)
	local xPlayer = MYX.GetPlayerFromId(target)

	cb({
		identifier   = xPlayer.identifier,
		accounts     = xPlayer.getAccounts(),
		inventory    = xPlayer.getInventory(),
		job          = xPlayer.getJob(),
		loadout      = xPlayer.getLoadout(),
		money        = xPlayer.getMoney()
	})
end)

MYX.RegisterServerCallback('myx:getPlayerNames', function(source, cb, players)
	players[source] = nil

	for playerId,v in pairs(players) do
		local xPlayer = MYX.GetPlayerFromId(playerId)

		if xPlayer then
			players[playerId] = xPlayer.getName()
		else
			players[playerId] = nil
		end
	end

	cb(players)
end)

MYX.StartDBSync()
MYX.StartPayCheck()
