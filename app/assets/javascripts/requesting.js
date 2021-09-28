function showAndEnableRequestButtons($widgetArea, selectedItem) {
    $widgetArea.find('.print-request-button').prop('disabled', false).show();
    if(selectedItem.scannable) {
        $widgetArea.find('.electronic-request-button').prop('disabled', false).show();
    }
    $widgetArea.find('.aeon-request-button').prop('disabled', true).hide();
}

function showAndEnablePublicAeonButton($widgetArea) {
    $widgetArea.find('.print-request-button').prop('disabled', true).hide();
    $widgetArea.find('.electronic-request-button').prop('disabled', true).hide();
    $widgetArea.find('.aeon-request-button').prop('disabled', false).show();
}

function showDisabledRequestButtons($widgetArea) {
    $widgetArea.find('.print-request-button').prop('disabled', true).show();
    $widgetArea.find('.electronic-request-button').prop('disabled', true).show();
    $widgetArea.find('.aeon-request-button').prop('disabled', false).hide();
}

function displayButtons($widgetArea, selectedItem, logged_in, context) {
    if(!selectedItem.aeon_requestable) {
        if(logged_in) {
            showAndEnableRequestButtons($widgetArea, selectedItem);
        } else {
            showDisabledRequestButtons($widgetArea);
        }
    } else {
        showAndEnablePublicAeonButton($widgetArea);
    }
}

function calculateItemRequestUrl(mmsId, itemCount, emptyHoldingCount) {
    var itemRequestUrl = '/alma/items/' + mmsId + '/all';

    if(itemCount || emptyHoldingCount) {
        var urlParams = new URLSearchParams({
            item_count: itemCount,
            empty_holding_count: emptyHoldingCount
        });
        return itemRequestUrl + '?' + urlParams.toString();
    } else {
        return itemRequestUrl
    }
}

function initializeRequestingWidget($widgetArea, context) {
    $('.selected-item-debug').hide();
    var $requestForm = $widgetArea.find('.request-form')
    var $widget = $widgetArea.find('.request-item-select');
    var logged_in = $('#requesting-logged-in').data('value')
    if($widget.length > 0) {
        var mmsId = $widget.data('mmsid');
        var responseData;
        var selectedItem;
        $requestForm.hide();
        var itemCount = $widget.data('itemCount');
        var emptyHoldingCount = $widget.data('emptyHoldingCount');
        var itemRequestUrl = calculateItemRequestUrl(mmsId, itemCount, emptyHoldingCount);
        $.ajax({
            url: itemRequestUrl,
            dataType: 'json'
        }).done(function(data) {
            $widgetArea.removeClass('spinner');
            $requestForm.show();
            responseData = data
            if(!responseData) {
                $widgetArea.html('<div class="alert alert-danger requesting-widget-error-alert">Failed to load any items for this record - refresh the page and try again.</div>');
            } else {
                if (responseData.length === 1) {
                    // single item case - avoid instantiating select2 widget
                    $widget.closest('.form-group').hide();
                    selectedItem = responseData[0];
                    $widget.data(selectedItem);
                    displayButtons($widgetArea, selectedItem, logged_in, context);
                } else {
                    $widget.select2({
                        theme: 'bootstrap',
                        placeholder: "Click here to see all Items",
                        width: "100%",
                        data: responseData
                    }).on('select2:open', function (e) {
                        $('.select2-search__field').attr('placeholder', "Type a year, issue or volume number to filter the list");
                    }).on('select2:select', function (e) {
                        selectedItem = e.params.data;
                        displayButtons($widgetArea, selectedItem, logged_in, context);
                    });
                }
            }
            $widgetArea.addClass('loaded');
            // srt focus to first button - triggers tooltip :/
            // $widgetArea.find('button:first').focus();
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
    $('.tooltip-wrapper').tooltip(); // activate tooltips
    var context;
    if(document.body.classList.contains("blacklight-catalog-show")) {
        var $widgetArea = $('.item-request-widget');
        context = 'show';
        initializeRequestingWidget($widgetArea, context);
    } else if(document.body.classList.contains("blacklight-catalog-index")) {
        context = 'index';
        $body.on('click', '.btn-get-it', function(e){
            e.preventDefault();
            var $button = $(this);
            var mms_id = $button.data('mms-id');
            if(mms_id) {
                var id = '#item-request-widget-for-' + mms_id;
                var $widget = $(id);
                var $caret = $button.find('span.getit-caret');
                if($widget && !$widget.hasClass('loaded')) {
                    initializeRequestingWidget($widget, context);
                }
                $widget.slideToggle(200);
                if($caret.hasClass('glyphicon-chevron-up')) {
                    $button.attr('aria-expanded', false);
                    $caret.removeClass('glyphicon-chevron-up').addClass('glyphicon-chevron-down');
                } else if($caret.hasClass('glyphicon-chevron-down')) {
                    $button.attr('aria-expanded', true);
                    $caret.removeClass('glyphicon-chevron-down').addClass('glyphicon-chevron-up');
                }

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
            var $bbm_checkbox = $('#bbm_validation_checkbox');
            var $chd_checkbox = $('#chd_validation_checkbox');
            if ($radio.val() === 'mail') {
                $bbm_checkbox.prop('disabled', false).focus();
                $bbm_checkbox.closest('div.checkbox').removeClass('disabled');
                $chd_checkbox.prop('disabled', true);
                $chd_checkbox.closest('div.checkbox').addClass('disabled');
            } else if ($radio.val() === 'college_house') {
                $chd_checkbox.prop('disabled', false).focus();
                $chd_checkbox.closest('div.checkbox').removeClass('disabled');
                $bbm_checkbox.prop('disabled', true);
                $bbm_checkbox.closest('div.checkbox').addClass('disabled');
            } else {
                $chd_checkbox.prop('disabled', true);
                $chd_checkbox.closest('div.checkbox').addClass('disabled');
                $bbm_checkbox.prop('disabled', true);
                $bbm_checkbox.closest('div.checkbox').addClass('disabled');
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
        $('[data-toggle="tooltip"]').tooltip('hide'); // hide tooltips
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
            $modal.find('#requestIsxn').val(selectedItem.isxn);

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
