local isPaused, isDead, pickups = false, false, {}

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if NetworkIsPlayerActive(PlayerId()) then
			TriggerServerEvent('myx:onPlayerJoined')
			break
		end
	end
end)

RegisterNetEvent('myx:playerLoaded')
AddEventHandler('myx:playerLoaded', function(playerData)
	MYX.PlayerLoaded = true
	MYX.PlayerData = playerData

	-- check if player is coming from loading screen
	if GetEntityModel(PlayerPedId()) == GetHashKey('PLAYER_ZERO') then
		local defaultModel = GetHashKey('a_m_y_stbla_02')
		RequestModel(defaultModel)

		while not HasModelLoaded(defaultModel) do
			Citizen.Wait(10)
		end

		SetPlayerModel(PlayerId(), defaultModel)
		SetPedDefaultComponentVariation(PlayerPedId())
		SetPedRandomComponentVariation(PlayerPedId(), true)
		SetModelAsNoLongerNeeded(defaultModel)
	end

	-- freeze the player
	FreezeEntityPosition(PlayerPedId(), true)

	-- enable PVP
	SetCanAttackFriendly(PlayerPedId(), true, false)
	NetworkSetFriendlyFireOption(true)

	-- disable wanted level
	ClearPlayerWantedLevel(PlayerId())
	SetMaxWantedLevel(0)

	if Config.EnableHud then
		for k,v in ipairs(playerData.accounts) do
			local accountTpl = '<div><img src="img/accounts/' .. v.name .. '.png"/>&nbsp;{{money}}</div>'
			MYX.UI.HUD.RegisterElement('account_' .. v.name, k, 0, accountTpl, {money = MYX.Math.GroupDigits(v.money)})
		end

		local jobTpl = '<div>{{job_label}} - {{grade_label}}</div>'

		if playerData.job.grade_label == '' or playerData.job.grade_label == playerData.job.label then
			jobTpl = '<div>{{job_label}}</div>'
		end

		MYX.UI.HUD.RegisterElement('job', #playerData.accounts, 0, jobTpl, {
			job_label = playerData.job.label,
			grade_label = playerData.job.grade_label
		})
	end
	Wait(1000)
	SetEntityCoords(GetPlayerPed(-1), playerData.coords.x, playerData.coords.y, playerData.coords.z)
	TriggerServerEvent('myx:onPlayerSpawn')
	TriggerEvent('myx:onPlayerSpawn')
	TriggerEvent('playerSpawned') -- compatibility with old scripts, will be removed soon
	TriggerEvent('myx:restoreLoadout')

	Citizen.Wait(4000)
	ShutdownLoadingScreen()
	ShutdownLoadingScreenNui()
	FreezeEntityPosition(PlayerPedId(), false)
	DoScreenFadeIn(10000)
	StartServerSyncLoops()

	TriggerEvent('myx:loadingScreenOff')
end)

RegisterNetEvent('myx:setMaxWeight')
AddEventHandler('myx:setMaxWeight', function(newMaxWeight) MYX.PlayerData.maxWeight = newMaxWeight end)

AddEventHandler('myx:onPlayerSpawn', function() isDead = false end)
AddEventHandler('myx:onPlayerDeath', function() isDead = true end)

AddEventHandler('skinchanger:modelLoaded', function()
	while not MYX.PlayerLoaded do
		Citizen.Wait(100)
	end

	TriggerEvent('myx:restoreLoadout')
end)

AddEventHandler('myx:restoreLoadout', function()
	local playerPed = PlayerPedId()
	local ammoTypes = {}
	RemoveAllPedWeapons(playerPed, true)

	for k,v in ipairs(MYX.PlayerData.loadout) do
		local weaponName = v.name
		local weaponHash = GetHashKey(weaponName)

		GiveWeaponToPed(playerPed, weaponHash, 0, false, false)
		SetPedWeaponTintIndex(playerPed, weaponHash, v.tintIndex)

		local ammoType = GetPedAmmoTypeFromWeapon(playerPed, weaponHash)

		for k2,v2 in ipairs(v.components) do
			local componentHash = MYX.GetWeaponComponent(weaponName, v2).hash
			GiveWeaponComponentToPed(playerPed, weaponHash, componentHash)
		end

		if not ammoTypes[ammoType] then
			AddAmmoToPed(playerPed, weaponHash, v.ammo)
			ammoTypes[ammoType] = true
		end
	end
end)

RegisterNetEvent('myx:setAccountMoney')
AddEventHandler('myx:setAccountMoney', function(account)
	for k,v in ipairs(MYX.PlayerData.accounts) do
		if v.name == account.name then
			MYX.PlayerData.accounts[k] = account
			break
		end
	end

	if Config.EnableHud then
		MYX.UI.HUD.UpdateElement('account_' .. account.name, {
			money = MYX.Math.GroupDigits(account.money)
		})
	end
end)

RegisterNetEvent('myx:addInventoryItem')
AddEventHandler('myx:addInventoryItem', function(item, count, showNotification)
	for k,v in ipairs(MYX.PlayerData.inventory) do
		if v.name == item then
			MYX.UI.ShowInventoryItemNotification(true, v.label, count - v.count)
			MYX.PlayerData.inventory[k].count = count
			break
		end
	end

	if showNotification then
		MYX.UI.ShowInventoryItemNotification(true, item, count)
	end

	if MYX.UI.Menu.IsOpen('default', 'es_extended', 'inventory') then
		MYX.ShowInventory()
	end
end)

RegisterNetEvent('myx:removeInventoryItem')
AddEventHandler('myx:removeInventoryItem', function(item, count, showNotification)
	for k,v in ipairs(MYX.PlayerData.inventory) do
		if v.name == item then
			MYX.UI.ShowInventoryItemNotification(false, v.label, v.count - count)
			MYX.PlayerData.inventory[k].count = count
			break
		end
	end

	if showNotification then
		MYX.UI.ShowInventoryItemNotification(false, item, count)
	end

	if MYX.UI.Menu.IsOpen('default', 'es_extended', 'inventory') then
		MYX.ShowInventory()
	end
end)

RegisterNetEvent('myx:setJob')
AddEventHandler('myx:setJob', function(job)
	MYX.PlayerData.job = job
end)

RegisterNetEvent('myx:addWeapon')
AddEventHandler('myx:addWeapon', function(weaponName, ammo)
	local playerPed = PlayerPedId()
	local weaponHash = GetHashKey(weaponName)

	GiveWeaponToPed(playerPed, weaponHash, ammo, false, false)
end)

RegisterNetEvent('myx:addWeaponComponent')
AddEventHandler('myx:addWeaponComponent', function(weaponName, weaponComponent)
	local playerPed = PlayerPedId()
	local weaponHash = GetHashKey(weaponName)
	local componentHash = MYX.GetWeaponComponent(weaponName, weaponComponent).hash

	GiveWeaponComponentToPed(playerPed, weaponHash, componentHash)
end)

RegisterNetEvent('myx:setWeaponAmmo')
AddEventHandler('myx:setWeaponAmmo', function(weaponName, weaponAmmo)
	local playerPed = PlayerPedId()
	local weaponHash = GetHashKey(weaponName)

	SetPedAmmo(playerPed, weaponHash, weaponAmmo)
end)

RegisterNetEvent('myx:setWeaponTint')
AddEventHandler('myx:setWeaponTint', function(weaponName, weaponTintIndex)
	local playerPed = PlayerPedId()
	local weaponHash = GetHashKey(weaponName)

	SetPedWeaponTintIndex(playerPed, weaponHash, weaponTintIndex)
end)

RegisterNetEvent('myx:removeWeapon')
AddEventHandler('myx:removeWeapon', function(weaponName)
	local playerPed = PlayerPedId()
	local weaponHash = GetHashKey(weaponName)

	RemoveWeaponFromPed(playerPed, weaponHash)
	SetPedAmmo(playerPed, weaponHash, 0) -- remove leftover ammo
end)

RegisterNetEvent('myx:removeWeaponComponent')
AddEventHandler('myx:removeWeaponComponent', function(weaponName, weaponComponent)
	local playerPed = PlayerPedId()
	local weaponHash = GetHashKey(weaponName)
	local componentHash = MYX.GetWeaponComponent(weaponName, weaponComponent).hash

	RemoveWeaponComponentFromPed(playerPed, weaponHash, componentHash)
end)

RegisterNetEvent('myx:teleport')
AddEventHandler('myx:teleport', function(coords)
	local playerPed = PlayerPedId()

	-- ensure decmial number
	coords.x = coords.x + 0.0
	coords.y = coords.y + 0.0
	coords.z = coords.z + 0.0

	MYX.Game.Teleport(playerPed, coords)
end)

RegisterNetEvent('myx:setJob')
AddEventHandler('myx:setJob', function(job)
	if Config.EnableHud then
		MYX.UI.HUD.UpdateElement('job', {
			job_label = job.label,
			grade_label = job.grade_label
		})
	end
end)

RegisterNetEvent('myx:spawnVehicle')
AddEventHandler('myx:spawnVehicle', function(vehicleName)
	local model = (type(vehicleName) == 'number' and vehicleName or GetHashKey(vehicleName))

	if IsModelInCdimage(model) then
		local playerPed = PlayerPedId()
		local playerCoords, playerHeading = GetEntityCoords(playerPed), GetEntityHeading(playerPed)

		MYX.Game.SpawnVehicle(model, playerCoords, playerHeading, function(vehicle)
			TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
		end)
	else
		TriggerEvent('chat:addMessage', {args = {'^1SYSTEM', 'Invalid vehicle model.'}})
	end
end)

RegisterNetEvent('myx:createPickup')
AddEventHandler('myx:createPickup', function(pickupId, label, coords, type, name, components, tintIndex)
	local function setObjectProperties(object)
		SetEntityAsMissionEntity(object, true, false)
		PlaceObjectOnGroundProperly(object)
		FreezeEntityPosition(object, true)
		SetEntityCollision(object, false, true)

		pickups[pickupId] = {
			obj = object,
			label = label,
			inRange = false,
			coords = vector3(coords.x, coords.y, coords.z)
		}
	end

	if type == 'item_weapon' then
		local weaponHash = GetHashKey(name)
		MYX.Streaming.RequestWeaponAsset(weaponHash)
		local pickupObject = CreateWeaponObject(weaponHash, 50, coords.x, coords.y, coords.z, true, 1.0, 0)
		SetWeaponObjectTintIndex(pickupObject, tintIndex)

		for k,v in ipairs(components) do
			local component = MYX.GetWeaponComponent(name, v)
			GiveWeaponComponentToWeaponObject(pickupObject, component.hash)
		end

		setObjectProperties(pickupObject)
	else
		MYX.Game.SpawnLocalObject('prop_money_bag_01', coords, setObjectProperties)
	end
end)

RegisterNetEvent('myx:createMissingPickups')
AddEventHandler('myx:createMissingPickups', function(missingPickups)
	for pickupId,pickup in pairs(missingPickups) do
		TriggerEvent('myx:createPickup', pickupId, pickup.label, pickup.coords, pickup.type, pickup.name, pickup.components, pickup.tintIndex)
	end
end)

RegisterNetEvent('myx:registerSuggestions')
AddEventHandler('myx:registerSuggestions', function(registeredCommands)
	for name,command in pairs(registeredCommands) do
		if command.suggestion then
			TriggerEvent('chat:addSuggestion', ('/%s'):format(name), command.suggestion.help, command.suggestion.arguments)
		end
	end
end)

RegisterNetEvent('myx:removePickup')
AddEventHandler('myx:removePickup', function(pickupId)
	if pickups[pickupId] and pickups[pickupId].obj then
		MYX.Game.DeleteObject(pickups[pickupId].obj)
		pickups[pickupId] = nil
	end
end)

RegisterNetEvent('myx:deleteVehicle')
AddEventHandler('myx:deleteVehicle', function(radius)
	local playerPed = PlayerPedId()

	if radius and tonumber(radius) then
		radius = tonumber(radius) + 0.01
		local vehicles = MYX.Game.GetVehiclesInArea(GetEntityCoords(playerPed), radius)

		for k,entity in ipairs(vehicles) do
			local attempt = 0

			while not NetworkHasControlOfEntity(entity) and attempt < 100 and DoesEntityExist(entity) do
				Citizen.Wait(100)
				NetworkRequestControlOfEntity(entity)
				attempt = attempt + 1
			end

			if DoesEntityExist(entity) and NetworkHasControlOfEntity(entity) then
				MYX.Game.DeleteVehicle(entity)
			end
		end
	else
		local vehicle, attempt = MYX.Game.GetVehicleInDirection(), 0

		if IsPedInAnyVehicle(playerPed, true) then
			vehicle = GetVehiclePedIsIn(playerPed, false)
		end

		while not NetworkHasControlOfEntity(vehicle) and attempt < 100 and DoesEntityExist(vehicle) do
			Citizen.Wait(100)
			NetworkRequestControlOfEntity(vehicle)
			attempt = attempt + 1
		end

		if DoesEntityExist(vehicle) and NetworkHasControlOfEntity(vehicle) then
			MYX.Game.DeleteVehicle(vehicle)
		end
	end
end)

-- Pause menu disables HUD display
if Config.EnableHud then
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(300)

			if IsPauseMenuActive() and not isPaused then
				isPaused = true
				MYX.UI.HUD.SetDisplay(0.0)
			elseif not IsPauseMenuActive() and isPaused then
				isPaused = false
				MYX.UI.HUD.SetDisplay(1.0)
			end
		end
	end)

	AddEventHandler('myx:loadingScreenOff', function()
		MYX.UI.HUD.SetDisplay(1.0)
	end)
end

function StartServerSyncLoops()
	-- keep track of ammo
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(0)

			if isDead then
				Citizen.Wait(500)
			else
				local playerPed = PlayerPedId()

				if IsPedShooting(playerPed) then
					local _,weaponHash = GetCurrentPedWeapon(playerPed, true)
					local weapon = MYX.GetWeaponFromHash(weaponHash)

					if weapon then
						local ammoCount = GetAmmoInPedWeapon(playerPed, weaponHash)
						TriggerServerEvent('myx:updateWeaponAmmo', weapon.name, ammoCount)
					end
				end
			end
		end
	end)

	-- sync current player coords with server
	Citizen.CreateThread(function()
		local previousCoords = vector3(MYX.PlayerData.coords.x, MYX.PlayerData.coords.y, MYX.PlayerData.coords.z)

		while true do
			Citizen.Wait(1000)
			local playerPed = PlayerPedId()

			if DoesEntityExist(playerPed) then
				local playerCoords = GetEntityCoords(playerPed)
				local distance = #(playerCoords - previousCoords)

				if distance > 1 then
					previousCoords = playerCoords
					local playerHeading = MYX.Math.Round(GetEntityHeading(playerPed), 1)
					local formattedCoords = {x = MYX.Math.Round(playerCoords.x, 1), y = MYX.Math.Round(playerCoords.y, 1), z = MYX.Math.Round(playerCoords.z, 1), heading = playerHeading}
					TriggerServerEvent('myx:updateCoords', formattedCoords)
				end
			end
		end
	end)
end

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if IsControlJustReleased(0, 289) then
			if IsInputDisabled(0) and not isDead and not MYX.UI.Menu.IsOpen('default', 'es_extended', 'inventory') then
				MYX.ShowInventory()
			end
		end
	end
end)

-- Pickups
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		local playerPed = PlayerPedId()
		local playerCoords, letSleep = GetEntityCoords(playerPed), true
		local closestPlayer, closestDistance = MYX.Game.GetClosestPlayer(playerCoords)

		for pickupId,pickup in pairs(pickups) do
			local distance = #(playerCoords - pickup.coords)

			if distance < 5 then
				local label = pickup.label
				letSleep = false

				if distance < 1 then
					if IsControlJustReleased(0, 38) then
						if IsPedOnFoot(playerPed) and (closestDistance == -1 or closestDistance > 3) and not pickup.inRange then
							pickup.inRange = true

							local dict, anim = 'weapons@first_person@aim_rng@generic@projectile@sticky_bomb@', 'plant_floor'
							MYX.Streaming.RequestAnimDict(dict)
							TaskPlayAnim(playerPed, dict, anim, 8.0, 1.0, 1000, 16, 0.0, false, false, false)
							Citizen.Wait(1000)

							TriggerServerEvent('myx:onPickup', pickupId)
							PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
						end
					end

					label = ('%s~n~%s'):format(label, _U('threw_pickup_prompt'))
				end

				MYX.Game.Utils.DrawText3D({
					x = pickup.coords.x,
					y = pickup.coords.y,
					z = pickup.coords.z + 0.25
				}, label, 1.2, 1)
			elseif pickup.inRange then
				pickup.inRange = false
			end
		end

		if letSleep then
			Citizen.Wait(500)
		end
	end
end)
