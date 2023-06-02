$(document).ready(function() {

    var showing = {};
    var $floorplan = $("#fisherfloorplan");
    var scale = 1;

    var imgWidth = 800;
    var imgHeight = 964;
    var invAspectRatio = imgHeight / imgWidth;

    var calcHeight = function() {
        $floorplan.css("height", $floorplan.width() * invAspectRatio);
        $floorplan.css("max-height", window.innerHeight);
    };
    var calcWidth = function() {
        $floorplan.css("width", $floorplan.height() / invAspectRatio);
        $floorplan.css("max-width", window.innerWidth);
    };
    $(window).resize(calcHeight); //auto resizing when window scales
    $(window).resize(calcWidth);
    calcHeight(); //set the inital width & height
    calcWidth();


    var scalePercent = function(orig, scalar) {
        return (parseInt(orig) * scalar) + "%";
    };
    // format the number + %

    function showFloor(floor){

        currentFloor = floor;
        switch(floor){
        case 0:
                $floorplan.css({ 'background-image': 'url(https://www.library.upenn.edu/sites/default/files/images/floorplans/fisherground.png)'});
                $floorplan.css({ 'background-repeat': 'no-repeat'});
                break;
        case 1:
                $floorplan.css({ 'background-image': 'url(https://www.library.upenn.edu/sites/default/files/images/floorplans/fisherfirst.png)'});
                $floorplan.css({ 'background-repeat': 'no-repeat'});
                break;
        case 2:
                $floorplan.css({ 'background-image': 'url(https://www.library.upenn.edu/sites/default/files/images/floorplans/fishersecond.png)'});
                $floorplan.css({ 'background-repeat': 'no-repeat'});
                break;
        case 3:
                $floorplan.css({ 'background-image': 'url(https://www.library.upenn.edu/sites/default/files/images/floorplans/fisherthird.png)'});
                $floorplan.css({ 'background-repeat': 'no-repeat'});
                break;
        case 4:
                $floorplan.css({ 'background-image': 'url(https://www.library.upenn.edu/sites/default/files/images/floorplans/fisherfourth.png)'});
                $floorplan.css({ 'background-repeat': 'no-repeat'});
                break;
        break;
        }
    }


    function display(target, nAreas){
        //alert("in display");

        for(var i = 0; i < nAreas; i++){
            var $mDiv = $("<div class = 'floor-section' id = 'section" + target + "'></div>"); //create a new $ element
            var props = locations[target+i];
            // console.log(props);
            var styles = {};
            for (var k in props) {
                if (props.hasOwnProperty(k)) {
                    styles[k] = scalePercent(props[k], scale);
                }
            }

            styles["position"] = "absolute";
            styles["z-index"] = 100;
            $mDiv.css(styles); // create a new Div
            $floorplan.append($mDiv); // and then add to original floorplan
            showing[target] = $mDiv;

            //Change css for block for ie8 (deprecated as of jQuery 1.9)
            /*if ( $.browser.msie ) {
                if( parseInt($.browser.version, 10) <= 8 ){
                    $('div.section').css("border-color","#8A2BE2");
                    $('div.section').css("border-style","solid");
                }
            }*/

        }//end of for loop

    } //end of function display


    /*-- Find the target area by hash -----------------*/
    var target;
    var hash = document.location.hash; //document.location is the URL, hash is the #N part
    if (hash) {
        target = hash.slice(1); //get the string from index 1 upwards, aka, get rid of the starting #
        //console.log(target, document.location.hash, locations, "Hello");
    } else {
        // if no hash, go to circulation desk by default
        target = "CIRCULATION_RESERVES";
    }

    if(target){
        var floor = floorMap[target];
        showFloor(floor);
        display(target, nAreas[target].length);
        //console.log("nAreas[target].length: " + nAreas[target].length);
    }

    $(window).hashchange(function(){ location.reload(); });

});
