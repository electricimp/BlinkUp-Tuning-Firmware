#require "rocky.class.nut:1.2.3"
#require "Bullwinkle.class.nut:2.0.0"
#require "BlinkUpTuner.agent.nut:1.0"

app <- Rocky({timeout = 10})
bull <- Bullwinkle();

// Serve the web app to any request to the root agent URL
app.get("/", function(context) { context.send(200, BlinkUpTuner.html); });

// Start collecting data when requested by the web app
app.post("/start", function(context) {
    bull.send("start").onReply(function(message){
        local time, val, offset, v, values = message.data;
        server.log("Done collecting, sending BlinkUp graphing data to webpage");
        
    
        // unpack the blob of timestamps and light levels
        offset = values.readn('i');
        val = (values.readn('w') / 65535.0);
        v = [[0, val]];
        while (!values.eos()) {
            time = values.readn('i');
            val = (values.readn('w') / 65535.0);
            v.append( [ (time - offset) / 1000000.0, val ] );
        };
        
        // send the decoded data along to the web app to be graphed
        // By using Bullwinkle, our reply is appropriately scoped so we don't need
        // any kind of global variable to hold onto our context object
        context.send(http.jsonencode(v))
    })
});
