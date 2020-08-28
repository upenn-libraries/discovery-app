$(document).ready(function() {
    var $expert;
    $expert = $('#ExpertOptions');

    if (window.matchMedia("(min-width: 992px)").matches &&
        !document.cookie.includes('franklin_hide_expert_help=true')) {
      $expert.collapse('show');
    } else {
      $expert.collapse('hide');
    }

    $expert.on('hide.bs.collapse', function() {
        document.cookie = 'franklin_hide_expert_help=true;path=/'
    });

    $expert.on('show.bs.collapse', function() {
        document.cookie = 'franklin_hide_expert_help=;path=/;max-age=0'
    });
});
