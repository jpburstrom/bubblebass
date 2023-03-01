~modules.addModule(\ifBela, (
	desc: "Conditional branch: if Bela or not",
	func: { |belaFunc, notBelaFunc|
		if (~isBela or: { [~belaServer, Server.named[\ScoreDummy]].includes(~server) },
			belaFunc,
			notBelaFunc
		)
	}
));

