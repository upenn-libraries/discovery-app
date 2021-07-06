


// /**
//  * Adds the dropdown hover effects on the Franklin header
//  */
// $(document).ready(function() {
//
$(document).ready(function() {

  var timeout;
  function toggleMenuOn() {
    $('.dropdown-help').addClass('visible');
    $('#header-navbar').addClass('nav-expanded');
    $('#desktop-franklin-help').addClass('hover');
    $('#desktop-franklin-help').attr("aria-expanded","true");
    $('.accessibility_button.expand_button').addClass('button_expanded');
    $('.accessibility_button.expand_button').text('Hide submenu');
  }

  function toggleMenuOff() {
    $('.dropdown-help').removeClass('visible');
    $('#header-navbar').removeClass('nav-expanded');
    $('#desktop-franklin-help').removeClass('hover');
    $('#desktop-franklin-help').attr("aria-expanded","false");
    $('.accessibility_button.expand_button').text('Show submenu');
    $('.accessibility_button.expand_button').removeClass('button_expanded');
  }

  $('#li-desktop-franklin-help').hover(function(){
        clearTimeout(timeout);
        toggleMenuOn();
    },
      function() {
        timeout = setTimeout(function(){
          toggleMenuOff();
        }, 500);
    });

  $('.accessibility_button.expand_button').on("click", function() {
    if($(this).hasClass('button_expanded')) {
      toggleMenuOff();
    }
    else {
      toggleMenuOn();
    }
  });
});
