
$(document).ready(function() {
    $(".show_hathi_extra_links").click(function (event) {
        $(event.currentTarget).hide();
        $(event.currentTarget).parent().find(".hathi_extra_links").show();
        return false;
    });
});
