
$(document).ready(function() {
    $('.direct-link-trigger').click(function (event) {
        event.preventDefault();
        var id = $(event.currentTarget).data("directLinkId");
        $('.direct-link-popup').filter(function(idx, element) {
            return $(element).data("directLinkId") === id;
        }).show();
    });

    $('.direct-link-close').click(function (event) {
        event.preventDefault();
        $(event.currentTarget).closest('.direct-link-popup').hide();
    });
});
