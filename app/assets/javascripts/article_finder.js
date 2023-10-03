
$(document).ready(function () {

    var articleFinderUrl = 'https://hdl.library.upenn.edu/1017/25333';

    // we set href too for cleanliness
    $('.article-finder-link')
        .attr("href", articleFinderUrl)
        .click(function (event) {
            event.preventDefault();
            window.open(articleFinderUrl,
                "librarieswindow",
                "toolbar=no,width=900,height=900,status=no,scrollbars=yes,resizable=yes,menubar=no,alwaysRaised=yes,accessKey=1");
        });

});
