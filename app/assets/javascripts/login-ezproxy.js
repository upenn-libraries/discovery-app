$(document).ready(function() {

    var SUMMON_ROLE_AUTH_HEADER_NAME = "x-summon-role-auth";
    var PROXY_PREPEND = "https://proxy.library.upenn.edu/login?url=";


    function clearLoggedInClasses() {
        $(".ezproxy-login-status").removeClass("ezproxy-is-logged-in ezproxy-is-not-logged-in");
    }

    // if there exist elements with the ezproxy-login-status class,
    // then check status.... and add some classes to parts of the subtree
    // according to whether user is logged in or not.

    if ($(".ezproxy-login-status").length > 0) {
        var LOGIN = require('ezproxy-login-status');
        var module = LOGIN.getModule('ezproxyStatus');
        module.setURL(PROXY_PREPEND + "https://127.0.0.1:8080/");
        //module.setLoggedOutPingIntervalSeconds(60);
        //module.setLoggedInPingIntervalSeconds(60);
        //module.setTimeoutMillis(2000); // to determine a failed jsonp authentication request

        var loginStatusDiv = $(".ezproxy-login-status");
        module.addOnLoggedIn('main', function (data) {
            clearLoggedInClasses();
            loginStatusDiv.addClass("ezproxy-is-logged-in");
        });
        module.addOnNotLoggedIn('main', function () {
            clearLoggedInClasses();
            loginStatusDiv.addClass("ezproxy-is-not-logged-in");
        });

        // first ("fail") param undefined (handled by BentoSearch)
        // last ("instance") param is window; we don't care about "this", so global scope
        module.requestSubmit(undefined, function (fail, auth) {
            var beforeSend = undefined;
            if (auth !== null && auth !== undefined) {
                beforeSend = function beforeSend(xhr, settings) {
                    xhr.setRequestHeader(SUMMON_ROLE_AUTH_HEADER_NAME, auth.iv + ';' + auth.ciphertext);
                };
            }
            BentoSearch.ajax_load(loginStatusDiv.children(".bento_search_ajax_wait"), function (div) {
                // set the login link with proper redirect
                var currentUrl = window.location.href;
                var proxyUrl = PROXY_PREPEND + 'http://127.0.0.1:8082/?redirect=' + encodeURIComponent(currentUrl);
                $(div).find(".ezproxy-login-link").attr("href", proxyUrl);

                if (auth !== null && auth !== undefined && auth.loggedIn) {
                    $(div).find(".view-and-filter").find("a").each(function (idx, element) {
                        // ezproxy handles url param specifically so we don't need to escape it
                        var viewAndFilterUrl = $(element).attr("href");
                        $(element).attr("href", PROXY_PREPEND + viewAndFilterUrl);
                    });
                }

            }, beforeSend);
        }, window);

        module.init();

        loginStatusDiv.on("click", ".ezproxy-login-link", function () {
            module.loginOnclick();
        });
    }
});
