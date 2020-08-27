$(document).ready(function() {
    var hide_help;
    hide_help = document.cookie.includes('franklin_hide_expert_help=true');
    if (window.matchMedia("(min-width: 992px)").matches && !hide_help) {
      $('#ExpertOptions').collapse('show');
    }
});
