function activateButton($elem) {
    $elem.prop("disabled", false);
}

function disableRequestButtons() {
    $('.request-button').prop("disabled", true);
}

$(document).ready(function() {
    var $widget = $('#request-item-select');
    if($widget) {
        var mmsId = $widget.data('mmsid');
        var responseData;
        var selectedItem;
        var selectedItemId;
        var papButton = $('#pap-request-button');
        var bbmButton = $('#bbm-request-button');
        var sadButton = $('#sad-request-button');

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
                }).on('select2:open', function(e) {
                    $('.select2-search__field').attr('placeholder', 'Start typing to filter the list');
                }).on('select2:select', function(e) {
                    disableRequestButtons();
                    selectedItemId = this.value;
                    selectedItem = responseData.find(function(item, index) {
                        if(item.id === selectedItemId) {
                            return item;
                        }
                    });
                    if(selectedItem.delivery_options.includes('pickup')) { activateButton(papButton) }
                    if(selectedItem.delivery_options.includes('booksbymail')) { activateButton(bbmButton) }
                    if(selectedItem.delivery_options.includes('scandeliver')) { activateButton(sadButton) }
                });
            });
    }
})
