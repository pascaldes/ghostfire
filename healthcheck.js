var http = require("http");

var options = {  
    host : "localhost",
    port : "2368",
    timeout : 2000
};

var request = http.request(options, (res) => {  
    console.log(`STATUS: ${res.statusCode}`);
    if (res.statusCode == 200) {
        process.exit(0);
    }
    else {
        process.exit(1);
    }
});

request.on('error', function(err) {  
    console.log('ERROR');
    process.exit(1);
});

request.end(); 


/*
— — — # — — — # — — — # — — — # — — — # — — —

In the Dockerfile:

HEALTHCHECK --interval=12s --timeout=12s --start-period=30s \  
 CMD node /healthcheck.js
 
https://blog.sixeyed.com/docker-healthchecks-why-not-to-use-curl-or-iwr/

— — — # — — — # — — — # — — — # — — — # — — —
*/