$(document).ajaxComplete(function() {
    if($("#bento-results-databases .bento-item").length == 0 && $('.gs-no-results-result').length){
        $('#bento-results-catalog').addClass('fifty-percent')
        $('#bento-results-summon').addClass('fifty-percent')
    }
});