window.ST = window.ST || {};

(function (module) {

    module.initializeFromToDatePicker = function (rangeCongainerId) {
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
                        return booking_date_array.indexOf(date) >= 0 ? 'disabled': 0;
                    },
                    rtl: dateRage.css("direction") == "rtl"
                };

                if (dateLocale !== 'en') {
                    options.language = dateLocale;
                }

                var picker = dateRage.datepicker(options);

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
