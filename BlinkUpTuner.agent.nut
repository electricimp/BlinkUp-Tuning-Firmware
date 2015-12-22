// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
//
// BlinkUp Tuning Agent Code
// Web UI to graph LightLevel samples from the agent,
// used to tune the BlinkUp Receiver

//---------HTML----------------------------------------------------------------

BlinkUpTuner <- {
    html = @"
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
                timeout: 15000,
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
    </html>"
};
