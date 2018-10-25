(function() {
  var receiveMessage = function (evt) {
    if (evt.data === 'MM:3PCunsupported') {
      flashContainer = document.getElementsByClassName('flash_messages')[0];
      if(flashContainer) {
        flashContainer.innerHTML += " \
          <div class='alert alert-danger'> \
            It looks like you have third-party cookies disabled, which will prevent you from placing requests in this catalog. Click <a href='https://guides.library.upenn.edu/franklincatalog/third-party-cookies' target='_blank'>here</a> for information on configuring your browser. \
            <a class='close' data-dismiss='alert' href='#'>×</a> \
          </div>";
      }
    }
  };
  window.addEventListener("message", receiveMessage, false);
})();
