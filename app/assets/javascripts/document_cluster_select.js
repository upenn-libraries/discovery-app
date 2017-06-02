
$(document).ready(function() {
    $(".document-cluster-select").change(function (event) {
        var selectedId = $(event.currentTarget).find("option:selected").attr("value");
        if(selectedId) {
            window.location = "/catalog/" + selectedId;
        }
        return false;
    });
});
