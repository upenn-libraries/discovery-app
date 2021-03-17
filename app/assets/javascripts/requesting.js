function activateButton($elem) {
    $elem.prop("disabled", false);
}

function resetRequestButtons() {
    $('.request-button').prop("disabled", true);
    $('.ff-form-load').addClass('hidden');
}

function showAndUpdateDiv(id, content) {
    if(content) {
        var $element = $("#" + id);
        if($element) {
            $element.closest('.form-group').removeClass('hidden');
            $element.text(content);
        }
    }
}

$(document).ready(function() {
    var $panel = $('#item-request-widget .panel');
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
                if(responseData.length === 1) {
                    $widget.closest('.form-group').hide();
                    selectedItem = responseData[0];
                    $('.single-item-info-group').removeClass('hidden');
                    $('#singleItemInfo').text(selectedItem.text);
                    if(selectedItem.delivery_options.includes('pickup')) { activateButton(papButton) }
                    if(selectedItem.delivery_options.includes('booksbymail')) { activateButton(bbmButton) }
                    if(selectedItem.delivery_options.includes('scandeliver')) { activateButton(sadButton) }
                } else {
                    $widget.select2({
                        theme: 'bootstrap',
                        placeholder: "Click here to make a selection",
                        width: "100%",
                        data: responseData
                    }).on('select2:open', function(e) {
                        $('.select2-search__field').attr('placeholder', 'Start typing to filter the list');
                    }).on('select2:select', function(e) {
                        resetRequestButtons();
                        selectedItemId = this.value;
                        selectedItem = responseData.find(function(item, index) {
                            if(item.id === selectedItemId) {
                                return item;
                            }
                        });
                        if(selectedItem.delivery_options.includes('pickup')) { activateButton(papButton) }
                        if(selectedItem.delivery_options.includes('booksbymail')) { activateButton(bbmButton) }
                        if(selectedItem.delivery_options.includes('scandeliver')) { activateButton(sadButton) }
                        if(!selectedItem.circulate) {
                            // show ill button
                            var illButton = $('#ill-request-button');
                            illButton.removeClass('hidden');
                            activateButton(illButton);
                        }
                        if(selectedItem.aeon_requestable) {
                            // show Aeon form link button
                            var aeonButton = $('#aeon-request-button');
                            aeonButton.removeClass('hidden');
                            activateButton(aeonButton);
                        }
                    });
                }
            });

        $('.request-button').on('click', function(e) {
            e.preventDefault();
            $("#confirm-modal").modal('show', $(this));
        });

        $('.ff-form-load').on('click', function(e) {
            e.preventDefault();
            var ffUrl = this.dataset.url;
            // TODO: add to URL with item info? volume, issue? from selectedItem?
            ffUrl.replace('__HOLDINGID__', selectedItem.holding_id);
            window.open(ffUrl, '_blank');
        })


        $('#confirm-modal').on('show.bs.modal', function(e) {
            var $modal = $(this)
            var $deliveryButton = e.relatedTarget;
            var option = $deliveryButton.val();
            updateModalHeader($modal, option);

            // show spinner?

            // load modal HTML via ajax
            $.get('/request/confirm', { method: option }, function(html) {
                $modal.find('.modal-body').empty().html(html);

                // set hidden fields
                $modal.find('#requestItemPid').val(selectedItem.id);
                $modal.find('#requestHoldingId').val(selectedItem.holding_id);
                $modal.find('#requestMmsId').val(mmsId);
                $modal.find('#requestDeliveryMethod').val(option);

                // set Item details
                //     showAndUpdateDiv('requestItemTitle', selectedItem.title);
                //     showAndUpdateDiv('requestItemDescription', selectedItem.description);
                //     showAndUpdateDiv('requestItemNote', selectedItem.publicNote);
                //     showAndUpdateDiv('requestItemDueDate', selectedItem.due_date);

            });
        });
    }
})

function updateDueDateDisplay(selectedItem) {
    var dueDateDisplay = $('#due-date-display');
    dueDateDisplay.closest('.form-group').removeClass('hidden');
    dueDateDisplay.text(selectedItem.due_date);
}

function deliveryNameFor(deliveryCode) {
    switch(deliveryCode) {
        case 'pap':
            return "Confirm PickUp @ Penn Request";
        case 'bbm':
            return "Confirm Books by Mail Request";
        case 'sad':
            return "Confirm Scan & Deliver Request";
    }
}

function updateModalHeader($modal, deliveryCode) {
    $modal.find('.modal-title').text(deliveryNameFor(deliveryCode));
}
