// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// BlinkUp Tuning Device Code
// Collects LightLevel samples to Tune BlinkUp

class BlinkUpTuner {

    static NUMSAMPLES = 5000; // approximiately 5 seconds; sample rate ~ 1kHz

    static function captureBlinkUp() {
         // disable actual BlinkUp so that tuning tests don't reconfigure this device
         // to use BlinkUp to reconfigure the device under test, power cycle the
         // device under test and BlinkUp within 1 minute
         imp.enableblinkup(false);

         // pre-allocate some space in the blob, assuming ~ 1k samples / second
         // blob will be grown if necessary
         local _blinkUpData = blob(BlinkUpTuner.NUMSAMPLES*6);

         // alias repeatedly-called methods for speed
         local u = hardware.micros.bindenv(hardware);
         local l = hardware.lightlevel.bindenv(hardware);
         local w = _blinkUpData.writen.bindenv(_blinkUpData)
         // sample start and end times to adjust delay for ~ 1kHz sampling
         local prev = null;
         local now = null;

         // tight loop to collect samples
         prev = u();
         for (local n = 0; n < BlinkUpTuner.NUMSAMPLES; n++) {
             w(u(), 'i'); // Write timestamp to blob
             w(l(), 'w'); // Write lightlevel to blob
             now = u();
             imp.sleep(0.001 - ((now - prev) / 1000000.0));
             prev = now;
         }

         _blinkUpData.seek(0);
         return _blinkUpData;
     }
}
