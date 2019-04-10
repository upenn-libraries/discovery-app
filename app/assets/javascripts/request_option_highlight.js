$(document).ready(function() {
    $('body').on('click','.request-option-link', function(event) {
        let table = $(event.target).closest('div[id^=table-wrapper')
        table.find('button.highlightable').each(function() {
          $(this).parent().addClass('highlighted');
          $(this).animate({backgroundColor: '#f3f6ba'}, 1000);
        });
    });
});
