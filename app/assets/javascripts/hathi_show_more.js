
$(document).ready(function() {
    $(".show-hathi-extra-links").click(function (event) {
        $(event.currentTarget).hide();
        $(event.currentTarget).parent().find(".hathi-extra-links").show();
        return false;
    });
});
