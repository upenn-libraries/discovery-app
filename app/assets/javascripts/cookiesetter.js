// TO USE: Create a bookmark containing this link:
// javascript:void($.getScript('http://localhost:3000/assets/cookiesetter.js'))

TEST_COOKIE_NAME='franklin-test-branch';

currentCookieVal=getCookie(TEST_COOKIE_NAME);
if (!currentCookieVal) {
  currentCookieVal='None';
}

modal='<div id="cookiemodal"><div class="cookiemodal-window">' +
        '<p>Current cookie: '+currentCookieVal+'</p>'+
        '<p>Select a feature branch to set a cookie:</p>' +
        '<select id="cookieselection">'+
          '<option value="none" selected disabled hidden>- Select a feature branch -</option>'+
          '<option value="branch1">branch1</option>'+
          '<option value="branch2">branch2</option>'+
          '<option value="branch3">branch3</option>'+
          '<option value="">Unset cookie</option>'+
        '</select>'+
        '<p><b>When you\'ve made your selection, refresh this page.</b></p>' +
        '</div></div>';

styles='<style>'+
'#cookiemodal {'+
'    position: fixed;'+
'    top: 0;'+
'    left: 0;'+
'    bottom: 0;'+
'    right: 0;'+
'    display: block;'+
'    overflow: auto;'+
'    background-color: #000000;'+
'    background-color: rgba(0, 0, 0, 0.7);'+
'    z-index: 9999;'+
'}'+
'.cookiemodal-window {'+
'    position: relative;'+
'    background-color: #FFFFFF;'+
'    width: 50%;'+
'    margin: 10% auto;'+
'    padding: 20px;'+
'}'+
'</style>';

document.body.innerHTML += styles + modal;

document.getElementById("cookieselection").onchange = function() {
  newCookie = document.getElementById("cookieselection").value;
  setCookie(TEST_COOKIE_NAME, newCookie, 1); //expires in 1 day
};

// Helper functions from https://www.w3schools.com/js/js_cookies.asp
function getCookie(cname) {
  var name = cname + "=";
  var decodedCookie = decodeURIComponent(document.cookie);
  var ca = decodedCookie.split(';');
  for(var i = 0; i <ca.length; i++) {
    var c = ca[i];
    while (c.charAt(0) == ' ') {
      c = c.substring(1);
    }
    if (c.indexOf(name) == 0) {
      return c.substring(name.length, c.length);
    }
  }
  return "";
}

function setCookie(cname, cvalue, exdays) {
  var d = new Date();
  d.setTime(d.getTime() + (exdays*24*60*60*1000));
  var expires = "expires="+ d.toUTCString();
  document.cookie = cname + "=" + cvalue + ";" + expires + ";path=/";
}
