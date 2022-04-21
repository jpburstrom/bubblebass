declare name "GR Pitch Tracker 4";
declare description "4-channel GR-300 style pitch tracker";
declare author "Johannes Burström (johannes@ljud.org)";
declare copyright "Johannes Burström";
declare version "0.1";
declare licence "GPL";

import("stdfaust.lib");

freqA = hslider("ffreq1 [unit:hz]", 32.7, 5.0, 20000., 0.001);
freqB = hslider("ffreq2 [unit:hz]", 32.7, 5.0, 20000., 0.001);
freqC = hslider("ffreq3 [unit:hz]", 32.7, 5.0, 20000., 0.001);
freqD = hslider("ffreq4 [unit:hz]", 32.7, 5.0, 20000., 0.001);


pitchTracker(x, freq) = output with {
    maxFreq = 640;
    /*
    rq = 1;
    halfbw = 0.1 * freq * 0.5;
    fl = freq - halfbw;
    fu = freq + halfbw;
    */
    //Rectify signal
    rectify = (_ * 1e+02) >= 0;
    //Inverse triggers - zero when square is 1, -1
    triggers = fi.tf21(1, -1, 0, 0, 0) <: _ != -1, _ != 1;
    //Make a saw from a stream of 1's plus reset 0 (integrate the 1's)
    trig2saw = _, 1 : fi.pole;
    //make saws from the two triggers above, add inverted triggers
    makeSaws = trig2saw, trig2saw, 1 - _, 1 - _;
    //Input: pair of saw waves, output: denominator
    //Latch first signal with second trigger and vice versa. This gives the halfway value of the saw wave.
    //Add the two saws and we get an approximate amount of samples for a waveform period
    denom = route(4, 4, (1, 2), (4, 1), (2, 4), (3, 3)) : ba.latch, ba.latch: + : max(ma.SR / maxFreq, _ - 3);
    //Scale the raw saw to the current denominator value, which should make the waveform roughly in the -1->1 range
    //below maxFreq (above maxFreq, the amplitude will start diminishing)
    outputSaw = fi.dcblocker((_/_) * 2);
    //Divide samplerate with denom to get the frequency
    outputPitch = !, max(ma.SR/_, 0);
    //Add it up
    output = x : fi.lowpass(1, freq) : rectify <: triggers <: makeSaws <: _, !, !, !, denom <: outputSaw, outputPitch;
};

process(a, b, c, d) = pitchTracker(a, freqA), pitchTracker(b, freqB), pitchTracker(c, freqC), pitchTracker(d, freqD);
