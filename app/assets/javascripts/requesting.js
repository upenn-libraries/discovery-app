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

        $('.request-button').on('click', function(e) {
            e.preventDefault();
            $("#confirm-modal").modal('show', $(this));
        });

        $('#confirm-modal').on('show.bs.modal', function(e) {
            var $modal = $(this)
            var $deliveryButton = e.relatedTarget;
            $modal.find('#requestItemPid').val(selectedItem.id);
            $modal.find('#requestHoldingId').val(selectedItem.holding_id);
            $modal.find('#requestMmsId').val(mmsId);
            showAndUpdateDiv('requestItemTitle', selectedItem.title);
            // $modal.find('#requestItemTitle').text(selectedItem.title);
            showAndUpdateDiv('requestItemDescription', selectedItem.description);
            // $modal.find('#requestItemDescription').text(selectedItem.description);
            $modal.find('#requestItemNote').text(selectedItem.public_note);
            $modal.find('#requestDeliveryMethod').text($deliveryButton.val());
        });
    }
})

function showAndUpdateDiv(id, content) {
    if(content) {
        var $element = $("#" + id);
        if($element) {
            $element.closest('.form-group').removeClass('hidden');
            $element.text(content);
        }
    }
//    if content is not empty, show #id and add content as text
}
