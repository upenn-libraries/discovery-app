function populateItemDebugWell($panelBody, selectedItem) {
    $panelBody.find('.selected-item-debug').show().text('Debug Info: ' + JSON.stringify(selectedItem, null, 4));
}

function showAndEnableRequestButtons($panelBody, selectedItem) {
    $panelBody.find('.print-request-button').prop('disabled', false).show();
    if(selectedItem.scannable) {
        $panelBody.find('.electronic-request-button').prop('disabled', false).show();
    }
    $panelBody.find('.aeon-request-button').prop('disabled', true).hide();
}

function showAndEnablePublicAeonButton($panelBody) {
    $panelBody.find('.print-request-button').prop('disabled', true).hide();
    $panelBody.find('.electronic-request-button').prop('disabled', true).hide();
    $panelBody.find('.aeon-request-button').prop('disabled', false).show();
}

function showDisabledRequestButtons($panelBody) {
    $panelBody.find('.print-request-button').prop('disabled', true).show();
    $panelBody.find('.electronic-request-button').prop('disabled', true).show();
    $panelBody.find('.aeon-request-button').prop('disabled', false).hide();
}

function displayButtons($panelBody, selectedItem, logged_in, context) {
    if(!selectedItem.aeon_requestable) {
        if(logged_in) {
            showAndEnableRequestButtons($panelBody, selectedItem);
        } else {
            showDisabledRequestButtons($panelBody);
        }
    } else {
        showAndEnablePublicAeonButton($panelBody);
    }

    if (context === 'show') { populateItemDebugWell($panelBody, selectedItem) }
}

function initializeRequestingWidget($panelBody, context) {
    $('.selected-item-debug').hide();
    var $requestForm = $panelBody.find('.request-form')
    var $widget = $panelBody.find('.request-item-select');
    var logged_in = $('#requesting-logged-in').data('value')
    if($widget.length > 0) {
        var mmsId = $widget.data('mmsid');
        var responseData;
        var selectedItem;
        $requestForm.hide();
        var itemCount = $widget.data('item_count');
        var emptyHoldingCount = $widget.data('empty_holding_count');
        // TODO: move to function, e.g.:
        // var itemRequestUrl = calculateItemRequestUrl(itemCount, emptyHoldingCount)
        var itemRequestUrl = '/alma/items/' + mmsId + '/all';
        if(itemCount || emptyHoldingCount) {
            itemRequestUrl += '?'
        }
        if(itemCount) {
            itemRequestUrl += $.param({ item_count: itemCount })
        }
        if(emptyHoldingCount) {
            itemRequestUrl += $.param({ empty_holding_count: emptyHoldingCount })
        }
        $.ajax({
            url: itemRequestUrl,
            dataType: 'json'
        }).done(function(data) {
            $panelBody.removeClass('spinner');
            $requestForm.show();
            responseData = data
            if(responseData.length === 1) {
                // single iem case - avoid instantiating select2 widget
                $widget.closest('.form-group').hide();
                selectedItem = responseData[0];
                $widget.data(selectedItem);
                displayButtons($panelBody, selectedItem, logged_in, context);
            } else {
                $widget.select2({
                    theme: 'bootstrap',
                    placeholder: "Click here to select an item",
                    width: "100%",
                    data: responseData
                }).on('select2:open', function(e) {
                    $('.select2-search__field').attr('placeholder', "Start typing to filter the list");
                }).on('select2:select', function(e) {
                    selectedItem = e.params.data;
                    displayButtons($panelBody, selectedItem, logged_in, context);
                });
            }
            $panelBody.addClass('loaded');
        });

        if(context === 'show') {
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
    }
}

$(document).ready(function() {
    var $body = $('body');
    var context;
    if(document.body.classList.contains("blacklight-catalog-show")) {
        var $panelBody = $('.item-request-widget');
        context = 'show';
        initializeRequestingWidget($panelBody, context);
    } else if(document.body.classList.contains("blacklight-catalog-index")) {
        context = 'index';
        $body.on('click', '.btn-get-it', function(e){
            e.preventDefault();
            var mms_id = $(this).data('mms-id');
            if(mms_id) {
                var id = '#item-request-widget-for-' + mms_id;
                var $widget = $(id);
                if($widget && !$widget.hasClass('loaded')) {
                    initializeRequestingWidget($widget, context);
                }
                var $otherWidgets = $('.item-request-widget:not(' + id + ')');
                $otherWidgets.hide();
                $widget.slideToggle(200);
            }

        });
    }

    // trigger display of modal upon clicking a request button
    $('.request-button').on('click', function(e) {
        e.preventDefault();
        $("#confirm-modal").modal('show', $(this));
    });

    // bind events to dynamically created elements
    $body
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

    // do stuff upon display of modal window
    $('#confirm-modal').on('show.bs.modal', function(e) {
        var selectedItem;
        var $modal = $(this);
        $modal.empty();
        var triggeringButton = e.relatedTarget;
        var $widget = triggeringButton.closest('form').find('.request-item-select')
        // get selected item from 'widget'
        if($widget.hasClass('select2-hidden-accessible')) {
            selectedItem = $widget.select2('data')[0];
        } else {
            selectedItem = $widget.data();
        }
        var mmsId = $widget.data('mmsid');
        var format = triggeringButton.val();
        var urlPart;
        var params = { mms_id: mmsId, holding_id: selectedItem.holding_id };
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
            $modal.html(html)
            // set hidden fields
            $modal.find('#requestItemPid').val(selectedItem.id);
            $modal.find('#requestHoldingId').val(selectedItem.holding_id);
            $modal.find('#requestMmsId').val(mmsId);

            // set Item details
            $modal.find('#title').val(selectedItem.title);
            if(selectedItem.description) {
                $modal.find('#selection').val(selectedItem.description);
            } else {
                $modal.find('#selection').closest('.form-group').hide();
            }
        });
    });
})
