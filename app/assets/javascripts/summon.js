$(document).ready(function() {
    $(".summon-form").submit(function(event) {
        event.preventDefault();
        var searchURL = "http://upenn.summon.serialssolutions.com/#!/search?q=" + encodeURIComponent($(".summon-form input[name='q']").val());
        // Must concatenate all fvf values into one parameter.
        var fvf = "";
        $(".summon-form .limit-options input:checked").each(function() {
            if (this.name === "fvf") {
                if (fvf !== "") {
                    fvf += "|";
                }
                fvf += this.value;
            } else {
                searchURL += "&" + this.name + "=" + this.value;
            }
        });
        if (fvf !== "") {
            searchURL += "&fvf=" + fvf;
        }
        window.location.href = searchURL;
    });
});

BentoSearch.ajax_load.default_success_callback = function(div) {
    // set the login link with proper redirect
    var currentUrl = window.location.href;
    var proxyUrl = 'https://proxy.library.upenn.edu/login?url=http://127.0.0.1:8082/?redirect=' + encodeURIComponent(currentUrl);
    $(div).find(".ezproxy-login-link").attr("href", proxyUrl);
};
