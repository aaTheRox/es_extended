AddEventHandler('myx:getSharedObject', function(cb)
	cb(MYX)
end)

function getSharedObject()
	return MYX
end
