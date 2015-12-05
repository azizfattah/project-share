window.ST = window.ST || {};

(function (module) {

    module.initializeFromToDatePicker = function (rangeCongainerId, price_tags, default_price) {
        var now = new Date();
        var today = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
        var dateRage = $('#' + rangeCongainerId);
        var dateLocale = dateRage.data('locale');

        var options = {}
           booking_date_array=[];

        $.ajax({
            url: "listings/listing_booking_date",
            type: "GET",
            dataType: "json",
            success: function (date) {
                booking_date_array = date.data
                options = {
                    startDate: today,
                    inputs: [$("#start-on"), $("#end-on")],

                    beforeShowDay: function (date) {
                        date = getFormattedDate(date)
                        var options = {}
                        var current_price_date = jQuery.grep(price_tags, function(price_tag){
                            return (price_tag.date == date)
                        });

                        if(booking_date_array.indexOf(date) >= 0){
                            options['enabled'] = false
                        }else if(current_price_date.length > 0){
                            price_tag = current_price_date[0];
                            if (price_tag.available){
                                options['tooltip'] = price_tag.price;
                                options['classes'] = 'price-tooltip';
                            } else{
                                options['enabled'] = false;
                            };
                        }else{
                            options['tooltip'] = default_price;
                            options['classes'] = 'price-tooltip';

                        }
                        return options;
                    },
                    rtl: dateRage.css("direction") == "rtl"
                };

                if (dateLocale !== 'en') {
                    options.language = dateLocale;
                }

                var picker = dateRage.datepicker(options)
                    .on("show", function(e){
                        $('.price-tooltip').tooltipster();
                });

                var outputElements = {
                    "booking-start-output": $("#booking-start-output"),
                    "booking-end-output": $("#booking-end-output")
                };

                picker.on('changeDate', function (e) {
                    var newDate = e.dates[0];
                    var outputElementId = $(e.target).data("output");
                    var outputElement = outputElements[outputElementId];
                    outputElement.val(module.utils.toISODate(newDate));
                });

                function getFormattedDate(date) {
                    var year = date.getFullYear();
                    var month = (1 + date.getMonth()).toString();
                    month = month.length > 1 ? month : '0' + month;
                    var day = date.getDate().toString();
                    day = day.length > 1 ? day : '0' + day;
                    return year + '-' + month + '-' + day;
                }

            },
            error: function () {
                alert("Ajax error!,Please reload the page.")
            }
        });


    };
})(window.ST);
