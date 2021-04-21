function populateItemDebugWell(selectedItem) {
    $('#selected-item-debug').show().text('Debug Info: ' + JSON.stringify(selectedItem, null, 4));
}

function showAndEnableRequestButtons(selectedItem) {
    $('#print-request-button').prop('disabled', false).show();
    if(selectedItem.scannable) {
        $('#electronic-request-button').prop('disabled', false).show();
    }
    $('#aeon-request-button').prop('disabled', true).hide();
}

function showAndEnablePublicAeonButton() {
    $('#print-request-button').prop('disabled', true).hide();
    $('#electronic-request-button').prop('disabled', true).hide();
    $('#aeon-request-button').prop('disabled', false).show();
}

function hideRequestButtons() {
    $('.request-button').prop('disabled', true).hide();
}

function displayButtons(selectedItem, logged_in) {
    if(!selectedItem.aeon_requestable) {
        if(logged_in) {
            showAndEnableRequestButtons(selectedItem);
        } else {
            hideRequestButtons();
        }
    } else {
        showAndEnablePublicAeonButton();
    }
    populateItemDebugWell(selectedItem);
}

$(document).ready(function() {
    $('#selected-item-debug').hide();
    var $panel = $('#item-request-widget .panel');
    var $requestForm = $panel.find('#request-form')
    var $widget = $('#request-item-select');
    var logged_in =$('#requesting-logged-in').data('value')
    if($widget.length > 0) {
        var mmsId = $widget.data('mmsid');
        var responseData;
        var selectedItem;
        var selectedItemId;
        $requestForm.hide();
        $.ajax({
            url: '/alma/items/' + mmsId + '/all',
            dataType: 'json'
        }).done(function(data) {
            $panel.find('.panel-body').removeClass('spinner');
            $requestForm.show();
            responseData = data
            if(responseData.length === 1) {
                $widget.closest('.form-group').hide();
                selectedItem = responseData[0];
                displayButtons(selectedItem, logged_in);
            } else {
                $widget.select2({
                    theme: 'bootstrap',
                    placeholder: "Click here to make a selection",
                    width: "100%",
                    data: responseData
                }).on('select2:open', function(e) {
                    $('.select2-search__field').attr('placeholder', 'Start typing to filter the list');
                }).on('select2:select', function(e) {
                    selectedItemId = this.value;
                    selectedItem = responseData.find(function(item, index) {
                        if(item.id === selectedItemId) {
                            return item;
                        }
                    });
                    displayButtons(selectedItem, logged_in);
                });
            }
        });

        $('.request-button').on('click', function(e) {
            e.preventDefault();
            $("#confirm-modal").modal('show', $(this));
        });

        $('body')
            .on('click', '.delivery-option-radio', function(e) {
                var $radio = $(this);
                if($radio.val() === 'mail') {
                    $('#bbm_validation_checkbox').prop('disabled', false).focus();
                } else {
                    $('#bbm_validation_checkbox').prop('disabled', true);
                }
            })
            .on('ajax:beforeSend', '#confirm-modal form', function() {
                $('#confirm-modal .modal-body').empty().addClass('spinner')
            })
            .on('ajax:success', '#confirm-modal form', function(e, data) {
                $("#confirm-modal").empty().removeClass('spinner').html(data);
            })
            .on('click', '.input-toggleable', function(e) {
                e.preventDefault();
                var $this = $(this);
                $this.hide();
                $this.siblings('.toggle-field').show();
            });

        $('#confirm-modal').on('show.bs.modal', function(e) {
            var $modal = $(this);
            var $formatButton = e.relatedTarget;
            var format = $formatButton.val();

            var urlPart;
            var params = { mms_id: mmsId, holding_id: selectedItem.holding_id };
            var fulltextUrl = $('#electronic-request-button').data('fulltext-url');
            if(format === 'electronic') {
                params.volume = selectedItem.volume;
                params.issue = selectedItem.issue;
                urlPart = 'electronic';
            } else {
                if(selectedItem.circulate) {
                    params.available = selectedItem.in_place;
                    urlPart = 'circulate';
                } else {
                    if(selectedItem.aeon_requestable) {
                        urlPart = 'aeon';
                    } else {
                        urlPart = 'ill';
                    }
                }
            }

            // load modal HTML via ajax
            $.get('/request/confirm/' + urlPart, params, function(html) {
                // $modal.find('.modal-body').empty().html(html);
                $modal.empty().html(html);

                // set hidden fields
                $modal.find('#requestItemPid').val(selectedItem.id);
                $modal.find('#requestHoldingId').val(selectedItem.holding_id);
                $modal.find('#requestMmsId').val(mmsId);

                // set Item details TODO: what if description is empty? :(
                $('#selection').val(selectedItem.description);

                // set Fulltext link if possible
                if(fulltextUrl) { $('#fulltext-link').attr('href', fulltextUrl).closest('div#online-access-div').show(); }
            });
        });

        $.getJSON('/request/options?mms_id=' + mmsId, function(data) {
            var $showTools = $('.show-tools .panel-body ul.nav');
            var ares_url = data['ARES'];
            var enhance_url = data['ENHANCED'];
            if(ares_url) {
                $showTools.append($('<li><a target="_blank" href="'+ ares_url +'">Place on Course Reserve</a></li>'));
            }
            if(enhance_url) {
                $showTools.append($('<li><a target="_blank" href="'+ enhance_url +'">Report Cataloging Error</a></li>'));
            }
        });
    }
})
