~modules = ().make {

	//Dictionary of modules
	~moduleDict = IdentityDictionary().know_(true);

	//Build function. Takes a key and synth arguments
	~build = { |self, key ... args|
		var module = self.moduleDict[key];
		if (module.notNil) {
			var func = self.moduleDict[key][\func];
			var names = func.def.argNames;
			var defaults = func.def.prototypeFrame;
			args = defaults.collect { |default, i|
				var x = args[i];
				if (x.notNil) {
					//Map to spec if value is responding to \specMap
					self.trySpecMap(key, names[i].asSymbol, x)
				} {
					//Try spec if no default value
					if (default.isNil) {
						var spec = self.getParamSpec(key, names[i]);
						if (spec.notNil) {
							default = spec.default
						}
					};
					default
				}
			};
			self.checkRates(key, args, names);
			self.checkSizes(key, args, names);
			//Build
			func.value(*args);
		} {
			"Couldn't find module %".format(key).warn
		}

	};

	//Check rates. Faster rates are accepted, but audio inputs can't take control values
	//rates can be array or single value. The check will wrap shorter arrays or single values.
	~checkRates = { |self, key, args, names|
		args.do { |x, i|
			if (self.moduleDict[key].rates.asArray.wrapAt(i) < x.rate) {
				Error("%: Rate mismatch for arg %".format(key, names[i])).throw;
			}
		};
		true
	};

	//Check sizes.
	//(sizes: nil) //don't check sizes
	//(sizes: [1,2,2]) //check three sizes
	//(sizes: [1, nil, nil]) or (sizes:[1]) //check first arg
	//(sizes: 1) //check all sizes are 1
	~checkSizes = { |self, key, args, names|
		//Optional size check for cases when we don't want multichannel expansion
		//or other weird stuff happening
		if (self.moduleDict[key].sizes.notNil) {
			args.do { |x, i|
				var size = self.moduleDict[key].sizes[i];
				if (size.notNil and: { size != x.asArray.size }) {
					Error("%: Size mismatch for arg %".format(key, names[i])).throw;
				}
			}
		};
		true
	};

	//Add module
	//envir is a dictionary with the following keys:

	//\func: SynthDef building function with arguments corresponding to inputs
	//    Inputs are not converted to controls (as in SynthDef.wrap) but can have default values
	//\specs: Dictionary of specs corresponding to input arguments
	//\sizes: Array or single value of channel count for each input, see ~checkSizes
	//\rates: Array or single value of rate(s) for each input, see ~checkRates
	~addModule = { |self, key, envir|
		self.moduleDict[key] = envir.parent_(IdentityDictionary[
			\rates -> [\scalar]
		]);
	};

	//Remove module
	~removeModule = { |self, key|
		self.moduleDict[key] = nil;
	};

	//Get spec for param, nil if non-existing
	~getParamSpec = { |self, key, param|
		self.moduleDict[key].specs[param]
	};

	//Values can be dictionaries with specMap key pointing to the value
	//In that case, map to spec
	~trySpecMap = { |self, moduleKey, paramKey, value|
		var func = self.moduleDict[moduleKey][\func];
		var names = func.def.argNames;
		var outval = value;
		if ({ value.specMap }.try.notNil) {
			var spec = self.moduleDict[moduleKey].specs[paramKey];
			outval = value.specMap;
			if (spec.notNil) {
				//ControlSpec.map always uses clip and round,
				//avoid if not wanted
				if (value.clip.notNil) {
					outval = outval.clip(0.0, 1.0);
				};
				outval = spec.warp.map(outval);
				//(round: false): don't round
				//(round: nil): round if step != 0.0
				//(round: true): round
				if (value.round.isNil && (spec.step != 0.0) or: { value.round ? false }) {
					outval = outval.round(spec.step)
				};
			} {
				"Couldn't find specMap, using value".warn;
			}
		};
		outval
	}


};

//Load all modules
"modules/*".resolveRelative.pathMatch.do { |path|
	path.load;
};

