//Display scope for bubblebass buses

var win, scope, scopeView, buses, popup;

buses = ();

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
		var bus = buses[v.item];
		//if bus.isKindOf(
		scope.bus = bus;
	}),
	scopeView = View(nil, Rect(0, 0, 100, 100)),
));

scope = Stethoscope(s, view: scopeView).size_(100);
popup.valueAction = 0;