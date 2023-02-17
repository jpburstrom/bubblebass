~bela = Server.remote(\bela, NetAddr("bela.local", 57110), s.options);
Server.default = ~bela;
~bela.notify = true;

~bela.startAliveThread
~bela.initTree
ServerOptions
~bela.queryAllNodes
~bela.freeAll

~bela.initTree
z = { BNO.orientationKr(\cal.tr(0), \load.tr(0), \save.tr(0)).poll(0.5) }.play
s.scope(3, 0, rate:\control);
z.set(\save, 1)

9&8
        SynthDef(\bnoTest, {
            BNO.orientationKr.poll(1, "ori");
        }).writeDef; //Store so we can run server
(
fork {
	Ndef(\trillTest).end;
	0.5.wait;
	Ndef(\trillTest, {
		4.do { |i|
			var vals = TrillCentroids.kr(1, 0x20 + i, 0.02, 4);
			SendReply.kr(Impulse.kr(10), "/trill%".format(i), vals);
		}
	});
}
)


~slider = 4.collect { Slider() };
Window().front.layout_(HLayout(*~slider));
(
4.do { |i|
	OSCdef("trill%".format(i).asSymbol, { |msg|
		if (msg[3] == 1) {
			{ ~slider[i].value = msg[4] }.defer
		}
	}, "/trill%".format(i))
}
)
OSCdef(\trill).free


(
{ DigitalIn
)