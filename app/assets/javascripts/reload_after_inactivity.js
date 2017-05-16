$(document).ready(function () {

    // this mechanism exists to prevent users from clicking on stale iframe links
    if($(".reload-inactive-page").length > 0) {
        var inactiveTimeoutMs = 3600000;
        var now = new Date().getTime();

        $(document.body).bind("mousemove keypress", function (e) {
            if (new Date().getTime() - now >= inactiveTimeoutMs) {
                window.location.reload(true);
            }
            now = new Date().getTime();
        });
    }

});
