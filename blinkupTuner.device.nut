// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// BlinkUp Tuning Device Code
// Collects LightLevel samples and sends them to the agent to be graphed

class BlinkUpTuner {
    
    static DURATION = 5; // Sampling duration in seconds
    
    // blinkupData will be sent to the agent to be graphed
    _blinkupData = null;
     
    constructor() {
        return;   
    }
    
    function start() {
        // disable actual BlinkUp so that tuning tests don't reconfigure this device
        // to use BlinkUp to reconfigure the device under test, power cycle the
        // device under test and BlinkUp within 1 minute
        imp.enableblinkup(false);
        
        // pre-allocate some space in the blob, assuming ~ 1k samples / second
        // blob will be grown if necessary
        _blinkupData = blob(DURATION * 1000);
        
        // alias repeatedly-called methods for speed
        local u = hardware.micros.bindenv(hardware);
        local l = hardware.lightlevel.bindenv(hardware);
        // sample start and end times to adjust delay for ~ 1kHz sampling
        local s = null;
        local e = null;
        
        // tight loop to collect samples
        for (local n = 0; n < DURATION * 1000; n++) {
            s = u();
            _blinkupData.writen(u(), 'i'); // timestamp
            _blinkupData.writen(l()/128, 'w'); // lightlevel
            e = u();
            imp.sleep(0.001 - ((e - s) / 1000000.0));
        }
        
        _blinkupData.seek(0);
        agent.send("blinkupData", _blinkupData);
    }
}

blinkupTuner <- BlinkUpTuner();
agent.on("start", function(dummy) {
    blinkupTuner.start();
});