$(document).ready(function() {
    var $expert;
    var hide_help;
    $expert = $('#ExpertOptions');
    hide_help = document.cookie.includes('franklin_hide_expert_help=true');

    if (window.matchMedia("(min-width: 992px)").matches && !hide_help) {
      $expert.collapse('show');
    }

    $expert.on('hide.bs.collapse', function() {
        document.cookie = 'franklin_hide_expert_help=true;path=/'
    });

    $expert.on('show.bs.collapse', function() {
        document.cookie = 'franklin_hide_expert_help=;path=/;max-age=0'
    });
});
