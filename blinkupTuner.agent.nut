// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// BlinkUp Tuning Agent Code
// Receives LightLevel samples and serves a graphing web app

class Rocky {

    static version = [1,1,1]

    _handlers = null;

    // Settings:
    _timeout = 10;
    _strictRouting = false;
    _allowUnsecure = false;
    _accessControl = true;

    constructor(settings = {}) {
        if ("timeout" in settings) _timeout = settings.timeout;
        if ("allowUnsecure" in settings) _allowUnsecure = settings.allowUnsecure;
        if ("strictRouting" in settings) _strictRouting = settings.strictRouting;
        if ("accessControl" in settings) _accessControl = settings.accessControl;

        _handlers = {
            authorize = _defaultAuthorizeHandler.bindenv(this),
            onUnauthorized = _defaultUnauthorizedHandler.bindenv(this),
            onTimeout = _defaultTimeoutHandler.bindenv(this),
            onNotFound = _defaultNotFoundHandler.bindenv(this),
            onException = _defaultExceptionHandler.bindenv(this),
        };

        http.onrequest(_onrequest.bindenv(this));
    }

    /************************** [ PUBLIC FUNCTIONS ] **************************/
    function on(verb, signature, callback) {
        // Register this signature and verb against the callback
        verb = verb.toupper();
        signature = signature.tolower();
        if (!(signature in _handlers)) _handlers[signature] <- {};

        local routeHandler = Rocky.Route(callback);
        routeHandler.setTimeout(_timeout);

        _handlers[signature][verb] <- routeHandler;

        return routeHandler;
    }

    function post(signature, callback) {
        return on("POST", signature, callback);
    }

    function get(signature, callback) {
        return on("GET", signature, callback);
    }

    function put(signature, callback) {
        return on("PUT", signature, callback);
    }

    function authorize(callback) {
        _handlers.authorize <- callback;
        return this;
    }

    function onUnauthorized(callback) {
        _handlers.onUnauthorized <- callback;
        return this;
    }

    function onTimeout(callback, t = null) {
        if (t == null) t = _timeout;

        _handlers.onTimeout <- callback;
        _timeout = t;
        return this;
    }

    function onNotFound(callback) {
        _handlers.onNotFound <- callback;
        return this;
    }

    function onException(callback) {
        _handlers.onException <- callback;
        return this;
    }

    function sendToAll(statuscode, response, headers = {}) {
        Rocky.Context._sendToAll(statuscode, response, headers);
    }

    function getContext(id) {
        return Rocky.Context.get(id);
    }

    /************************** [ PRIVATE FUNCTIONS ] *************************/
    // Adds access control headers
    function _addAccessControl(res) {
        res.header("Access-Control-Allow-Origin", "*")
        res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
        res.header("Access-Control-Allow-Methods", "POST, PUT, GET, OPTIONS");
    }

    function _onrequest(req, res) {

        // Add access control headers if required
        if (_accessControl) _addAccessControl(res);

        // Setup the context for the callbacks
        local context = Rocky.Context(req, res);

        // Check for unsecure reqeusts
        if (_allowUnsecure == false && "x-forwarded-proto" in req.headers && req.headers["x-forwarded-proto"] != "https") {
            context.send(405, "HTTP not allowed.");
            return;
        }

        // Parse the request body back into the body
        try {
            req.body = _parse_body(req);
        } catch (e) {
            server.log("Parse error '" + e + "' when parsing:\r\n" + req.body)
            context.send(400, e);
            return;
        }

        // Look for a handler for this path
        local route = _handler_match(req);
        if (route) {
            // if we have a handler
            context.path = route.path;
            context.matches = route.matches;

            // parse auth
            context.auth = _parse_authorization(context);

            // Create timeout
            local onTimeout = _handlers.onTimeout;
            local timeout = _timeout;

            if (route.handler.hasHandler("onTimeout")) {
                onTimeout = route.handler.getHandler("onTimeout");
                timeout = route.handler.getTimeout();
            }

            context.setTimeout(timeout, onTimeout);
            route.handler.execute(context, _handlers);
        } else {
            // if we don't have a handler
            _handlers.onNotFound(context);
        }
    }

    function _parse_body(req) {
        if ("content-type" in req.headers && req.headers["content-type"] == "application/json") {
            if (req.body == "" || req.body == null) return null;
            return http.jsondecode(req.body);
        }
        if ("content-type" in req.headers && req.headers["content-type"] == "application/x-www-form-urlencoded") {
            return http.urldecode(req.body);
        }
        if ("content-type" in req.headers && req.headers["content-type"].slice(0,20) == "multipart/form-data;") {
            local parts = [];
            local boundary = req.headers["content-type"].slice(30);
            local bindex = -1;
            do {
                bindex = req.body.find("--" + boundary + "\r\n", bindex+1);
                if (bindex != null) {
                    // Locate all the parts
                    local hstart = bindex + boundary.len() + 4;
                    local nstart = req.body.find("name=\"", hstart) + 6;
                    local nfinish = req.body.find("\"", nstart);
                    local fnstart = req.body.find("filename=\"", hstart) + 10;
                    local fnfinish = req.body.find("\"", fnstart);
                    local bstart = req.body.find("\r\n\r\n", hstart) + 4;
                    local fstart = req.body.find("\r\n--" + boundary, bstart);

                    // Pull out the parts as strings
                    local headers = req.body.slice(hstart, bstart);
                    local name = null;
                    local filename = null;
                    local type = null;
                    foreach (header in split(headers, ";\n")) {
                        local kv = split(header, ":=");
                        if (kv.len() == 2) {
                            switch (strip(kv[0]).tolower()) {
                                case "name":
                                    name = strip(kv[1]).slice(1, -1);
                                    break;
                                case "filename":
                                    filename = strip(kv[1]).slice(1, -1);
                                    break;
                                case "content-type":
                                    type = strip(kv[1]);
                                    break;
                            }
                        }
                    }
                    local data = req.body.slice(bstart, fstart);
                    local part = { "name": name, "filename": filename, "data": data, "content-type": type };

                    parts.push(part);
                }
            } while (bindex != null);

            return parts;
        }

        // Nothing matched, send back the original body
        return req.body;
    }

    function _parse_authorization(context) {
        if ("authorization" in context.req.headers) {
            local auth = split(context.req.headers.authorization, " ");

            if (auth.len() == 2 && auth[0] == "Basic") {
                // Note the username and password can't have colons in them
                local creds = http.base64decode(auth[1]).tostring();
                creds = split(creds, ":");
                if (creds.len() == 2) {
                    return { authType = "Basic", user = creds[0], pass = creds[1] };
                }
            } else if (auth.len() == 2 && auth[0] == "Bearer") {
                // The bearer is just the password
                if (auth[1].len() > 0) {
                    return { authType = "Bearer", user = auth[1], pass = auth[1] };
                }
            }
        }

        return { authType = "None", user = "", pass = "" };
    }

    function _extract_parts(routeHandler, path, regexp = null) {
        local parts = { path = [], matches = [], handler = routeHandler };

        // Split the path into parts
        foreach (part in split(path, "/")) {
            parts.path.push(part);
        }

        // Capture regular expression matches
        if (regexp != null) {
            local caps = regexp.capture(path);
            local matches = [];
            foreach (cap in caps) {
                parts.matches.push(path.slice(cap.begin, cap.end));
            }
        }

        return parts;
    }

    function _handler_match(req) {
        local signature = req.path.tolower();
        local verb = req.method.toupper();

        // ignore trailing /s if _strictRouting == false
        if(!_strictRouting) {
            while (signature.len() > 1 && signature[signature.len()-1] == '/') {
                signature = signature.slice(0, signature.len()-1);
            }
        }

        if ((signature in _handlers) && (verb in _handlers[signature])) {
            // We have an exact signature match
            return _extract_parts(_handlers[signature][verb], signature);
        } else if ((signature in _handlers) && ("*" in _handlers[signature])) {
            // We have a partial signature match
            return _extract_parts(_handlers[signature]["*"], signature);
        } else {
            // Let's iterate through all handlers and search for a regular expression match
            foreach (_signature,_handler in _handlers) {
                if (typeof _handler == "table") {
                    foreach (_verb,_callback in _handler) {
                        if (_verb == verb || _verb == "*") {
                            try {
                                local ex = regexp(_signature);
                                if (ex.match(signature)) {
                                    // We have a regexp handler match
                                    return _extract_parts(_callback, signature, ex);
                                }
                            } catch (e) {
                                // Don't care about invalid regexp.
                            }
                        }
                    }
                }
            }
        }
        return null;
    }

    /*************************** [ DEFAULT HANDLERS ] *************************/
    function _defaultAuthorizeHandler(context) {
        return true;
    }

    function _defaultUnauthorizedHandler(context) {
        context.send(401, "Unauthorized");
    }

    function _defaultNotFoundHandler(context) {
        context.send(404, format("No handler for %s %s", context.req.method, context.req.path));
    }

    function _defaultTimeoutHandler(context) {
        context.send(500, format("Agent Request Timedout after %i seconds.", _timeout));
    }

    function _defaultExceptionHandler(context, ex) {
        context.send(500, "Agent Error: " + ex);
    }
}

class Rocky.Route {
    _handlers = null;
    _timeout = null;
    _callback = null;

    constructor(callback) {
        _handlers = {};
        _timeout = 10;
        _callback = callback;
    }

    /************************** [ PUBLIC FUNCTIONS ] **************************/
    function execute(context, defaultHandlers) {
        try {
            // setup handlers
            // NOTE: Copying these handlers into the route might have some unintended side effect.
            //       Consider changing this if issues come up.
            foreach (handlerName, handler in defaultHandlers) {
                if (!(handlerName in _handlers)) _handlers[handlerName] <- handler;
            }

            if (_handlers.authorize(context)) {
                _callback(context);
            } else {
                _handlers.onUnauthorized(context);
            }
        } catch(ex) {
            _handlers.onException(context, ex);
        }
    }

    function authorize(callback) {
        _handlers.authorize <- callback;
        return this;
    }

    function onException(callback) {
        _handlers.onException <- callback;
        return this;
    }

    function onUnauthorized(callback) {
        _handlers.onUnauthorized <- callback;
        return this;
    }

    function onTimeout(callback, t = null) {
        if (t == null) t = _timeout;

        _handlers.onTimeout <- callback;
        _timeout = t;
        return this;
    }

    function hasHandler(handlerName) {
        return (handlerName in _handlers);
    }

    function getHandler(handlerName) {
        return _handlers[handlerName];
    }

    function getTimeout() {
        return _timeout;
    }

    function setTimeout(timeout) {
        return _timeout = timeout;
    }
}

class Rocky.Context {
    req = null;
    res = null;
    sent = false;
    id = null;
    time = null;
    auth = null;
    path = null;
    matches = null;
    timer = null;
    userdata = null;
    static _contexts = {};

    constructor(_req, _res) {
        req = _req;
        res = _res;
        sent = false;
        time = date();

        // Identify and store the context
        do {
            id = math.rand();
        } while (id in _contexts);
        _contexts[id] <- this;
    }

    /************************** [ PUBLIC FUNCTIONS ] **************************/
    function get(id) {
        if (id in _contexts) {
            return _contexts[id];
        } else {
            return null;
        }
    }

    function isbrowser() {
        return (("accept" in req.headers) && (req.headers.accept.find("text/html") != null));
    }

    function getHeader(key, def = null) {
        key = key.tolower();
        if (key in req.headers) return req.headers[key];
        else return def;
    }

    function setHeader(key, value) {
        return res.header(key, value);
    }

    function send(code, message = null, forcejson = false) {
        // Cancel the timeout
        if (timer) {
            imp.cancelwakeup(timer);
            timer = null;
        }

        // Remove the context from the store
        if (id in _contexts) {
            delete Rocky.Context._contexts[id];
        }

        // Has this context been closed already?
        if (sent) {
            return false;
        }

        if (forcejson) {
            // Encode whatever it is as a json object
            res.header("Content-Type", "application/json; charset=utf-8");
            res.send(code, http.jsonencode(message));
        } else if (message == null && typeof code == "integer") {
            // Empty result code
            res.send(code, "");
        } else if (message == null && typeof code == "string") {
            // No result code, assume 200
            res.send(200, code);
        } else if (message == null && (typeof code == "table" || typeof code == "array")) {
            // No result code, assume 200 ... and encode a json object
            res.header("Content-Type", "application/json; charset=utf-8");
            res.send(200, http.jsonencode(code));
        } else if (typeof code == "integer" && (typeof message == "table" || typeof message == "array")) {
            // Encode a json object
            res.header("Content-Type", "application/json; charset=utf-8");
            res.send(code, http.jsonencode(message));
        } else {
            // Normal result
            res.send(code, message);
        }
        sent = true;
    }

    function setTimeout(timeout, callback) {
        // Set the timeout timer
        if (timer) imp.cancelwakeup(timer);
        timer = imp.wakeup(timeout, function() {
            if (callback == null) {
                send(502, "Timeout");
            } else {
                callback(this);
            }
        }.bindenv(this))
    }


    /************************** [ PRIVATE FUNCTIONS ] *************************/

    function _sendToAll(statuscode, response, headers = {}) {
        // Send to all active contexts
        foreach (context in _contexts) {
            foreach (key, value in headers) {
                context.setHeader(key, value);
            }
            context.send(statuscode, response);
        }
    }
}

// CONSTS AND GLOBALS ----------------------------------------------------------

c <- null; // web app request context
v <- null; // collected BlinkUp data ("values")

// DEVICE CALLBACKS ------------------------------------------------------------

device.on("blinkupData", function(values){
    local time, val, offset;

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
app.get("/", function(context) { context.send(200, html); });

// Start collecting data when requested by the web app
app.post("/start", function(context) {
    device.send("start", null);
    // hold the request context so that BlinkUp data can be sent back
    // to this web app when the device is done collecting data
    c = context;
});

//---------HTML----------------------------------------------------------------

html <- @"
<html>
  <head>
    <script type='text/javascript'src='https://www.google.com/jsapi'></script>
    <script type='text/javascript' src='https://code.jquery.com/jquery-latest.js'></script>
    <script type='text/javascript'>
    google.load('visualization', '1', {packages: ['corechart', 'controls']});
    google.setOnLoadCallback(function() { drawVisualization('[]'); });

    var chart;

    function drawVisualization(chartData) {
        var dashboard = new google.visualization.Dashboard(document.getElementById('dashboard'));

        var control = new google.visualization.ControlWrapper({
            'controlType': 'ChartRangeFilter',
            'containerId': 'control',
            'options': {
                // Filter by the date axis.
                'filterColumnIndex': 0,
                'ui': {
                    'chartType': 'LineChart',
                    'chartOptions': {
                        'chartArea': {'width': '90%'},
                        'hAxis': {'baselineColor': 'none'}
                    },
                    // Display a single series that shows the closing value of the stock.
                    // Thus, this view has two columns: the date (axis) and the stock value (line series).
                    'chartView': { 'columns': [0, 1]},
                    // 1 day in milliseconds = 24 * 60 * 60 * 1000 = 86,400,000
                    'minRangeSize': 86400000
                }
            },

        });

        chart = new google.visualization.ChartWrapper({
            'chartType': 'LineChart',
            'containerId': 'chart',
            'options': {
                // Use the same chart area width as the control for axis alignment.
                'chartArea': {'height': '80%', 'width': '90%'},
                'hAxis': {'slantedText': false, 'minorGridlines':{'count':'1'}},
                'vAxis': {'viewWindow': {'min': 0, 'max': 1}, 'minorGridlines':{'count':'5'}},
                'legend': {'position': 'none'},
            },
        });


        var data = new google.visualization.DataTable();

        //columns
        data.addColumn('number','Time');
        data.addColumn('number','Level');


        //console.log(chartData);
        //rows
        data.removeRows(0,data.getNumberOfRows());
        data.addRows(JSON.parse(chartData));

        dashboard.bind(control, chart);
        dashboard.draw(data);

    }

    function record(){
        $.ajax({
            type:'POST',
            url: window.location +'/start',
            data: '',
            success: drawVisualization,
            timeout: 120000,
            error: (function(err){
                console.log(err);
                console.log('Error parsing device info from imp');
                return;
            })
        });
    }

    function download(){
        console.log('Download it!');
        var uri = chart.getChart().getImageURI();
        var fn = document.getElementById('filename').value;
        var ld = document.getElementById('link_div');

        ld.innerHTML = '<a href='+uri+' id=""link_a"" download='+fn+'></a>';

        var la = document.getElementById('link_a');
        var clickEvent = document.createEvent('MouseEvent');
        clickEvent.initMouseEvent('click', true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null);
        document.getElementById('link_a').dispatchEvent(clickEvent);
    }

  </script>
  </head>
  <body>
    <button type='button' id='button' onclick='record()'>Start</button>
    <div id='dashboard' style='width: 100%%'>
        <div id='chart' style='width: 99%%; height: 400px;'></div>
        <div id='control' style='width: 99%%; height: 50px;'></div>
    </div>
    <p><p>
    <div id='download_div'>
        <input type='button' value='Download' onclick='download();'>
        <input type='text' id='filename' value='blinkup_test'>
    </div>
    <div id='link_div'></div>
  </body>
</html>";
