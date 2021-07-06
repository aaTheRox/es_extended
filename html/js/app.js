(() => {

	MYX = {};
	MYX.HUDElements = [];

	MYX.setHUDDisplay = function (opacity) {
		$('#hud').css('opacity', opacity);
	};

	MYX.insertHUDElement = function (name, index, priority, html, data) {
		MYX.HUDElements.push({
			name: name,
			index: index,
			priority: priority,
			html: html,
			data: data
		});

		MYX.HUDElements.sort((a, b) => {
			return a.index - b.index || b.priority - a.priority;
		});
	};

	MYX.updateHUDElement = function (name, data) {
		for (let i = 0; i < MYX.HUDElements.length; i++) {
			if (MYX.HUDElements[i].name == name) {
				MYX.HUDElements[i].data = data;
			}
		}

		MYX.refreshHUD();
	};

	MYX.deleteHUDElement = function (name) {
		for (let i = 0; i < MYX.HUDElements.length; i++) {
			if (MYX.HUDElements[i].name == name) {
				MYX.HUDElements.splice(i, 1);
			}
		}

		MYX.refreshHUD();
	};

	MYX.refreshHUD = function () {
		$('#hud').html('');

		for (let i = 0; i < MYX.HUDElements.length; i++) {
			let html = Mustache.render(MYX.HUDElements[i].html, MYX.HUDElements[i].data);
			$('#hud').append(html);
		}
	};

	MYX.inventoryNotification = function (add, label, count) {
		let notif = '';

		if (add) {
			notif += '+';
		} else {
			notif += '-';
		}

		if (count) {
			notif += count + ' ' + label;
		} else {
			notif += ' ' + label;
		}

		let elem = $('<div>' + notif + '</div>');
		$('#inventory_notifications').append(elem);

		$(elem).delay(3000).fadeOut(1000, function () {
			elem.remove();
		});
	};

	window.onData = (data) => {
		switch (data.action) {
			case 'setHUDDisplay': {
				MYX.setHUDDisplay(data.opacity);
				break;
			}

			case 'insertHUDElement': {
				MYX.insertHUDElement(data.name, data.index, data.priority, data.html, data.data);
				break;
			}

			case 'updateHUDElement': {
				MYX.updateHUDElement(data.name, data.data);
				break;
			}

			case 'deleteHUDElement': {
				MYX.deleteHUDElement(data.name);
				break;
			}

			case 'inventoryNotification': {
				MYX.inventoryNotification(data.add, data.item, data.count);
			}
		}
	};

	window.onload = function (e) {
		window.addEventListener('message', (event) => {
			onData(event.data);
		});
	};

})();
