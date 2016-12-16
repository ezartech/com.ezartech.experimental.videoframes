#ezAR VideoStream Cordova Plugin
This experimental plugin produces video frames from the camera preview created by the VideoOverlay 
plugin. The video frames are returned to your app in the form of JPEG images encoded as data url 
via a callback you provide. You must includes the VideoOverlay plugin in your app and start a 
camera before starting to capture video frames.


##Supported Platforms
- iOS 7, 8 & 9

##Getting Started
The simplest ezAR application involves adding the VideoOverlay   
and VideoStream plugins to your Corodva project using the Cordova CLI

        cordova plugin add pathtoezar/com.ezartech.ezar.videooverlay
        cordova plugin add pathtoezar/com.ezartech.experimental.videostream

Next in your Cordova JavaScript deviceready handler include the following  
JavaScript snippet to initialize the VideoOverlay plugin and activate the  
camera on the back of the device, i.e., the camera away from the display.

        ezar.initializeVideoOverlay(
            function() {
                ezar.getBackCamera().start(watchFrames);
            },
            function(err) {
                alert('unable to init ezar: ' + err);
            }
        );

        function watchFrames() {
            //define the rectangle to crop
            var cropRect = {x:0,y:0,width:200,height:200};
            ezar.watchVideoFrames(
                function(rect,jpgImageDataURI) {
                    //do something with jpg image
                }
            );
        }

        function stopWatchingFrames() {
            ezar.clearVideoFramesWatch();
        }
                    
##Additional Documentation        
See [ezartech.com](http://ezartech.com) for documentation and support.

##License
The ezAR Startup Kit is licensed under a [modified MIT license](http://www.ezartech.com/ezarstartupkit-license).


Copyright (c) 2015-2016, ezAR Technologies


