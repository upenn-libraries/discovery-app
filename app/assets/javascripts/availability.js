$(document).ready(function() {

    // subclass BlacklightAlma
    function Franklin() {
        BlacklightAlma.call(this);
    }

    Franklin.prototype = Object.create(BlacklightAlma.prototype);

    Franklin.prototype.formatHolding = function (holding) {
        if (holding['inventory_type'] == 'physical') {
            var availability = "Unknown";
            if(holding['availability'] == 'check_holdings') {
                availability = "Check holdings";
            } else if(holding['availability'] == 'unavailable') {
                availability = "Requestable";
            } else if(holding['availability'] == 'available') {
                availability = "Available";
            }
            return [availability, holding['location'], holding['call_number']]
                .filter(function (item) {
                    return item != null && item.length > 0;
                }).join(". ");
        } else {
            return BlacklightAlma.prototype.formatHolding.call(this, holding);
        }
    };

    var ba = new Franklin();
    ba.loadAvailability();
});
