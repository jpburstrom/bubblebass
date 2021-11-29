declare name "Frequency shifter";
declare description "Mono Frequency Shifting with pre-filtering";
declare author "Johannes Burström (johannes@ljud.org), based on work by Oli Larkin";
declare copyright "Johannes Burström";
declare version "0.1";
declare licence "GPL";

import("stdfaust.lib");
import("FrequencyShifter.lib");

shift = hslider("Shift [unit:hz]", 0.0, -10000., 10000., 0.001);
filterFreq = (5, ma.neg(shift)) : max;

process(x) = x : fi.highpass3e(filterFreq) : ssb(shift);
