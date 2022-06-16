
/**
 * jQuery function that works without a selector, e.g. you can call $.shelfLocationLink();
 * Packaging the code this way provides an isolated namespace for storing shelf locator code.
 *
 * This can probably be simplified; it was brought over from DLA Franklin with mostly minor clean-up.
 **/
jQuery.shelfLocatorLink = new function() {

    var intRegex = /[0-9 -()+]+$/;

    // note that location names here must be kept in sync with Alma, otherwise it won't work
    var locationsToTargetsVP = [
        {"v": "Africana Studies Resource Room", "tg": "ASRR"},
        {"v": "Bestsellers Collection", "tg": "BC"},
        {"v": "Classics Resource Room", "tg": "CRR"},
        {"v": "East Asia Collection", "tg": "EAC"},
        {"v": "East Asia Compact Shelving", "tg": "EACS"},
        {"v": "East Asia Seminar Room", "tg": "EASR"},
        {"v": "Judaica and Ancient Near East Resource Room", "tg": "JANERR"},
        {"v": "Marian Anderson Music Study Center", "tg": "MAMSC"},
        {"v": "Marian Anderson Study Center Reserve", "tg": "MAMSC"},
        {"v": "Medieval Studies Resource Room", "tg": "MSRR"},
        {"v": "Microtext", "tg": "MICRO"},
        {"v": "Middle East Seminar Reserve", "tg": "MESR"},
        {"v": "Middle East Seminar Room", "tg": "MESR"},
        {"v": "Music Library New Book Shelf", "tg": "MLNBS"},
        {"v": "New Book Display", "tg": "NBD"},
        {"v": "Ormandy", "tg": "OC"},
        {"v": "Rosengarten Reserve", "tg": "RR"},
        {"v": "South Asia Studies Reading Room", "tg": "SAS"},
        {"v": "South Asian Reserve", "tg": "SAS"},
        {"v": "Video Collection", "tg": "VC"},
        {"v": "Weigle Information Commons Reference", "tg": "WICR"},
        {"v": "Yarnall Collection", "tg": "YC"},
        {"v": "Lippincott Library", "tg": "LL"},
        {"v": "Judaica/Ancient", "tg": "JANERR"},
        {"v": "East Asia", "tg": "EAC"},
        {"v": "South Asia Reserve", "tg": "SAS"}
    ];

    var locationsToTargetsFisher = [
        {"v": "Cage", "tg": "DENIAL"},
        {"v": "Circulation Desk", "tg": "CIRCULATION_RESERVES"},
        {"v": "Image", "tg": "IMAGE_COLLECTION"},
        {"v": "Locked Case", "tg": "DENIAL"},
        {"v": "Map Collection", "tg": "DENIAL"},
        {"v": "Rare Book", "tg": "DENIAL"},
        {"v": "Rare Map", "tg": "DENIAL"},
        {"v": "Reference", "tg": "REFERENCE"},
        {"v": "Reserve", "tg": "CIRCULATION_RESERVES"},
        {"v": "New Book Display", "tg": "FISHER_NEW_BOOKS"},
        {"v": "Rare Print", "tg": "DENIAL"},
        {"v": "Core Reading Collection", "tg": "COREREADING"}
    ];

    var pMap = {
        "P"  : "P",
        "PA" : "P",
        "PB" : "P",
        "PC" : "P",
        "PD" : "P",
        "PE" : "P",
        "PF" : "P",
        "PG" : "P",
        "PH" : "P",
        "PI" : "P",
        "PJ" : "P",
        "PK" : "P",
        "PL" : "P",
        "PM" : "P",
        "PN" : "P",
        "PO" : "P",
        "PP" : "P",
        "PQ" : "P",
        "PR" : "P",
        "PS" : "P",
        "PT" : "P",
        "PU" : "P",
        "PV" : "P",
        "PW" : "P",
        "PX" : "P",
        "PY" : "P",
        "PZ" : "P"
    };

    function shouldDisplayLink(location, target, status, format) {
        var inVP = location.indexOf("Van Pelt") >= 0;
        var inLL = location.indexOf("Lippincott") >= 0;
        var inFA = (location.indexOf("Fine Arts") >= 0) && (location.indexOf("LIBRA") < 0);

        if (!inVP && !inLL && !inFA) {
            return false;
        }
        else if (location.indexOf("in process") >= 0) {
            return false;
        }
        else if (location.indexOf("on order") >= 0) {
            return false;
        }
        else if (location.indexOf("Illman") >= 0) {
            return false;
        }
        else if (location.indexOf("Freedman") >= 0) {
            return false;
        }
        else if (location.indexOf("Lippincott Library - Lipman Collection") >= 0) {
            return false;
        }
        else if (location.indexOf("Lippincott Library - Snyder Computer Area") >= 0) {
            return false;
        }
        else if (location.indexOf("Lippincott Library - Business Collection") >= 0) {
            return false;
        }
        else if (location.indexOf("Music Library Technical Services") >= 0) {
            return false;
        }
        else if (format.indexOf("Microformat") >= 0 && location.indexOf("Marian") < 0 && location.indexOf("Micro") < 0) {
            return false;
        }
        else if (target) {
            if (target[0]) {
                // TODO: this isn't quite right; this prevents showing the map for N call numbers in East Asia
                if ((inVP || inLL) && target[0] === "N" && target !== "NX") {
                    return false;
                }
            }
        }
        return status === "available" || status === "unavailable";
    }

    function getMapTarget(location, call_number, format) {
        var goTo = '';
        var inLocationsMap = false;

        //bifurcation between locations in Fisher Fine Arts Library and others
        if (location.indexOf("Fine Arts") >= 0) {
            //6.12.2014 update: special location has a higher order of priority in determining target than microform
            for (var i = 0; i < locationsToTargetsFisher.length; i++) {
                var locationRecord = locationsToTargetsFisher[i];
                if (location.indexOf(locationRecord.v) >= 0) {
                    inLocationsMap = true;
                    goTo = locationRecord.tg;
                    break;
                }
            }
            if (!inLocationsMap) {
                //if it is of format microformat, return directly
                if (format.indexOf("Microformat") >= 0) {
                    return "MICROFORM";
                }
                else {
                    goTo = getMapTargetByCallNumForFisher(call_number);
                }
            }
        }
        else {
            for (var i = 0; i < locationsToTargetsVP.length; i++) {
                var locationRecord = locationsToTargetsVP[i];
                if (format.indexOf("Microformat") >= 0) {
                    if (location.indexOf("Marian") >= 0) {
                        goTo = "MAMSC";
                    }
                    else if (location.indexOf("Micro") >= 0) {
                        goTo = "MICRO";
                    }
                    return goTo;
                }
                if (location.indexOf(locationRecord.v) >= 0) {
                    inLocationsMap = true;
                    if (locationRecord.v === "Lippincott Library") {
                        if (location.indexOf("Class of 1956 Computer Area") >= 0) {
                            goTo = "LCCA";
                            break;
                        } else if (location.indexOf("Peck Collection") >= 0) {
                            goTo = "LPC";
                            break;
                        } else if ((location.indexOf("Reference") >= 0) || (location.indexOf("Reserve") >= 0)) {
                            goTo = "LR";
                            break;
                        } else {
                            goTo = locationRecord.tg;
                            break;
                        }
                    }
                    else {
                        goTo = locationRecord.tg;
                        break;
                    }
                }
            }
            if (!inLocationsMap) {
                goTo = getMapTargetByCallNumForVP(call_number);
            }
        }
        return goTo;
    }

    function getMapTargetByCallNumForVP(call_number) {
        var target;
        else if (call_number.indexOf("Folio") >= 0) {
            target = "FOLIO";
        }
        else {
            var numIndex;
            var firstPart = '';
            for (var i = 0; i < call_number.length; i++) {
                var ch = call_number[i];
                if (ch) {
                    if (ch.match(intRegex)) {
                        numIndex = i;
                        break;
                    }
                }
            }
            for (var i = 0; i < numIndex; i++) {
                firstPart = firstPart + call_number[i];
            }
            target = firstPart;
            if (target[0] === "P") {
                target = pMap[target];
            } else if (target[0] === "N" && target[1] === "N") {
                target = "NX";
            } else if (target[0] !== "N") {
                target = firstPart[0];
            }
        }
        return target;
    }

    function getMapTargetByCallNumForFisher(call_number) {
        var target;
        if (call_number.indexOf("Folio") >= 0) {
            return "FOLIO";
        }
        // callno starts with 000-999
        else if (call_number.search(/[0-9]{3}/) === 0) {
            return "DEWEY";
        }
        // call numbers starting with 'N'
        else if (call_number[0] === 'N') {
            switch (call_number[1]) {
                case 'A':
                    target = "NA";
                    break;
                case 'B':
                    target = "NB";
                    break;
                case 'C':
                    target = "NC";
                    break;
                case 'D':
                    target = "ND";
                    break;
                case 'E':
                    target = "NE";
                    break;
                case 'K':
                    target = "NK";
                    break;
                case 'X':
                    target = "NX";
                    break;
                default:
                    target = "N";
            }
        }
        else {
            switch (call_number[0]) {
                case 'A':
                case 'B':
                case 'C':
                case 'D':
                case 'E':
                case 'F':
                case 'G':
                case 'H':
                case 'J':
                case 'K':
                case 'L':
                case 'M':
                    target = "A-M";
                    break;
                case 'P':
                case 'Q':
                case 'R':
                case 'S':
                case 'T':
                case 'U':
                case 'V':
                case 'W':
                case 'X':
                case 'Y':
                case 'Z':
                    target = "P-Z";
                    break;
                default:
                    target = "Other_Call_No";
            }
        }
        return target;
    }

    return function(mms_id, holding, format) {
        try {
            var location = holding['location'];
            var target = getMapTarget(location, holding['call_number'], format);
            var availability = holding['availability'];
            if (target !== 'DENIAL' && shouldDisplayLink(location, target, availability, format)) {
                if (location.indexOf("Fine Arts") >= 0) {
                    var url = "http://www.library.upenn.edu/about/locations/floor-plans/stacks-fisher#" + target;
                    return "<a href=\"" + url + "\" target='_blank'>See shelf location</a>";
                } else {
                    //console.log("showing result for " + mms_id + " " + library + " " + location + " " + target + " " + availability);
                    var url = "http://www.library.upenn.edu/about/locations/floor-plans/stacks-vp#" + target;
                    return "<a href=\"" + url + "\" target='_blank'>See shelf location</a></div>";
                }
            }
        } catch(e) {
            console.log("error in shelfLocatorLink for " + mms_id + ": " + e.message);
        }
    };
};