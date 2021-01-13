SET SEARCH_PATH TO NYCCrash, public;
DROP TABLE IF EXISTS qHolidayAccidents cascade;

-- Number of accidents that happened on holidays
CREATE TABLE qHolAccidents (
    day date not null,
    holiday text not null,
    totalCrashes int not null
);

-- Number of accidents and number of holidays by month
CREATE TABLE qMonthHolAccidents (
    month int not null,
    totalHolidays int not null,
    totalCrashes int not null
);

-- Average number of crashes per day and proportion of major accidents by average temperate (as reported by nearest weather stations to crash location)
CREATE TABLE qAccidentsTemp (
    temp int not null,
    avgCrashes float not null,
    propMajor float not null
);

-- Average number of crashes per day and proportion of major accidents by average precip, rounded to nearest integer (as reported by nearest weather stations to crash location)
CREATE TABLE qAccidentsPrecip (
    precip int not null,
    avgCrashes float not null,
    propMajor float not null
);

-- Avg number of crashes per day and proportion of major accidents by average wind speed, rounded to nearest integer (as reported by nearest weather stations to crash location)
CREATE TABLE qAccidentsWind (
    windSpeed int not null,
    avgCrashes float not null,
    propMajor float not null
);





-- Number of accidents per day
DROP VIEW IF EXISTS DailyAccidents CASCADE;
CREATE VIEW DailyAccidents AS
SELECT DATE(crashTime) as day, count(*) as totalCrashes
FROM NYCAccidents
GROUP BY DATE(crashTime);

-- Number of accidents that happened on holidays
insert into qHolAccidents
(SELECT *
FROM USHolidays NATURAL JOIN DailyAccidents
ORDER BY totalCrashes);





-- Number of accidents per month
DROP VIEW IF EXISTS MonthlyAccidents CASCADE;
CREATE VIEW MonthlyAccidents AS
SELECT EXTRACT(MONTH FROM crashTime) as month, count(*) as totalCrashes
FROM NYCAccidents
GROUP BY EXTRACT(MONTH FROM crashTime);

-- Number of holidays per month
DROP VIEW IF EXISTS MonthlyHolidays CASCADE;
CREATE VIEW MonthlyHolidays AS
SELECT EXTRACT(MONTH FROM day) as month, count(*) as totalHolidays
FROM USHolidays
GROUP BY EXTRACT(MONTH FROM day);

-- Number of accidents and number of holidays by month
insert into qMonthHolAccidents
(SELECT *
FROM MonthlyHolidays NATURAL JOIN MonthlyAccidents
ORDER BY month);




-- Major crashes (crashes with at least 1 injured or 1 death)
DROP VIEW IF EXISTS MajorCrashes CASCADE;
CREATE VIEW MajorCrashes AS
SELECT collisionID, 1 as major
FROM NYCCasualties
WHERE (pedestrianInjured > 0) OR (pedestrianKilled > 0) OR (cyclistInjured>0) OR (cyclistKilled>0) OR (motoristInjured>0) OR (motoristKilled>0);

-- Weather station reports and the longitude and lattitude of the reporting weather station
DROP VIEW IF EXISTS DailyWeatherLL CASCADE;
CREATE VIEW DailyWeatherLL AS
SELECT w.stationID as stationID, day, longitude, latitude, avgTemp, precip, avgWindSpeed
FROM NYCDailyWeather as w JOIN NYCWeatherStations as s ON w.stationID = s.stationID;

-- Crashes and weather stations that reported avgTemp on the day of crash
DROP VIEW IF EXISTS tempCrashesValidWS CASCADE;
CREATE VIEW tempCrashesValidWS AS
SELECT collisionID, s.day, stationID, avgTemp, c.longitude as crashLong, c.latitude as crashLat, s.longitude as wsLong, s.latitude as wsLat
FROM NYCAccidents as c JOIN DailyWeatherLL as s ON DATE(c.crashTIME) = s.day
WHERE avgTemp IS NOT NULL;

-- Crashes and their squared distance to avgTemp reporting weather stations in NYC
DROP VIEW IF EXISTS tempCrashesDistanceWS CASCADE;
CREATE VIEW tempCrashesDistanceWS AS
SELECT collisionID, stationID, day, avgTemp, ((crashLong-wsLong)*(crashLong-wsLong)+(crashLat-wsLat)*(crashLat-wsLat)) as distanceSquared
FROM tempCrashesValidWS;

-- Crashes and the smallest squared distance to weather station that reported avgTemp
DROP VIEW IF EXISTS tempCrashesMinD CASCADE;
CREATE VIEW tempCrashesMinD AS
SELECT collisionID, min(distanceSquared) as minDistanceSquared
FROM tempCrashesDistanceWS
GROUP BY collisionID;

-- Crashes and the closest weather stations that reported avg temp
DROP VIEW IF EXISTS tempCrashesClosestWS CASCADE;
CREATE VIEW tempCrashesClosestWS AS
SELECT a.collisionID as collisionID, a.stationID as stationID, avgTemp, day
FROM tempCrashesDistanceWS as a JOIN tempCrashesMinD as m ON a.collisionID = m.collisionID and a.distanceSquared = m.minDistanceSquared;

-- Crashes and average of reported average temperature across all closest weather stations
DROP VIEW IF EXISTS tempCrashesAvgTempWS CASCADE;
CREATE VIEW tempCrashesAvgTempWS AS
SELECT a.collisionID as collisionID, day, AVG(avgTemp) as overallAvgTemp, SUM(major) as major
FROM tempCrashesClosestWS as a LEFT JOIN MajorCrashes as m ON a.collisionID = m.collisionID
GROUP BY a.collisionID, day;

-- Total number of crashes by daily average temperate (as reported by nearest weather station to crash location) and proportion of major crashes
insert into qAccidentsTemp
(SELECT overallAvgTemp as temp, COUNT(distinct collisionID)/COUNT(distinct day) as avgCrashes, COALESCE(SUM(major), 0)/COUNT(distinct collisionID) as propMajor
FROM tempCrashesAvgTempWS
GROUP BY overallAvgTemp
ORDER BY temp);





-- Crashes and weather stations that reported precip on the day of crash and their rounded precip
DROP VIEW IF EXISTS precipCrashesValidWS CASCADE;
CREATE VIEW precipCrashesValidWS AS
SELECT collisionID, s.day, stationID, precip, c.longitude as crashLong, c.latitude as crashLat, s.longitude as wsLong, s.latitude as wsLat
FROM NYCAccidents as c JOIN DailyWeatherLL as s ON DATE(c.crashTIME) = s.day
WHERE precip IS NOT NULL;

-- Crashes and their squared distance to precip reporting weather stations in NYC
DROP VIEW IF EXISTS precipCrashesDistanceWS CASCADE;
CREATE VIEW precipCrashesDistanceWS AS
SELECT collisionID, stationID, day, precip, ((crashLong-wsLong)*(crashLong-wsLong)+(crashLat-wsLat)*(crashLat-wsLat)) as distanceSquared
FROM precipCrashesValidWS;

-- Crashes and the smallest squared distance to weather station that reports precip
DROP VIEW IF EXISTS precipCrashesMinD CASCADE;
CREATE VIEW precipCrashesMinD AS
SELECT collisionID, min(distanceSquared) as minDistanceSquared
FROM precipCrashesDistanceWS
GROUP BY collisionID;

-- Crashes and the closest weather stations that reported precip
DROP VIEW IF EXISTS precipCrashesClosestWS CASCADE;
CREATE VIEW precipCrashesClosestWS AS
SELECT a.collisionID as collisionID, a.stationID as stationID, precip, day
FROM precipCrashesDistanceWS as a JOIN precipCrashesMinD as m ON a.collisionID = m.collisionID and a.distanceSquared = m.minDistanceSquared;

-- Crashes and average of reported precip across all closest weather stations and the major proportion
DROP VIEW IF EXISTS precipCrashesAvgTempWS CASCADE;
CREATE VIEW precipCrashesAvgTempWS AS
SELECT a.collisionID as collisionID, day, AVG(precip) as overallPrecip, SUM(major) as major
FROM precipCrashesClosestWS as a LEFT JOIN MajorCrashes as m ON a.collisionID = m.collisionID
GROUP BY a.collisionID, day;

-- Average number of crashes per day by average precip, rounded to nearest tenth (as reported by nearest weather stations to crash location) and proportion of major crashes
insert into qAccidentsPrecip
(SELECT ROUND(overallPrecip ::int) as precip, COUNT(distinct collisionID)/COUNT(distinct day) as avgCrashes, COALESCE(SUM(major), 0)/COUNT(distinct collisionID) as propMajor
FROM precipCrashesAvgTempWS
GROUP BY ROUND(overallPrecip ::int)
ORDER BY precip);

-- Crashes perday per station [stations reported temp, precip, wind]
DROP VIEW IF EXISTS StationsReportTemp CASCADE;
CREATE VIEW StationsReportTemp AS
SELECT avgTemp as temp, (CAST(COUNT(stationID) AS float) / CAST(COUNT(DISTINCT day) AS float)) as stationsReportedPerDay FROM NYCDailyWeather
GROUP BY avgTemp;




-- Crashes and weather stations that reported avgWindTemp on the day of crash
DROP VIEW IF EXISTS windCrashesValidWS CASCADE;
CREATE VIEW windCrashesValidWS AS
SELECT collisionID, s.day, stationID, avgWindSpeed, c.longitude as crashLong, c.latitude as crashLat, s.longitude as wsLong, s.latitude as wsLat
FROM NYCAccidents as c JOIN DailyWeatherLL as s ON DATE(c.crashTIME) = s.day
WHERE avgWindSpeed IS NOT NULL;

-- Crashes and their squared distance to avgWindSpeed reporting weather stations in NYC
DROP VIEW IF EXISTS windCrashesDistanceWS CASCADE;
CREATE VIEW windCrashesDistanceWS AS
SELECT collisionID, stationID, day, avgWindSpeed, ((crashLong-wsLong)*(crashLong-wsLong)+(crashLat-wsLat)*(crashLat-wsLat)) as distanceSquared
FROM windCrashesValidWS;

-- Crashes and the smallest squared distance to weather station that reports avgWindSpeed
DROP VIEW IF EXISTS windCrashesMinD CASCADE;
CREATE VIEW windCrashesMinD AS
SELECT collisionID, min(distanceSquared) as minDistanceSquared
FROM precipCrashesDistanceWS
GROUP BY collisionID;

-- Crashes and the closest weather stations that reported avgWindSpeed
DROP VIEW IF EXISTS windCrashesClosestWS CASCADE;
CREATE VIEW windCrashesClosestWS AS
SELECT a.collisionID as collisionID, a.stationID as stationID, avgWindSpeed, day
FROM windCrashesDistanceWS as a JOIN windCrashesMinD as m ON a.collisionID = m.collisionID and a.distanceSquared = m.minDistanceSquared;

-- Crashes and average of reported avgWindSpeed across all closest weather stations and major proportion
DROP VIEW IF EXISTS windCrashesAvgTempWS CASCADE;
CREATE VIEW windCrashesAvgTempWS AS
SELECT a.collisionID as collisionID, day, AVG(avgWindSpeed) as overallAvgWindSpeed, SUM(major) as major
FROM windCrashesClosestWS as a LEFT JOIN MajorCrashes as m ON a.collisionID = m.collisionID
GROUP BY a.collisionID, day;

-- Total number of crashes by average windSpeed (as reported by nearest weather stations to crash location) and proportion of major crashes
insert into qAccidentsWind
(SELECT ROUND(overallAvgWindSpeed ::int) as windSpeed, COUNT(distinct collisionID)/COUNT(distinct day) as avgCrashes, COALESCE(SUM(major), 0)/COUNT(distinct collisionID) as propMajor
FROM windCrashesAvgTempWS
GROUP BY ROUND(overallAvgWindSpeed ::int)
ORDER BY windSpeed);





-- ** per station ** 
DROP TABLE IF EXISTS qAccidentsTempWS;
CREATE TABLE qAccidentsTempWS (
    temp int not null,
    stationsReportedPerDay float,
    averagecrashesperdayperstation float
);

DROP TABLE IF EXISTS qAccidentsPrecipWS;
CREATE TABLE qAccidentsPrecipWS (
    precip int not null,
    stationsReportedPerDay float,
    averagecrashesperdayperstation float
);

DROP TABLE IF EXISTS qAccidentsWindWS;
CREATE TABLE qAccidentsWindWS (
    wind int not null,
    stationsReportedPerDay float,
    averagecrashesperdayperstation float
);

DROP VIEW IF EXISTS StationsReportPrecip CASCADE;
CREATE VIEW StationsReportPrecip AS
SELECT ROUND(precip ::int) as precip, (CAST(COUNT(stationID) AS float) / CAST(COUNT(DISTINCT day) AS float)) as stationsReportedPerDay FROM NYCDailyWeather
GROUP BY ROUND(precip ::int);

DROP VIEW IF EXISTS StationsReportWind CASCADE;
CREATE VIEW StationsReportWind AS
SELECT ROUND(avgwindspeed ::int) as wind, (CAST(COUNT(stationID) AS float) / CAST(COUNT(DISTINCT day) AS float)) as stationsReportedPerDay FROM NYCDailyWeather
GROUP BY ROUND(avgwindspeed ::int);

INSERT INTO qAccidentsTempWS
SELECT qAccidentsTemp.temp as temp, qAccidentsTemp.avgCrashes/StationsReportTemp.stationsReportedPerDay as averagecrashesperdayperstation, stationsReportedPerDay
FROM 
qAccidentsTemp JOIN StationsReportTemp
ON qAccidentsTemp.temp = StationsReportTemp.temp;

INSERT INTO qAccidentsPrecipWS
SELECT qAccidentsPrecip.precip as precip, qAccidentsPrecip.avgCrashes/StationsReportPrecip.stationsReportedPerDay as averagecrashesperdayperstation, stationsReportedPerDay
FROM 
qAccidentsPrecip JOIN StationsReportPrecip
ON qAccidentsPrecip.precip = StationsReportPrecip.precip;

INSERT INTO qAccidentsWindWS
SELECT qAccidentsWind.windspeed as wind, qAccidentsWind.avgCrashes/StationsReportWind.stationsReportedPerDay as averagecrashesperdayperstation, stationsReportedPerDay
FROM 
qAccidentsWind JOIN StationsReportWind
ON qAccidentsWind.windSpeed = StationsReportWind.wind;


-- Top 10 most common contributing factors in accidents
CREATE TABLE qFactors (
    	factor1 text, 
	factor2 text, 
	factor3 text, 
	factor4 text, 
	factor5 text, 
	vehicle1 text, 
	vehicle2 text, 
	vehicle3 text, 
	vehicle4 text, 
	vehicle5 text, 
	count int

);

INSERT INTO qFactors
SELECT factor1, factor2, factor3, factor4, factor5, vehicle1, vehicle2, vehicle3, vehicle4, vehicle5, count(*)
FROM NYCFactors
GROUP BY factor1, factor2, factor3, factor4, factor5, vehicle1, vehicle2, vehicle3, vehicle4, vehicle5
ORDER BY count DESC limit 10;
