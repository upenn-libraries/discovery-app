
$(document).ready(function() {
    $('.catalog-anchor').click(function (event) {
        $('#bento-results-catalog .corner').removeClass('hide');
        $('#bento-results-catalog').animate({
            backgroundColor: "#f3f6ba"
        }, 1000 );

        resetOthers('catalog');

    });

    $('.articles-anchor').click(function (event) {
        $('#bento-results-summon .corner').removeClass('hide');
        $('#bento-results-summon').animate({
            backgroundColor: "#f3f6ba"
        }, 1000 );

        resetOthers('summon');

    });

    $('.databases-anchor').click(function (event) {
        $('#bento-results-databases .corner').removeClass('hide');
        $('#bento-results-databases').animate({
            backgroundColor: "#f3f6ba"
        }, 1000 );
        resetOthers('databases');
    });

    $('.website-anchor').click(function (event) {
        $('#bento-results-google .corner').removeClass('hide');
        $('#bento-results-google').animate({
            backgroundColor: "#f3f6ba"
        }, 1000 );
        resetOthers('google');
    });

    $('.bento-anchor').click(function (event) {
        resetOthers();
    });

});

function resetOthers(className = ''){
    classNames = ['catalog', 'summon', 'databases', 'google'];
    classNames.splice($.inArray(className, classNames), 1);

    $( classNames ).each(function() {
        $("#bento-results-" + this + " .corner").addClass('hide');
        $("#bento-results-" + this).animate({
            backgroundColor: "#ffffff"
        }, 1000 );
    });
}
