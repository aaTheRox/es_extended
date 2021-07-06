MYX = {}
MYX.Players = {}
MYX.UsableItemsCallbacks = {}
MYX.Items = {}
MYX.ServerCallbacks = {}
MYX.TimeoutCount = -1
MYX.CancelledTimeouts = {}
MYX.Pickups = {}
MYX.PickupId = 0
MYX.Jobs = {}
MYX.RegisteredCommands = {}

AddEventHandler('myx:getSharedObject', function(cb)
	cb(MYX)
end)

function getSharedObject()
	return MYX
end

MySQL.ready(function()
	MySQL.Async.fetchAll('SELECT * FROM items', {}, function(result)
		for k,v in ipairs(result) do
			MYX.Items[v.name] = {
				label = v.label,
				weight = v.weight,
				rare = v.rare,
				canRemove = v.can_remove
			}
		end
	end)

	MySQL.Async.fetchAll('SELECT * FROM jobs', {}, function(jobs)
		for k,v in ipairs(jobs) do
			MYX.Jobs[v.name] = v
			MYX.Jobs[v.name].grades = {}
		end

		MySQL.Async.fetchAll('SELECT * FROM job_grades', {}, function(jobGrades)
			for k,v in ipairs(jobGrades) do
				if MYX.Jobs[v.job_name] then
					MYX.Jobs[v.job_name].grades[tostring(v.grade)] = v
				else
					print(('[es_extended] [^3WARNING^7] Ignoring job grades for "%s" due to missing job'):format(v.job_name))
				end
			end

			for k2,v2 in pairs(MYX.Jobs) do
				if MYX.Table.SizeOf(v2.grades) == 0 then
					MYX.Jobs[v2.name] = nil
					print(('[es_extended] [^3WARNING^7] Ignoring job "%s" due to no job grades found'):format(v2.name))
				end
			end
		end)
	end)

	print('[es_extended] [^2INFO^7] MYX developed by MYX-Org has been initialized')
end)

RegisterServerEvent('myx:clientLog')
AddEventHandler('myx:clientLog', function(msg)
	if Config.EnableDebug then
		print(('[es_extended] [^2TRACE^7] %s^7'):format(msg))
	end
end)

RegisterServerEvent('myx:triggerServerCallback')
AddEventHandler('myx:triggerServerCallback', function(name, requestId, ...)
	local playerId = source

	MYX.TriggerServerCallback(name, requestId, playerId, function(...)
		TriggerClientEvent('myx:serverCallback', playerId, requestId, ...)
	end, ...)
end)
