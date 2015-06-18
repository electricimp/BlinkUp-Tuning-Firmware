// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// BlinkUp Tuning Agent Code
// Receives LightLevel samples and serves a graphing web app

#require "Rocky.class.nut:1.1"
#require "BlinkUpTuner.agent.nut:1.0"

// CONSTS AND GLOBALS ----------------------------------------------------------

c <- null; // web app request context
v <- null; // collected BlinkUp data ("values")

// DEVICE CALLBACKS ------------------------------------------------------------

device.on("blinkupData", function(values){
    local time, val, offset;
    server.log("Done collecting, graphing BlinkUp");

    // unpack the blob of timestamps and light levels
    offset = values.readn('i');
    val  = 1.0 - (values.readn('w') / 65535.0);
    v = [[0, val]];
    while (!values.eos()) {
        time = values.readn('i');
        val  = 1.0 - (values.readn('w') / 65535.0);
        v.append( [ (time - offset) / 1000000.0, val ] );
    };

    // send the decoded data along to the web app to be graphed
    imp.wakeup(0, function() { c.send(200, http.jsonencode(v))});
});

// RUNTIME ---------------------------------------------------------------------

app <- Rocky({timeout = 60});

// Serve the web app to any request to the root agent URL
app.get("/", function(context) { context.send(200, BlinkUpTuner.html); });

// Start collecting data when requested by the web app
app.post("/start", function(context) {
    server.log("Collecting BlinkUp Sample");
    device.send("start", null);
    // hold the request context so that BlinkUp data can be sent back
    // to this web app when the device is done collecting data
    c = context;
});
