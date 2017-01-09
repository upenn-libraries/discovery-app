$(document).ready(function() {

    function BlacklightAlmaCustom() {
    };

    BlacklightAlmaCustom.prototype = new BlacklightAlma();

    /*
    BlacklightAlmaCustom.prototype.loadAvailability = function(){
        BlacklightAlma.prototype.loadAvailability.call(this);
        console.log("I'm here!")
        $(".show-on-availability-ajax-load").removeClass("hide").show();
    };
    */

    var ba = new BlacklightAlmaCustom();
    ba.loadAvailability();

});
