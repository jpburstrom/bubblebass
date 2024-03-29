var path = "".resolveRelative;
var closePlotter, plotter;
var win;
var updateFunc = FunctionList();
var updater = SkipJack(updateFunc, 0.3, false, "devGuiUpdate");
//Need to run main first if it's the first time
if (~belaServer.isNil) {
	~respawnAll = true;
	(path +/+ "main.scd").load;
};

win = Window().front.layout_(VLayout(
	HLayout(
		StaticText().string_("Select server"),
		value {
			var pp = PopUpMenu().items_(Server.named.keys.asArray.sort).action_({ |menu|
				Server.default = Server.named[menu.item.asSymbol]
			});

			updateFunc.addFunc({
				pp.value = pp.items.indexOf(Server.default.name)
			});

			pp
		}
	),
	HLayout(
		Button().states_([["Server"]]).action_({
			~belaServer.freeAll;
			"ssh root@bela make -C /root/Bela scsynthstart &".unixCmd;
		}.inEnvir),
		Button().states_([["Startup"]]).action_({
			~belaServer.freeAll;
			"ssh root@bela systemctl start bela_startup &".unixCmd
		}.inEnvir),
		Button().states_([["Stop"]]).action_({ |b|
			~belaServer.freeAll;
			"ssh root@bela make -C /root/Bela stop &".unixCmd

		}.inEnvir),
		Button().states_([["HALT", Color.red]]).action_({ |b|
			~belaServer.freeAll;
			"ssh root@bela halt &".unixCmd
		}.inEnvir)
	),

	HLayout(
		Button().states_([["Re-init server"]]).action_({
			~belaServer.freeAll.initTree.notify_(true).startAliveThread;
		}.inEnvir),
		Button().states_([["Soft reload"]]).action_({
			~respawnAll = false;
			(path +/+ "main.scd").load;
		}.inEnvir),
		Button().states_([["Hard reload"]]).action_({
			~respawnAll = true;
			(path +/+ "main.scd").load;
		}.inEnvir),
	),
	Button().states_([["Mute off"], ["Mute on"]]).action_({ |btn|
		~synths[\playOutput].run(btn.value == 0);
	}.inEnvir),
	StaticText().string_("IMU"),
	HLayout(
		Button().states_([["Calibrate"]]).action_({
			~synths[\globals].set(\imuCalibrate, 1)

		}),
		Button().states_([["Load"]]).action_({
			~synths[\globals].set(\imuLoad, 1)

		}),
		Button().states_([["Save"]]).action_({
			~synths[\globals].set(\imuSave, 1)

		})
	),

	HLayout(
		Button().states_([["Update JSON"]]).action_({
			var filename = PathName.tmp +/+ "score-" ++ UniqueID.next ++ ".json";
			fork {
				ScoreClock.beginScore;
				~respawnAll = true;
				Server.default.sendDefaultGroups;
				(path +/+ "main.scd").load;
				ScoreClock.makeScore;
				File.use(filename, "w", { |f|
					f.write(JSON.stringify(ScoreClock.score.score))
				});
				"scp % root@bela:/root/Bela/projects/bubblebass/score.json".format(filename.quote).unixCmd({ |code, pid|
					if (code == 0) {
						"Score sent to Bela!".postln;
					} {
						"Something went wrong when sending the score".warn;
						"Find the score at: %".format(filename).postln;
					}
				})
			}
		}).toolTip_("Generate and update JSON file on the Bela"),
	),

	(path +/+ "utils/bela-bus-sliders.scd").load.inEnvir.value(path),
	plotter = ScrollView().minHeight_(300)
));
win.view.fixedWidth_(300);
win.setInnerExtent(300, Window.availableBounds.height);
closePlotter = Server.default.plotTreeView(0.5, plotter);
win.onClose = {
	closePlotter.value;
	updater.stop;
}

