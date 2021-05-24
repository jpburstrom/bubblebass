declare name "compLimiter";
import("stdfaust.lib");

channels = 4;
strength = hslider("strength", 0, 0, 1, 0.001):si.smoo; 	//write a specific position input signal operation here
thresh = hslider("thresh [unit:dB]", -20, -60, 0, 0.1):si.smoo;
threshLim = hslider("threshLim [unit:dB]", -6, -60, 0, 0.1):si.smoo;
att = hslider("att [unit:ms] [scale:log] [tooltip: Time constant in ms]", 8, 1, 100, 0.1) : *(0.001) : max(1/ma.SR);
rel = hslider("rel [unit:ms] [scale:log] [tooltip: Time constant in ms]", 500, 1, 1000, 0.1) : *(0.001) : max(1/ma.SR);
knee = hslider("knee", 3, 0, 18, 0.1):si.smoo;
makeupgain = hslider("makeupGain [unit:dB]
	[tooltip: The compressed-signal output level is increased by this amount
	(in dB) to make up for the level lost due to compression]",
	0, 0, 24, 0.1) : ba.db2linear;
link = 0;


 
process = si.bus(channels) : co.RMS_FBcompressor_peak_limiter_N_chan(strength,thresh,threshLim,att,rel,knee,link,_,channels) : par(i, 4, *(makeupgain)) : si.bus(channels);
