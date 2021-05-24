declare name "limiter";
import("stdfaust.lib");

ratio = hslider("ratio", 4, 1, 20, 0.1);
threshold = hslider("threshold", -6, -80, 0, 0.1);
attack = hslider("attack", 0.0008, 0.0001, 1, 0.0001);
release = hslider("release", 0.5, 0.0001, 1, 0.0001);
process = si.bus(4) : co.compressor_mono(ratio, threshold, attack, release) : si.bus(4);
