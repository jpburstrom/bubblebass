//Changing as little as possible to allow recording remotely
RemoteRecorder : Recorder {
	prepareForRecord { | path, numChannels |
		var dir;

		numChannels = numChannels ? server.recChannels;

		path = if(path.isNil) { this.makePath } { path.standardizePath };
		dir = path.dirname;

		//TODO Directory check

		recordBuf = Buffer.alloc(server,
			this.recBufSize,
			numChannels,
			{| buf |
				buf.writeMsg(path, this.recHeaderFormat, this.recSampleFormat, 0, 0, true)
			}
		);
		if(recordBuf.isNil) { Error("could not allocate buffer").throw };
		recordBuf.path = path;
		this.numChannels = numChannels;
		id = UniqueID.next;

		synthDef = SynthDef(SystemSynthDefs.generateTempName, { |in, bufnum, duration|
			var tick = Impulse.kr(1);
			var timer = PulseCount.kr(tick) - 1;
			var doneAction = if(duration <= 0, 0, 2);
			Line.kr(0, 0, duration, doneAction:doneAction);
			SendReply.kr(tick, '/recordingDuration', timer, id);
			DiskOut.ar(bufnum, In.ar(in, numChannels))
		}).send(server);

		"Preparing recording on '%'\n".postf(server.name);
	}
}