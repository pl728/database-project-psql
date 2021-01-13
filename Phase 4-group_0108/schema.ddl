drop schema if exists NYCCrash cascade;
create schema NYCCrash;
set search_path to NYCCrash;

-- An accident that occured in New York City
create table NYCAccidents(
    collisionID varchar(10) primary key,
    crashTime timestamp,
    longitude float,
    latitude float
);

-- A weather station and its location in coordinates.
create table NYCWeatherStations(
    stationID varchar(11) primary key,
    longitude float,
    latitude float,
    unique (longitude, latitude)
);

-- Daily weather details from weather stations.
create table NYCDailyWeather(
    day date not null,
    stationID varchar(11) not null,
    minTemp float,
    maxTemp float,
    avgTemp float,
    precip float,
    snowFall float,
    snowDepth float,
    waterSnowOnGround float,
    waterSnowfall float,
    avgWindSpeed float,
    primary key (day, stationID),
    foreign key (stationID) references NYCWeatherStations
);

-- Accident involving at least one injury or death.
create table NYCCasualties(
    collisionID varchar(10) primary key,
    pedestrianInjured integer,
    pedestrianKilled integer,
    cyclistInjured integer,
    cyclistKilled integer,
    motoristInjured integer,
    motoristKilled integer,
    foreign key (collisionID) references NYCAccidents
);

-- Factors and vehicles involved in an accident.
create table NYCFactors(
    collisionID varchar(10) primary key,
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
    foreign key (collisionID) references NYCAccidents
);

-- American Holidays throughout the years. 
create table USHolidays(
    day date not null,
    holiday text not null,
    primary key (day, holiday)
    -- foreign key (day) references NYCDailyWeather(day)
);
