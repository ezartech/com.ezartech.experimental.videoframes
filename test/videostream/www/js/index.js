
var app = {
    // Application Constructor
    initialize: function() {
        this.bindEvents();
 
        window.shouldRotateToOrientation = function(degrees) {
            console.log("shouldRotateToOrientation called");
            return true;
        }    
    },
    // Bind Event Listeners
    //
    // Bind any events that are required on startup. Common events are:
    // 'load', 'deviceready', 'offline', and 'online'.
    bindEvents: function() {
        document.addEventListener('deviceready', this.onDeviceReady, false);
    },
    // deviceready Event Handler
    //
    // The scope of 'this' is the event. In order to call the 'receivedEvent'
    // function, we must explicitly call 'app.receivedEvent(...);'
    onDeviceReady: function() {
        var btn = document.getElementById('btn1');
        btn.onclick = function() {
            watchVideoFrames();
        };

        btn = document.getElementById('btn2');
        btn.onclick = function() {
            clearVideoFramesWatch();
        };

        btn = document.getElementById('btn3');
        btn.onclick = function() {
            switchCameras();
        };

        if (window.ezar) {
            ezar.initializeVideoOverlay(
                function() {
                    ezar.getFrontCamera().start(
                        //function() {
                        //   watchVideoFrames();
                        //}
                    );
                },
                function(err) {
                    alert('unable to init ezar: ' + err);
                }
            );
        } else {
            alert('Unable to detect the ezAR plugin');
        }
               
    }
};

app.initialize();


var start, frameCnt=0;
var img;
var canvas, ctx;

img = document.getElementById('myimg');
canvas = document.getElementById('mycanvas');
ctx = canvas ? canvas.getContext("2d") : null;

function watchVideoFrames() {
   
    var cropRect = {
        x: 100,
        y: 100,
        width: 200,
        height: 200
    };

    start = performance.now();
    ezar.watchVideoFrames(cropRect,processJpgFrame);

    fillCanvas();

    img.onload = function() {
        if (ctx) ctx.drawImage(img, 0, 0,400,400);
    };
}

function clearVideoFramesWatch() {
    ezar.clearVideoFramesWatch();
}

function switchCameras() {
    clearVideoFramesWatch();
    var revCam = ezar.getActiveCamera() == ezar.getFrontCamera() ? 
        ezar.getBackCamera() : ezar.getFrontCamera();
    revCam.start();
  }

function processJpgFrame(imageData) {
   
    var dataUrl = imageData;
    img.src = dataUrl;

    //ctx.drawImage(img, 0, 0);

    ++frameCnt;
    if (frameCnt % 30 == 0) {
        showFrameStats();
    }
}

function showFrameStats() {
    var now = performance.now();
    var fps = frameCnt / (now - start) * 1000;
    console.log('framecnt',frameCnt, fps);
    start = now;
    frameCnt = 0;
}

function fillCanvas() {
    if (!ctx) return;

    ctx.fillStyle = "red";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
}

function jackCanvas() {
    var imageData = ctx.getImageData(0,0,50,50);
    var data = imageData.data;
    for (var row=0; row < 25; row++) {
        var pixelIdx = row * imageData.width*4 + 25*4;
        imageData.data[pixelIdx]   = 255;
        imageData.data[pixelIdx+1] = 255;
        imageData.data[pixelIdx+2] = 255;
    }
    ctx.putImageData(imageData,0,0);
}

function jackCanvas1() {
    var imageData = ctx.createImageData(100,100);
    var data = imageData.data;
    for (var i = 0; i < data.length; i += 4) {
      data[i]     = 255;     // red
      data[i + 1] = 255; // green
      data[i + 2] = 255; // blue
      data[i + 3] = 100;
    }
    /*
    for (var row=0; row < 100; row++) {
        for (var col=0; col < 100; col++) {
            var pixelIdx = row * imageData.width*4 + col*4;
            data[pixelIdx]   = 100;
            data[pixelIdx+1] = 0;
            data[pixelIdx+2] = 0;
            data[pixelIdx+3] = 1.0;
        }
    }
    */
    //imageData.data = data;
    ctx.putImageData(imageData,0,0);
}
