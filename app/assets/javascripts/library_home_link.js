
$(document).ready(function() {
    // TODO: brought over verbatim from DLA franklin; replace with a jquery plugin or something else
    function readCookie(name) {
        var nameEQ = name + "=";
        var ca = document.cookie.split(';');
        for(var i=0;i<  ca.length;i++) {
            var c = ca[i];
            while (c.charAt(0)==' ') {
                c = c.substring(1,c.length);
            }
            if (c.indexOf(nameEQ) == 0) {
                return c.substring(nameEQ.length,c.length);
            }
        }
        return "";
    }

    var hp = readCookie('hp');
    if(hp && hp.length > 0) {
        $('.library-home-link').each(function(idx, element) {
            $(element).attr("href", "http://www.library.upenn.edu" + hp);
        });
    }
});
