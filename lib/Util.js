/**
 * Created by slanska on 2015-12-09.
 */
///<reference path="../typings/tsd.d.ts"/>
var Util = (function () {
    function Util() {
    }
    Util.JSONReplacer = function () {
    };
    // Julian date conversion utilities.
    // Borrowed from: http://www.onlineconversion.com/julian_date.htm
    //-------
    // convert calendar to Julian date
    // (Julian day number algorithm adopted from Press et al.)
    //-------
    Util.dateToJulian = function (era, y, m, d, h, mn, s) {
        var jy, ja, jm; //scratch
        if (y == 0) {
            alert("There is no year 0 in the Julian system!");
            return 0; // Invalid
        }
        if (y == 1582 && m == 10 && d > 4 && d < 15) {
            alert("The dates 5 through 14 October, 1582, do not exist in the Gregorian system!");
            return 0; // "invalid";
        }
        if (era == "BCE")
            y = -y + 1;
        if (m > 2) {
            jy = y;
            jm = m + 1;
        }
        else {
            jy = y - 1;
            jm = m + 13;
        }
        var intgr = Math.floor(Math.floor(365.25 * jy) + Math.floor(30.6001 * jm) + d + 1720995);
        //check for switch to Gregorian calendar
        var gregcal = 15 + 31 * (10 + 12 * 1582);
        if (d + 31 * (m + 12 * y) >= gregcal) {
            ja = Math.floor(0.01 * jy);
            intgr += 2 - ja + Math.floor(0.25 * ja);
        }
        //correct for half-day offset
        var dayfrac = h / 24.0 - 0.5;
        if (dayfrac < 0.0) {
            dayfrac += 1.0;
            --intgr;
        }
        //now set the fraction of a day
        var frac = dayfrac + (mn + s / 60.0) / 60.0 / 24.0;
        //round to nearest second
        var jd0 = (intgr + frac) * 100000;
        var jd = Math.floor(jd0);
        if (jd0 - jd > 0.5)
            ++jd;
        return jd / 100000;
    };
    //-------
    // convert Julian date to calendar date
    // (algorithm adopted from Press et al.)
    //-------
    Util.julianToDate = function (jd, form) {
        var j1, j2, j3, j4, j5; //scratch
        //
        // get the date from the Julian day number
        //
        var intgr = Math.floor(jd);
        var frac = jd - intgr;
        var gregjd = 2299161;
        if (intgr >= gregjd) {
            var tmp = Math.floor(((intgr - 1867216) - 0.25) / 36524.25);
            j1 = intgr + 1 + tmp - Math.floor(0.25 * tmp);
        }
        else
            j1 = intgr;
        //correction for half day offset
        var dayfrac = frac + 0.5;
        if (dayfrac >= 1.0) {
            dayfrac -= 1.0;
            ++j1;
        }
        j2 = j1 + 1524;
        j3 = Math.floor(6680.0 + ((j2 - 2439870) - 122.1) / 365.25);
        j4 = Math.floor(j3 * 365.25);
        j5 = Math.floor((j2 - j4) / 30.6001);
        var d = Math.floor(j2 - j4 - Math.floor(j5 * 30.6001));
        var m = Math.floor(j5 - 1);
        if (m > 12)
            m -= 12;
        var y = Math.floor(j3 - 4715);
        if (m > 2)
            --y;
        if (y <= 0)
            --y;
        //
        // get time of day from day fraction
        //
        var hr = Math.floor(dayfrac * 24.0);
        var mn = Math.floor((dayfrac * 24.0 - hr) * 60.0);
        var f = ((dayfrac * 24.0 - hr) * 60.0 - mn) * 60.0;
        var sc = Math.floor(f);
        f -= sc;
        if (f > 0.5)
            ++sc;
        if (y < 0) {
            y = -y;
            form.era[1].checked = true;
        }
        else
            form.era[0].checked = true;
        form.year.value = y;
        form.month[m - 1].selected = true;
        form.day[d - 1].selected = d;
        form.hour.value = hr;
        form.minute.value = mn;
        form.second.value = sc;
    };
    return Util;
})();
exports.Util = Util;
//# sourceMappingURL=Util.js.map