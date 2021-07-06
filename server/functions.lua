MYX.Trace = function(msg)
	if Config.EnableDebug then
		print(('[es_extended] [^2TRACE^7] %s^7'):format(msg))
	end
end

MYX.SetTimeout = function(msec, cb)
	local id = MYX.TimeoutCount + 1

	SetTimeout(msec, function()
		if MYX.CancelledTimeouts[id] then
			MYX.CancelledTimeouts[id] = nil
		else
			cb()
		end
	end)

	MYX.TimeoutCount = id

	return id
end

MYX.RegisterCommand = function(name, group, cb, allowConsole, suggestion)
	if type(name) == 'table' then
		for k,v in ipairs(name) do
			MYX.RegisterCommand(v, group, cb, allowConsole, suggestion)
		end

		return
	end

	if MYX.RegisteredCommands[name] then
		print(('[es_extended] [^3WARNING^7] An command "%s" is already registered, overriding command'):format(name))

		if MYX.RegisteredCommands[name].suggestion then
			TriggerClientEvent('chat:removeSuggestion', -1, ('/%s'):format(name))
		end
	end

	if suggestion then
		if not suggestion.arguments then suggestion.arguments = {} end
		if not suggestion.help then suggestion.help = '' end

		TriggerClientEvent('chat:addSuggestion', -1, ('/%s'):format(name), suggestion.help, suggestion.arguments)
	end

	MYX.RegisteredCommands[name] = {group = group, cb = cb, allowConsole = allowConsole, suggestion = suggestion}

	RegisterCommand(name, function(playerId, args, rawCommand)
		local command = MYX.RegisteredCommands[name]

		if not command.allowConsole and playerId == 0 then
			print(('[es_extended] [^3WARNING^7] %s'):format(_U('commanderror_console')))
		else
			local xPlayer, error = MYX.GetPlayerFromId(playerId), nil

			if command.suggestion then
				if command.suggestion.validate then
					if #args ~= #command.suggestion.arguments then
						error = _U('commanderror_argumentmismatch', #args, #command.suggestion.arguments)
					end
				end

				if not error and command.suggestion.arguments then
					local newArgs = {}

					for k,v in ipairs(command.suggestion.arguments) do
						if v.type then
							if v.type == 'number' then
								local newArg = tonumber(args[k])

								if newArg then
									newArgs[v.name] = newArg
								else
									error = _U('commanderror_argumentmismatch_number', k)
								end
							elseif v.type == 'player' or v.type == 'playerId' then
								local targetPlayer = tonumber(args[k])

								if args[k] == 'me' then targetPlayer = playerId end

								if targetPlayer then
									local xTargetPlayer = MYX.GetPlayerFromId(targetPlayer)

									if xTargetPlayer then
										if v.type == 'player' then
											newArgs[v.name] = xTargetPlayer
										else
											newArgs[v.name] = targetPlayer
										end
									else
										error = _U('commanderror_invalidplayerid')
									end
								else
									error = _U('commanderror_argumentmismatch_number', k)
								end
							elseif v.type == 'string' then
								newArgs[v.name] = args[k]
							elseif v.type == 'item' then
								if MYX.Items[args[k]] then
									newArgs[v.name] = args[k]
								else
									error = _U('commanderror_invaliditem')
								end
							elseif v.type == 'weapon' then
								if MYX.GetWeapon(args[k]) then
									newArgs[v.name] = string.upper(args[k])
								else
									error = _U('commanderror_invalidweapon')
								end
							elseif v.type == 'any' then
								newArgs[v.name] = args[k]
							end
						end

						if error then break end
					end

					args = newArgs
				end
			end

			if error then
				if playerId == 0 then
					print(('[es_extended] [^3WARNING^7] %s^7'):format(error))
				else
					xPlayer.triggerEvent('chat:addMessage', {args = {'^1SYSTEM', error}})
				end
			else
				cb(xPlayer or false, args, function(msg)
					if playerId == 0 then
						print(('[es_extended] [^3WARNING^7] %s^7'):format(msg))
					else
						xPlayer.triggerEvent('chat:addMessage', {args = {'^1SYSTEM', msg}})
					end
				end)
			end
		end
	end, true)

	if type(group) == 'table' then
		for k,v in ipairs(group) do
			ExecuteCommand(('add_ace group.%s command.%s allow'):format(v, name))
		end
	else
		ExecuteCommand(('add_ace group.%s command.%s allow'):format(group, name))
	end
end

MYX.ClearTimeout = function(id)
	MYX.CancelledTimeouts[id] = true
end

MYX.RegisterServerCallback = function(name, cb)
	MYX.ServerCallbacks[name] = cb
end

MYX.TriggerServerCallback = function(name, requestId, source, cb, ...)
	if MYX.ServerCallbacks[name] then
		MYX.ServerCallbacks[name](source, cb, ...)
	else
		print(('[es_extended] [^3WARNING^7] Server callback "%s" does not exist. Make sure that the server sided file really is loading, an error in that file might cause it to not load.'):format(name))
	end
end

MYX.SavePlayer = function(xPlayer, cb)
	local asyncTasks = {}

	table.insert(asyncTasks, function(cb2)
		MySQL.Async.execute('UPDATE users SET accounts = @accounts, job = @job, job_grade = @job_grade, `group` = @group, loadout = @loadout, position = @position, inventory = @inventory WHERE identifier = @identifier', {
			['@accounts'] = json.encode(xPlayer.getAccounts(true)),
			['@job'] = xPlayer.job.name,
			['@job_grade'] = xPlayer.job.grade,
			['@group'] = xPlayer.getGroup(),
			['@loadout'] = json.encode(xPlayer.getLoadout(true)),
			['@position'] = json.encode(xPlayer.getCoords()),
			['@identifier'] = xPlayer.getIdentifier(),
			['@inventory'] = json.encode(xPlayer.getInventory(true))
		}, function(rowsChanged)
			cb2()
		end)
	end)

	Async.parallel(asyncTasks, function(results)
		print(('[es_extended] [^2INFO^7] Saved player "%s^7"'):format(xPlayer.getName()))

		if cb then
			cb()
		end
	end)
end

MYX.SavePlayers = function(cb)
	local xPlayers, asyncTasks = MYX.GetPlayers(), {}

	for i=1, #xPlayers, 1 do
		table.insert(asyncTasks, function(cb2)
			local xPlayer = MYX.GetPlayerFromId(xPlayers[i])
			MYX.SavePlayer(xPlayer, cb2)
		end)
	end

	Async.parallelLimit(asyncTasks, 8, function(results)
		print(('[es_extended] [^2INFO^7] Saved %s player(s)'):format(#xPlayers))
		if cb then
			cb()
		end
	end)
end

MYX.StartDBSync = function()
	function saveData()
		MYX.SavePlayers()
		SetTimeout(10 * 60 * 1000, saveData)
	end

	SetTimeout(10 * 60 * 1000, saveData)
end

MYX.GetPlayers = function()
	local sources = {}

	for k,v in pairs(MYX.Players) do
		table.insert(sources, k)
	end

	return sources
end

MYX.GetPlayerFromId = function(source)
	return MYX.Players[tonumber(source)]
end

MYX.GetPlayerFromIdentifier = function(identifier)
	for k,v in pairs(MYX.Players) do
		if v.identifier == identifier then
			return v
		end
	end
end

MYX.RegisterUsableItem = function(item, cb)
	MYX.UsableItemsCallbacks[item] = cb
end

MYX.UseItem = function(source, item)
	MYX.UsableItemsCallbacks[item](source, item)
end

MYX.GetItemLabel = function(item)
	if MYX.Items[item] then
		return MYX.Items[item].label
	end
end

MYX.CreatePickup = function(type, name, count, label, playerId, components, tintIndex)
	local pickupId = (MYX.PickupId == 65635 and 0 or MYX.PickupId + 1)
	local xPlayer = MYX.GetPlayerFromId(playerId)
	local coords = xPlayer.getCoords()

	MYX.Pickups[pickupId] = {
		type = type, name = name,
		count = count, label = label,
		coords = coords
	}

	if type == 'item_weapon' then
		MYX.Pickups[pickupId].components = components
		MYX.Pickups[pickupId].tintIndex = tintIndex
	end

	TriggerClientEvent('myx:createPickup', -1, pickupId, label, coords, type, name, components, tintIndex)
	MYX.PickupId = pickupId
end

MYX.DoesJobExist = function(job, grade)
	grade = tostring(grade)

	if job and grade then
		if MYX.Jobs[job] and MYX.Jobs[job].grades[grade] then
			return true
		end
	end

	return false
end
