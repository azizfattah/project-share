$(document).ready(function () {
    $('#checkout_button_transaction').click(function () {
        if( $('#message').val().length > 0){
            $('body').waitMe({
                effect: 'win8',
                text: '',
                color: '#000',
            });
        }

    });
});