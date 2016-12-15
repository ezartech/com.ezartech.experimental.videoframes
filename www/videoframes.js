/**
 * _videoframes.js
 * Copyright 2015-2016, ezAR Technologies
 * Licensed under a modified MIT license, see LICENSE or http://ezartech.com/ezarstartupkit-license
 * 
 * @file stream image frames of the video camera 
 * @author @wayne_parrott
 * @version 0.0.1 
 */

var exec = require('cordova/exec'),
    argscheck = require('cordova/argscheck'),
    utils = require('cordova/utils');

module.exports = (function() {
           
	 //--------------------------------------
    var _videoframes = {};
                  
   /**
    * 
    * rect {x,y,width,height}
    */
    var start, frameCnt = 0;
    _videoframes.watchVideoFrames = function(rect,successCallback,errorCallback) {

        start = performance.now();
        exec(successCallback,
            errorCallback,
            "videoFrames",
            "watchVideoFrames",
            [rect.x, rect.y, rect.width, rect.height]);
    }
            
   /**
    *
    *
    */
    _videoframes.clearVideoFramesWatch = function(successCallback,errorCallback) {
                  
        exec(successCallback,
            errorCallback,
            "videoFrames",
            "clearVideoFramesWatch",
            []);
    }
                  
    function _processFrame(data) {
        frameCnt++;
        if (frameCnt % 30 == 0) {
            var now = performance.now();
            var fps = frameCnt / (now - start) * 1000;
            console.log('framecnt',frameCnt, fps);
            start = now;
            frameCnt = 0;
        }
    }
    
    return _videoframes;
    
}());
