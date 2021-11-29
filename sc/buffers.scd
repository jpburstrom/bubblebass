//A buffer/bufrd factory for mapping curves
//1. Define a mapping: ~buffers.addMapping(\foo)
//2. Make a synthdef with the getBufRd method: ~buffers.getBufRd(\foo)
//3. Play synth: Synth(\..., [\mapbufnum, ~buffers.getBuffer(\foo)])
(
var ev = (
	server: ~server,
	buffers: (),
	readers: (),
	freeServerNode: {
		~buffers.do(_.free);
	},
	bufferSize: 512,
	ampModCurve: { |self, min, mid=0, max|
		var limit = min.abs.max(max.abs);
		self.bufferSize.collect({ |i|
			var val = i.linlin(0, self.bufferSize-1, limit.neg, limit);
			if (val < mid) {
				val = val.lincurve(min, mid, -4, 0, -4);
			} {
				val = val.lincurve(mid, max, 0, 6, 4);
			};
			2.pow(val);
		})
	},
	allPassCurve: { |self, min, mid=0, max|
		var limit = min.abs.max(max.abs);
		self.bufferSize.collect({ |i|
			var val = i.linlin(0, self.bufferSize-1, limit.neg, limit);
			if (val < mid) {
				val = val.lincurve(min, mid, 60, 1000, 4);
			} {
				val = val.lincurve(mid, max, 1000, 200, 4);
			};
			val
		})
	},
	sendCollection: { |self, name, collection|
		self.buffers[name] = Buffer.sendCollection(self.server, collection);
	},
	makeSynthDef: { |self, key|
		SynthDef(key, {
			var sig = In.kr(\in.kr(0));
			sig = Sanitize.kr(sig);
			Out.kr(\out.kr(0), self.getBufRd(key, sig).lag(0.1));
		}).add;
	},
	addMapping: { |self, name, min, max, mid=0, curve=\ampModCurve|
		var coll = self.perform(curve, min, mid, max);
		var limit = min.abs.max(max.abs);
		self.sendCollection(name, coll);
		self.readers[name] = { |phase, mapbufnum|
			phase = phase.linlin(limit.neg, limit, 0, self.bufferSize-1);
			BufRd.kr(1, mapbufnum, phase, 1);
		};
		self.makeSynthDef(name);
	},
	getBufRd: { |self, name, input|
		if (self.buffers[name].isNil) {
			Error("Buffer doesn't exist").throw;
		};
		SynthDef.wrap(self.readers[name], prependArgs: [input]);
	},
	getBuffer: { |self, key|
		if (self.buffers[key].isNil) {
			Error("Buffer doesn't exist").throw;
		};
		self.buffers[key];
	},
	getSynth: { |self, key, args, target, addAction|
		if (self.buffers[key].isNil) {
			Error("Mapper doesn't exist").throw;
		};
		args = args ++ [\mapbufnum, self.getBuffer(key)];
		Synth(key, args, target, addAction);
	}


);

~buffers = ev;
ev
)



