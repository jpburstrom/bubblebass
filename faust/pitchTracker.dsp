declare name "GR Pitch Tracker";
declare description "Mono GR-300 style pitch tracker";
declare author "Johannes Burström (johannes@ljud.org)";
declare copyright "Johannes Burström";
declare version "0.1";
declare licence "GPL";

import("stdfaust.lib");

freq = hslider("Frequency [unit:hz]", 32.7, 5.0, 20000., 0.001);

pitchTracker(x, freq) = output with {
    maxFreq = 640;
    rq = 1;
    halfbw = 0.1 * freq * 0.5;
    fl = freq - halfbw;
    fu = freq + halfbw;
    //Rectify signal
    rectify = (_ * 1e+02) >= 0;
    //Inverse triggers - zero when square is 1, -1
    triggers = fi.tf21(1, -1, 0, 0, 0) <: _ != -1, _ != 1;
    trig2saw = _, 1 : fi.pole;
    makeSaws = trig2saw, trig2saw, 1 - _, 1 - _;
    //Input: pair of saw waves, output: denominator
    denom = route(4, 4, (1, 2), (4, 1), (2, 4), (3, 3)) : ba.latch, ba.latch: + : max(ma.SR / maxFreq, _ - 3);
    outputSaw = fi.dcblocker((_/_) * 2);
    outputPitch = !, max(ma.SR/_, 0);
    output = x : fi.bandpass(1, fl, fu) : rectify <: triggers <: makeSaws <: _, !, !, !, denom <: outputSaw, outputPitch;
};

process(x) = x : pitchTracker(_, freq);
