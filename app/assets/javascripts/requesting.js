$(document).ready(function() {
    var $widget = $('#request-item-select');
    if($widget) {
        var mmsId = $widget.data('mmsid');
        var responseData;

        $.ajax({
            url: '/alma/items/' + mmsId + '/all',
            dataType: 'json'
        })
            .done(function(data) {
                responseData = data
                $widget.select2({
                    theme: 'bootstrap',
                    placeholder: "Click here to make a selection",
                    width: "100%",
                    data: responseData
                }).on('select2:open', function(e){
                    $('.select2-search__field').attr('placeholder', 'Start typing to filter the list');
                });
            });
    }
})
