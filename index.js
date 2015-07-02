var _param = require('./param.json');

var _ = require('underscore');
var _async = require('async');
var _format = require('util').format;
var _request = require('request');
var _tools = require('graphdat-plugin-tools');

var DEFAULT_TIMEOUT = 20000;
var SITE_IS_DOWN = -1;

// if we do not have a poll Interval for the plugin set it
// each endpoint has its own poll interval
var _pollInterval = _param.pollInterval || 1000;

// keep track of the endpoints last polled time so we don't hammer the endpoint
var _previous = {};

function logSuccess(source, duration) {
    console.log('HTTP_RESPONSETIME %d %s', duration, source);
}

function logFailure(err, resp, body, source, debugEnabled) {
    if (debugEnabled) {
        if (err)
            console.error(err);
        if (resp && resp.statusCode)
           console.error('Status: ' + resp.statusCode);
        if (body)
            console.error(body);
    }
    console.log('HTTP_RESPONSETIME %d %s', SITE_IS_DOWN, source);
}

function complete(err) {
    if (err)
        console.error(err);
}

function createHttpOptions(endpoint) {
    // if the user gave us some POST params, set them
    var content = {};
    endpoint.postdata = endpoint.postdata || [];
    _.each(endpoint.postdata, function(kvp) {
        if (!kvp)
            return;
        var kvps = kvp.split('=');
        content[kvp[0]] = kvp[1];
    });

    // setup the HTTP call
    var httpOptions = {
        headers: { 'User-Agent': 'Graphdat <support@graphdat.com>' },
        json: (_.keys(content).length > 0) ? content : undefined,
        method: endpoint.method,
        strictSSL: false,
        timeout: DEFAULT_TIMEOUT,
        uri: _format('%s://%s', endpoint.protocol, endpoint.url),
    };

    // if we have a name and password, then add an auth header
    if (endpoint.username)
        httpOptions.auth = {
            username: endpoint.username,
            password: endpoint.password,
            sendImmediately: true
        };

    return httpOptions;
}

// poll and endpoint and report back
function pollEndpoint(endpoint, cb) {

    // check if we need to poll again
    var last = _previous[endpoint.source] || 0;
    var now = Date.now();
    var source = endpoint.source;

    if ((last + endpoint.pollInterval) > now)
        return cb(null);
    else
        _previous[source] = now;

    // call endpoint and check the return value
    var start = Date.now();
    _request(endpoint.httpOptions, function (err, resp, body) {
        var end = Date.now();
        var duration = end - start;
        if (err)
            logFailure(err, resp, body, source, endpoint.debugEnabled);
        else if (!endpoint.ignoreStatusCode && (resp.statusCode < 200 || resp.statusCode >= 300))
            logFailure(err, resp, body, source, endpoint.debugEnabled);
        else
            logSuccess(source, duration);

        return cb(null);
    });
}

// validate we have Endpoints to poll
if (!_param.items) {
    console.error('No configuration has been setup yet, so we\'re exiting');
    process.exit(1);
}

// generate the HTTP Options and validate the endpoint
_.each(_param.items, function(endpoint) {

    // set the poll interval in case it was set too low
    var pollInterval = parseFloat(endpoint.pollInterval, 10) || 5;
    pollInterval = pollInterval * 1000; // turn into ms
    if (pollInterval < 1000) // incase the user entered the wrong units
        pollInterval = 1000;

    endpoint.pollInterval = pollInterval;

    // generate the HTTP Options used to poll the URL
    endpoint.httpOptions = createHttpOptions(endpoint);
});

function poll() {
    _async.each(_param.items, pollEndpoint, complete);
    setTimeout(poll, _pollInterval);
}

// lets get the party started
poll();
