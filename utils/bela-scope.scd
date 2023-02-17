//Display scope for bubblebass buses

var win, scope, buses, popup;

buses = (spkr: Bus(), direct: Bus(\audio, 2, 4), main: { ~audioBus.main });

~ctlBus.keysValuesDo({ |k, item|
	if (item.isArray) {
		item.do { |bus, i|
			buses["% %".format(k, i + 1).asSymbol] = bus;
		}
	} {
		buses[k] = item;
	}
});



win = Window.new.front.layout_(VLayout(
	popup = PopUpMenu().items_(buses.keys.asArray.sort).action_({ |v|
		var bus = buses[v.item].value;
		scope.free;
		BelaScope.monitorBus(0, bus.index, 1, rate: \control);
	})
));

win.onClose = { scope.free };

popup.valueAction = 0;