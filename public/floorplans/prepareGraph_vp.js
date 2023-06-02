$(document).ready(function() {

    /* Find the target area by hash
     * Moved to the top of this script so we can use the hash to determine whether
     * we're on the 6th floor (because they have a different image size).*/
    var target;
    var hash = document.location.hash;

    if (hash) {
        target = hash.slice(1);
       // console.log(target, document.location.hash, locations, "Hello");
    } else {
        // show bare map?
    }

    var showing = {};
    var currentFloor;
    var $floorplan = $("#vpfloorplan");
    var scale = 1;

    var imgWidth = 1500;
    var imgHeight = 513;
    if (floorMap[target] == 6) {
        imgWidth = 2702;
        imgHeight = 1322;
    }
    var invAspectRatio = imgHeight / imgWidth;
    var calcHeight = function() {
        $floorplan.css("height", $floorplan.width() * invAspectRatio);
    };

    $(window).resize(calcHeight);
    calcHeight();

    var scalePercent = function(orig, scalar) {
        return (parseInt(orig) * scalar) + "%";
        //return $(window).height() * (parseInt(orig) * scalar)/100 + "px";
    };
    // format the number + %

    showing = {};
    function display(target, nAreas){
        //alert("in display");
        for(var i = 0; i < nAreas; i++){
            var $mDiv = $("<div class = 'floor-section' id = 'section" + target + "'></div>");
            var props = locations[target+i];
            //console.log(props);

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
                if ( parseInt($.browser.version, 10) <= 8 ){
                    $('div.section').css("border-color","#8A2BE2");
                    $('div.section').css("border-style","solid");
                }
            }*/
        }
    }

    function showFloor(floor){
        currentFloor = floor;
        switch (floor) {
        case 0:
                $("div#vpfloorplan").html('<img class="sourceImage" src="https://www.library.upenn.edu/sites/default/files/images/floorplans/vpground.png" alt="" />');
                $("div#vpfloorplan .sourceImage").css({ 'width': '100%', 'position': 'absolute', 'top':'0', 'left':'0'});
                break;
        case 1:
               $("div#vpfloorplan").html('<img class="sourceImage" src="https://www.library.upenn.edu/sites/default/files/images/floorplans/vpfirst.png" alt="" />');
                $("div#vpfloorplan .sourceImage").css({ 'width': '100%', 'position': 'absolute', 'top':'0', 'left':'0'});
                break;
        case 2:
                $("div#vpfloorplan").html('<img class="sourceImage" src="https://www.library.upenn.edu/sites/default/files/images/floorplans/vpsecond.png" alt="" />');
                $("div#vpfloorplan .sourceImage").css({ 'width': '100%', 'position': 'absolute', 'top':'0', 'left':'0'});
                break;
        case 3:
                $("div#vpfloorplan").html('<img class="sourceImage" src="https://www.library.upenn.edu/sites/default/files/images/floorplans/vpthird.png" alt="" />');
                $("div#vpfloorplan .sourceImage").css({ 'width': '100%', 'position': 'absolute', 'top':'0', 'left':'0'});
                break;
        case 4:
                $("div#vpfloorplan").html('<img class="sourceImage" src="https://www.library.upenn.edu/sites/default/files/images/floorplans/vpfourth.png" alt="" />');
                $("div#vpfloorplan .sourceImage").css({ 'width': '100%', 'position': 'absolute', 'top':'0', 'left':'0'});
                break;
        case 5:
                $("div#vpfloorplan").html('<img class="sourceImage" src="https://www.library.upenn.edu/sites/default/files/images/floorplans/vpfifth.png" alt="" />');
                $("div#vpfloorplan .sourceImage").css({ 'width': '100%', 'position': 'absolute', 'top':'0', 'left':'0'});
                break;
        case 6:
                $("div#vpfloorplan").html('<img class="sourceImage" src="https://www.library.upenn.edu/sites/default/files/images/floorplans/vpsixth.png" alt="" />');
                $("div#vpfloorplan .sourceImage").css({ 'width': '100%', 'position': 'absolute', 'top':'0', 'left':'0'});
                break;
        }
    }

    /*-- Select a floor to edit -----------------------*/
    /*
    $("button#select").click(function(){
        var floor = parseInt($("option:selected").val());
        showFloor(floor);
    });
    */

    if (target){
        if (target[0] == "P"){
            target = pMap[target];
        }
        var floor = floorMap[target];
        showFloor(floor);
        display(target, nAreas[target].length);
    }
    $floorplan.css("height", $floorplan.width() * invAspectRatio);

    $(window).hashchange(function(){
       location.reload();
    });

});



/*-- Draw Box to Mark Areas --------------------------*/
/*
	var x1 = [];
    var x2 = [];
    var y1 = [];
    var y2 = [];

	var bWidth = [];
    var bHeight = [];

    var nArea = 0;
	var flag = 0;

/*
    $("div#vpfloorplan").mousedown(function(e) {
        flag = 1;
        $("#current").attr({ id: '' })
		box = $('<div style="border:1px #FF00FF solid;position:fixed;">').hide(); /* set line color for draw areas */
/*		$("#floorplan").append(box);

		x1[nArea] = e.pageX;
		y1[nArea] = e.pageY;

		box.attr({id: 'current'}).css({
			top: e.pageY , //offsets
			left: e.pageX  //offsets
		}).fadeIn();
	});

	$("div#vpfloorplan").mousemove(function(e) {

		$("#current").css({
			width:Math.abs(e.pageX - x1[nArea]), //offsets
			height:Math.abs(e.pageY - y1[nArea]) //offsets
		}).fadeIn();
	});

	$("div#vpfloorplan").mouseup(function(e) {
		bWidth[nArea] = e.pageX - x1[nArea];
		bHeight[nArea] = e.pageY - y1[nArea];
		$("#current").attr({ id: '' }) // why use id: ''?
        if(flag == 1){
            nArea++;
        }
        flag = 0;
    });
*/

/*------------------------------- */

/*
    var arr = [];
    var wp = function(char){
        return '"' + char + '"';
    };

    var left =[];
    var top = [];
    var wid = [];
    var hei = [];

/*
	$("#apply").click(function(){

				var area;
                var i;

                $("input").keyup(function(){
                    area = $(this).val();
                }).keyup();

                arr.push("Locations:----------------------------------\n");

                for(i = 0; i < nArea; i++){

                    left[i] = parseInt((x1[i]/$("#floorplan").width())*100) + "%";
                    top[i] = parseInt((y1[i]/$("#floorplan").height())*100) + "%";
                    wid[i] = parseInt((bWidth[i]/$("#floorplan").width())*100) +"%";
                    hei[i] = parseInt((bHeight[i]/$("#floorplan").height())*100) + "%";

                    var property = [top[i], left[i], wid[i], hei[i]];

                    var str = "{"
                                + wp("top") +":"+ wp(top[i]) +","
                                + wp("left")+ ":"+ wp(left[i])+","
                                + wp("width")+":"+ wp(wid[i])+","
                                + wp("height")+":"+ wp(hei[i])+
                               "}";

                  //  console.log("str:" + str);


                    var final = wp(area+i) + ":"+ str;
                    arr.push(final);


                }

                var numOfAreas = wp(area)+":"+"{"+'"'+"length"+'"'+":"+wp(nArea)+"}";
                arr.push("\nLength:-----------------------------------\n");
                arr.push(numOfAreas);

                var floorMap = wp(area) + ":" + currentFloor;
                arr.push("\nfloorMap:----------------------------------\n");
                arr.push(floorMap);

                alert(arr);


	});
   */
