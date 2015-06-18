# BlinkUp&trade; Tuner Utility

This utility simplifies the process of tuning the BlinkUp receiver circuit for your imp-based device.

BlinkUp&trade; uses light and dark pulses, typically from a smartphone screen or an LED, to convey WiFi credentials and provisioning information to an imp. Light levels are detected with a simple circuit which uses a phototransistor and gain resistor to translate light level into a voltage signal. The value of the gain resistor must be carefully selected to acheive the best possibile BlinkUp reliability given your phototransistor and mechanical design.

This utility collects [hardware.lightlevel](https://electricimp.com/docs/api/hardware/lightlevel) samples during BlinkUp and produces a graph, which can be used to determine how the gain resistor should be adjusted to optimize BlinkUp. See [How to Tune Your BlinkUp Circuit](https://electricimp.com/docs/hardware/blinkuptuning/) in the Electric Imp Developer Center.

## Usage

Create a new model, and run the below code (which mirrors the [example](./examples)). For more information, see the [Hardware BlinkUp Tuning Guide](https://electricimp.com/docs/hardware/blinkuptuning/).

### Device Code

```Squirrel
// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// BlinkUp Tuning Device Code
// Collects LightLevel samples and sends them to the agent to be graphed

#require "BlinkUpTuner.device.nut:1.0"

agent.on("start", BlinkUpTuner.captureBlinkUp);
```

### Agent Code

```Squirrel
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
```

# License

The BlinkUpTuner library is licensed under the [MIT License](./LICENSE).
