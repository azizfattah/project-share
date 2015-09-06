window.ST = window.ST || {};

/**
  Initialize range slider filter

  ## Params:

  - `selector`: Selector
  - `range`: [min, max] array
  - `start`: [startValueMin, startValueMax]
  - `labels`: [labelElementMin, labelElementMax]
  - `fields`: [inputFieldMin, inputFieldMax]
  - `decimals: boolean allow decimals
*/

window.ST.rangeFilter = function(selector, range, start, labels, fields, decimals) {

  function decimalPlaces(number) {
    // The ^-?\d*\. strips off any sign, integer portion, and decimal point
    // leaving only the decimal fraction.
    return ((+number).toString()).replace(/^-?\d*\.?/g, '').length;
  }

  function numberOfDecimals(){
    if(decimals){
      var num_of_decimals = Math.max.apply(null, range.map(decimalPlaces));
      return 1 / Math.pow(10, num_of_decimals);
    }else{
      return 1;
    }
  }

  function updateLabel(el) {
    return function(val) {
      el.html(val);
    };
  }


  var step = numberOfDecimals();
  var slider = $(selector)[0];

  noUiSlider.create(slider, {
    range: range,
    step: step,
    start: [start[0], start[1]],
    connect: true,
    direction: $("body").css("direction")
  });

  slider.noUiSlider.on('update', function ( values, handle ) {
    if ( !handle ) {
      $(labels[0]).html(values[handle]);
    } else {
      $(labels[1]).html(values[handle]);
    }
  });
};
