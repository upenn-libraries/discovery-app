/**
 * Using data-target attribute for bootstrap tabs causes it not to update
 * the browser's current URL with the #anchor for the tab. This code handles
 * that behavior, as well as back/forward functionality.
 */
$(document).ready(function() {

    $("#feedbackout").click(function(){
        $("#feedback").hide();
    });

    $("a[role='tab']").bind('click', function(event) {
        window.history.pushState({},"", $(event.currentTarget).attr("href"));
    });

    function switchToTab(tabId) {
        $("a[class='tab-" + tabId + "']").tab('show');
    }

    function switchToTabInUrl(url) {
        var hashStart = url.indexOf("#");
        if(hashStart != -1) {
            var tabId = url.slice(hashStart + 1);
            switchToTab(tabId);
        }
    }

    $(window).bind("popstate", function(event) {
        switchToTabInUrl(window.location.href);
    });

    switchToTabInUrl(window.location.href);

});
