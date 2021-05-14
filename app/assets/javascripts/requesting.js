function populateItemDebugWell($panel, selectedItem) {
    $panel.find('.selected-item-debug').show().text('Debug Info: ' + JSON.stringify(selectedItem, null, 4));
}

function showAndEnableRequestButtons($panel, selectedItem) {
    $panel.find('.print-request-button').prop('disabled', false).show();
    if(selectedItem.scannable) {
        $panel.find('.electronic-request-button').prop('disabled', false).show();
    }
    $panel.find('.aeon-request-button').prop('disabled', true).hide();
}

function showAndEnablePublicAeonButton($panel) {
    $panel.find('.print-request-button').prop('disabled', true).hide();
    $panel.find('.electronic-request-button').prop('disabled', true).hide();
    $panel.find('.aeon-request-button').prop('disabled', false).show();
}

function showDisabledRequestButtons($panel) {
    $panel.find('.print-request-button').prop('disabled', true).show();
    $panel.find('.electronic-request-button').prop('disabled', true).show();
    $panel.find('.aeon-request-button').prop('disabled', false).hide();
}

function displayButtons($panel, selectedItem, logged_in, context) {
    if(!selectedItem.aeon_requestable) {
        if(logged_in) {
            showAndEnableRequestButtons($panel, selectedItem);
        } else {
            showDisabledRequestButtons($panel);
        }
    } else {
        showAndEnablePublicAeonButton($panel);
    }

    if (context === 'show') { populateItemDebugWell($panel, selectedItem) }
}

function initializeRequestingWidget($panel, context) {
    $('.selected-item-debug').hide();
    var $requestForm = $panel.find('.request-form')
    var $widget = $panel.find('.request-item-select');
    var logged_in = $('#requesting-logged-in').data('value')
    if($widget.length > 0) {
        var mmsId = $widget.data('mmsid');
        var responseData;
        var selectedItem;
        $requestForm.hide();
        $.ajax({
            url: '/alma/items/' + mmsId + '/all',
            dataType: 'json'
        }).done(function(data) {
            $panel.find('.panel-body').removeClass('spinner');
            $requestForm.show();
            responseData = data
            if(responseData.length === 1) {
                // single iem case - avoid instantiating select2 widget
                $widget.closest('.form-group').hide();
                selectedItem = responseData[0];
                $widget.data(selectedItem);
                displayButtons($panel, selectedItem, logged_in, context);
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
                    displayButtons($panel, selectedItem, logged_in, context);
                });
            }
            $panel.addClass('loaded');
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
    var context;
    if(document.body.classList.contains("blacklight-catalog-show")) {
        var $panel = $('.item-request-widget .panel');
        context = 'show';
        initializeRequestingWidget($panel, context);
    } else if(document.body.classList.contains("blacklight-catalog-index")) {
        context = 'index';
        $('body').on('click', '.btn-get-it', function(e){
            var mms_id = $(this).data('mms-id');
            if(mms_id) {
                var id = '#item-request-widget-for-' + mms_id;
                var $widget = $(id);
                if($widget && !$widget.hasClass('loaded')) {
                    initializeRequestingWidget($widget, context);
                }
                var $otherWidgets = $('.item-request-widget:not(' + id + ')');
                $otherWidgets.hide();
                $widget.toggle();
            }

        });
    }

    // bindings for request modal window activities


    // trigger display of modal upon clicking a request button
    $('.request-button').on('click', function(e) {
        e.preventDefault();
        $("#confirm-modal").modal('show', $(this));
    });

    // bind events to dynamically created elements
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

    // do stuff upon display of modal window
    $('#confirm-modal').on('show.bs.modal', function(e) {
        var selectedItem;
        var $modal = $(this);
        var triggeringButton = e.relatedTarget;
        var $widget = triggeringButton.closest('form').find('.request-item-select')
        if($widget.hasClass('select2-hidden-accessible')) {
            selectedItem = $widget.select2('data')[0];
        } else {
            selectedItem = $widget.data();
        }
        var mmsId = $widget.data('mmsid');
        $modal.empty();
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
            if(selectedItem.description) {
                $('#selection').val(selectedItem.description);
            } else {
                $('#selection').closest('.form-group').hide();
            }
        });
    });
})
