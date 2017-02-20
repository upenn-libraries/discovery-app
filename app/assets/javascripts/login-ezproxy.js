$(document).ready(function() {

    // if there exist elements with the ezproxy-login-status class,
    // then check status.... and add some classes to parts of the subtree
    // according to whether user is logged in or not.

    if($(".ezproxy-login-status").length > 0) {
        var LOGIN = require('ezproxy-login-status');
        var module = LOGIN.getModule('ezproxyStatus');
        module.setURL("https://proxy.library.upenn.edu/login?url=http://127.0.0.1:8080/");
        //module.setLoggedOutPingIntervalSeconds(60);
        //module.setLoggedInPingIntervalSeconds(60);
        //module.setTimeoutMillis(2000); // to determine a failed jsonp authentication request

        // add classes to summon-results container instead of alert link

        module.addOnLoggedIn('main', function(data){
            $(".ezproxy-login-status").addClass("ezproxy-is-logged-in");
        });
        module.addOnNotLoggedIn('main', function(){
            $(".ezproxy-login-status").addClass("ezproxy-is-not-logged-in");
        });
        module.init();

        $(".ezproxy-login-status").on("click", ".ezproxy-login-link", function() {
            module.loginOnclick();
        });
    }
});
