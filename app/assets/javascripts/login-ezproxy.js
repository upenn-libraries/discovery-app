$(document).ready(function() {

    function clearLoggedInClasses() {
        $(".ezproxy-login-status").removeClass("ezproxy-is-logged-in ezproxy-is-not-logged-in");
    }

    // if there exist elements with the ezproxy-login-status class,
    // then check status.... and add some classes to parts of the subtree
    // according to whether user is logged in or not.

    if($(".ezproxy-login-status").length > 0) {
        var LOGIN = require('ezproxy-login-status');
        var module = LOGIN.getModule('ezproxyStatus');
        module.setURL("https://proxy.library.upenn.edu/login?url=https://127.0.0.1:8080/");
        //module.setLoggedOutPingIntervalSeconds(60);
        //module.setLoggedInPingIntervalSeconds(60);
        //module.setTimeoutMillis(2000); // to determine a failed jsonp authentication request

        module.addOnLoggedIn('main', function(data){
            clearLoggedInClasses();
            $(".ezproxy-login-status").addClass("ezproxy-is-logged-in");
        });
        module.addOnNotLoggedIn('main', function(){
            clearLoggedInClasses();
            $(".ezproxy-login-status").addClass("ezproxy-is-not-logged-in");
        });
        module.init();

        $(".ezproxy-login-status").on("click", ".ezproxy-login-link", function() {
            module.loginOnclick();
        });
    }
});
