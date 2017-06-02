
$(document).ready(function() {
    $(".show-online-resource-extra-links").click(function (event) {
        $(event.currentTarget).hide();
        $(event.currentTarget).parent().find(".online-resource-extra-links").show();
        return false;
    });
});
