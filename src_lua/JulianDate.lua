---
--- Created by slanska.
--- DateTime: 2017-11-27 7:54 PM
---

--[[
// Julian date conversion utilities.
// Borrowed from: http://www.onlineconversion.com/julian_date.htm
//-------
// convert calendar to Julian date
// (Julian day number algorithm adopted from Press et al.)
//-------
]]

---@param era string @comment 'BCE'
---@param y number
---@param m number
---@param d number
---@param h number
---@param mn number
---@param s number
---@return number
local function dateToJulian(era, y, m, d, h, mn, s)
    local jy, ja, jm            --scratch

    if y == 0 then
        --alert("There is no year 0 in the Julian system!");
        return 0 --// Invalid
    end
    if y == 1582 and m == 10 and d > 4 and d < 15 then
        --alert("The dates 5 through 14 October, 1582, do not exist in the Gregorian system!");
        return 0 -- // "invalid";
    end

    if era == "BCE" then
        y = -y + 1
    end
    if m > 2 then
        jy = y
        jm = m + 1
    else
        jy = y - 1
        jm = m + 13
    end

    local intgr = math.floor(math.floor(365.25 * jy) + math.floor(30.6001 * jm) + d + 1720995)

    -- check for switch to Gregorian calendar
    local gregcal = 15 + 31 * ( 10 + 12 * 1582 )
    if d + 31 * (m + 12 * y) >= gregcal then
        ja = math.floor(0.01 * jy)
        intgr = intgr + (2 - ja + math.floor(0.25 * ja))
    end

    -- correct for half-day offset
    local dayfrac = h / 24.0 - 0.5
    if dayfrac < 0.0 then
        dayfrac = dayfrac + 1.0
        intgr = intgr - 1
    end

    -- now set the fraction of a day
    local frac = dayfrac + (mn + s / 60.0) / 60.0 / 24.0

    -- round to nearest second
    local jd0 = (intgr + frac) * 100000
    local jd = math.floor(jd0)
    if jd0 - jd > 0.5 then
        jd = jd + 1
    end
    return jd / 100000
end

--[[
// convert Julian date to calendar date
// (algorithm adopted from Press et al.)
//-------

// form - typed object
]]
---@param jd number
---@return table @comment typed object
local function julianToDate(jd, form)

    local j1, j2, j3, j4, j5            --scratch

    --//
    --// get the date from the Julian day number
    --//
    local intgr = math.floor(jd)
    local frac = jd - intgr
    local gregjd = 2299161
    if intgr >= gregjd then
        --Gregorian calendar correction
        local tmp = math.floor(( (intgr - 1867216) - 0.25 ) / 36524.25)
        j1 = intgr + 1 + tmp - math.floor(0.25 * tmp)

    else
        j1 = intgr
    end

    --correction for half day offset
    local dayfrac = frac + 0.5
    if dayfrac >= 1.0 then
        dayfrac = dayfrac - 1.0
        j1 = j1 + 1
    end

    j2 = j1 + 1524
    j3 = math.floor(6680.0 + ( (j2 - 2439870) - 122.1 ) / 365.25)
    j4 = math.floor(j3 * 365.25)
    j5 = math.floor((j2 - j4) / 30.6001)

    local d = math.floor(j2 - j4 - math.floor(j5 * 30.6001))
    local m = math.floor(j5 - 1)
    if m > 12 then
        m = m - 12
    end

    local y = math.floor(j3 - 4715)
    if m > 2 then
        y = y - 1
    end
    if y <= 0 then
        y = y - 1
    end

    --
    -- get time of day from day fraction
    --
    local hr = math.floor(dayfrac * 24.0)
    local mn = math.floor((dayfrac * 24.0 - hr) * 60.0)
    local f = ((dayfrac * 24.0 - hr) * 60.0 - mn) * 60.0
    local sc = math.floor(f)
    f = f - sc
    if f > 0.5 then
        sc = sc + 1
    end

    local result = {  }
    if y < 0 then
        y = -y
        result.era = true
    else
        result.era = false
    end

    result.year = y
    result.month = m
    result.day = d
    result.hour = hr
    result.minute = mn
    result.second = sc
    return result
end

return {
    dateToJulian = dateToJulian,
    julianToDate = julianToDate
}
