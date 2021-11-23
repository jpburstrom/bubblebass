var path = "".resolveRelative;
var plotter;
var win;
~respawnAll = true;
(path +/+ "main.scd").load;
win = Window().front.layout_(VLayout(
	HLayout(
		Button().states_([["Soft reload"]]).action_({
			~respawnAll = false;
			(path +/+ "main.scd").load;
		}),
		Button().states_([["Hard reload"]]).action_({
			~respawnAll = true;
			(path +/+ "main.scd").load;
		}),
		Button().states_([["Re-init server"]]).action_({
			Server.default.freeAll.initTree.notify_(true).startAliveThread;
		}),
	),
	StaticText().string_("IMU"),
	HLayout(
		Button().states_([["Calibrate"]]).action_({
			~synths[\imuInput].set(\calibrate, 1)

		}),
		Button().states_([["Load"]]).action_({
			~synths[\imuInput].set(\load, 1)

		}),
		Button().states_([["Save"]]).action_({
			~synths[\imuInput].set(\save, 1)

		})
	),

	"utils/bela-bus-sliders.scd".loadRelative,
	plotter = ScrollView().minHeight_(300)
));
win.view.fixedWidth_(300);
win.setInnerExtent(300, Window.availableBounds.height);
win.onClose = Server.default.plotTreeView(0.5, plotter);

