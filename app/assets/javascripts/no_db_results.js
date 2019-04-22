$(document).ajaxComplete(function() {
    if ($('.gs-no-results-result').length) {
        $('#bento-results-google').addClass('hidden');
    }
});