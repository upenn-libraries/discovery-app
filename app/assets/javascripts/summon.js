$(document).ready(function() {
    $(".summon-form").submit(function(event) {
        event.preventDefault();
        var searchURL = "https://upenn.summon.serialssolutions.com/#!/search?q=" + encodeURIComponent($(".summon-form input[name='q']").val());
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

