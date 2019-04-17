$(document).ajaxComplete(function() {
    if ($('.gs-no-results-result').length) {
        $('#bento-results-google .view-all').addClass('hidden');
    }
});