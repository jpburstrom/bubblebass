//Display scope for bubblebass buses
{
	arg path;

	var win, sliders, numbers, synth, func, buses, audiobuses, clist, alist, listAction, serverBootAction, selectedAudioBus,
	recBtn, saveBtn, textField;

	var recordingPath = "/root/Bela/projects/bubblebass/recordings";

	var actions = (
		textFieldInitRename: { |self, str=""|
			textField.visible_(true).enabled_(true).focus().string_(str);
			saveBtn.value = 1;
		},
		textFieldExitRename: { |self, ok|
			textField.enabled = false;
			saveBtn.value = 0;
			textField.visible = false;
			textField.string = "";
		},
		dirExists: { |self, path|
			var out = "bash -c 'ssh root@bela [[ -d \"%\" ]] && echo yes' &".format(path).unixCmdGetStdOut;
			out[..2] == "yes";
		},
		fileExists: { |self, path|
			var out = "bash -c 'ssh root@bela [[ -f \"%\" ]] && echo yes' &".format(path).unixCmdGetStdOut;
			out[..2] == "yes";
		},
		renameFile: { |self, from, to|
			var out = "bash -c 'ssh root@bela mv \"%\" \"%\" && echo yes' &".format(from, to).unixCmdGetStdOut;
			out[..2] == "yes";
		},
		deleteFile: { |self, path|
			var out = "bash -c 'ssh root@bela rm \"%\" && echo yes' &".format(path).unixCmdGetStdOut;
			out[..2] == "yes";
		}
	);

	listAction = { |bus|
		synth.free; func.free;
		func = OSCFunc({ |msg|
			defer {
				sliders.do { |sl, i|
					msg[i+3] !? { |val|
						sl.value = val;
						numbers[i].value = val;
						numbers[i].enabled = true;
						sl.enabled = true;
					} ?? {
						sl.value = 0;
						numbers[i].value = -1;
						numbers[i].enabled = false;
						sl.enabled = false;
					};
				}
			}
		}, '/busViewer', ~server.addr);

		synth = SynthDef(\busViewer, {

			var sig;
			if (bus.rate == \control) {
				sig = In.kr(bus.index, bus.numChannels);
			} {
				sig = A2K.kr(RMS.ar(In.ar(bus.index, bus.numChannels), 5));
			};
			SendReply.kr(Impulse.kr(5), '/busViewer', sig);
		}).play(addAction:\addToTail);
	};

	audiobuses = (
		spkr: Bus(),
		direct: Bus(\audio, 2, 4),
		main: { ~audioBus.main },
		pitchTracker: { ~audioBus.pitchTracker },
		input: Bus('audio', 6, 4);


	);
	buses = ();

	serverBootAction = {

		~ctlBus.keysValuesDo({ |k, item|
			if (item.isArray) {
				item.do { |bus, i|
					buses["% %".format(k, i + 1).asSymbol] = bus;
				}
			} {
				buses[k] = item;
			}
		});
		alist.items_(audiobuses.keys.asArray.sort);
		clist.items_(buses.keys.asArray.sort);

		alist.valueAction = 0;
		clist.valueAction = 0;
		if (actions.dirExists(recordingPath)) {
			recBtn.enabled = true;
		} {
			"Recording directory % doesn't exist".format(recordingPath).warn;
		};

	}.inEnvir;

	sliders = 5.collect { Slider().orientation_(\vertical) };
	numbers = 5.collect { NumberBox() };
	//~server.notify = true;

	win = View().layout_(VLayout(
		GridLayout.rows(sliders, numbers),
		StaticText().string_("Control Buses"),
		[clist = ListView().action_({ |v|
			listAction.(buses[v.item].value)
		}), s:2],
		StaticText().string_("Audio Buses"),
		[alist = ListView().action_({ |v|
			selectedAudioBus = v.item.postln;
			listAction.(audiobuses[v.item].value);
		}), s:1],
		value {
			var lastRecordingPath, recorder, pathLabel, delButton;
			VLayout(
				pathLabel = StaticText(),
				HLayout(
					recBtn = Button().states_([["REC"], ["Stop rec", Color.white, Color.red]]).action_({ |btn|
						if (btn.value == 1) {
							//Start recording
							var bus = audiobuses[selectedAudioBus];
							var filename = "bubblebass-%-%.wav".format(selectedAudioBus, Date.localtime.stamp
							);
							lastRecordingPath = recordingPath +/+ filename;
							pathLabel.string = filename;

							recorder = RemoteRecorder(~belaServer);
							recorder.recHeaderFormat = "wav";
							recorder.recSampleFormat = "int24";

							recorder.record(lastRecordingPath, bus, bus.numChannels);

						} {
							recorder.stopRecording;
							delButton.enabled = true;
							saveBtn.enabled = true;
						}
					}.inEnvir).enabled_(false),
					delButton = Button().states_([["DEL"]]).action_({ |btn|
						if (actions.deleteFile(lastRecordingPath).not) {
							"Error deleting file".error
						} {
							btn.enabled = false;
							saveBtn.enabled = false;
							pathLabel.string = "";
							lastRecordingPath = nil;
						}
					}.inEnvir).enabled_(false),
					saveBtn = Button().states_([["REN"], ["Cancel"]]).action_({ |btn|
						if (btn.value == 1) {
							actions.textFieldInitRename(lastRecordingPath.basename);
						} {
							actions.textFieldExitRename(false);
						}

					}.inEnvir).enabled_(false),
					Button().states_([["PLAY"]]).action_({
						(path +/+ "utils/player.scd").resolveRelative.load.value(
							recordingPath, audiobuses)
					})

				),
				textField = TextField().visible_(false).action_({ |field|
					var name = field.string;
					if (name.extension.isNil) {
						name = "%.wav".format(name);
					};

					name = recordingPath +/+ name;

					if (actions.fileExists(name) ) {
						"File % exists".format(name).warn
					} {
						if ( actions.renameFile(lastRecordingPath, name).not ) {
							"Couldn't rename file".warn;
						} {
							lastRecordingPath = name;
							pathLabel.string = lastRecordingPath.basename;
						};

						actions.textFieldExitRename(true);
					};

				}).keyDownAction_({ |view, char, mod, unicode, keycode, key|
					if (key == 16777216) {
						actions.textFieldExitRename(false);
					}
				}).toolTip_("Enter filename with or without extension"),
			)
		},
	));
	win.onClose = { synth.free; func.free; ServerBoot.remove(serverBootAction, ~belaServer) };

	ServerBoot.add(serverBootAction, ~belaServer);
	if (~belaServer.serverRunning) {
		serverBootAction.value;
	};

	win

}

