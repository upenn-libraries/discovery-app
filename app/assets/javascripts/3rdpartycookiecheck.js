$(document).ready(function() {
  var receiveMessage = function (evt) {
    if (evt.data === 'MM:3PCunsupported') {
      flashContainer = document.getElementsByClassName('flash_messages')[0];
      if(flashContainer) {
        flashContainer.innerHTML += " \
          <div class='alert alert-danger'> \
            NOTE: 3rd party cookies are disabled. \
            <a class='close' data-dismiss='alert' href='#'>×</a> \
          </div>";
      }
    }
  };
  window.addEventListener("message", receiveMessage, false);
});
