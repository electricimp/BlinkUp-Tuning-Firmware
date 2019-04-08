#require "Bullwinkle.class.nut:2.0.0"
#require "BlinkUpTuner.device.nut:1.0"

bull <- Bullwinkle();

bull.on("start", function(message, reply){
    server.log("Collecting BlinkUp Sample");
    reply(BlinkUpTuner.captureBlinkUp())
})
