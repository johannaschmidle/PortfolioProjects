/*

Cleaning Data in SQL Queries

*/

SELECT * FROM sightings;

-- need to edit column names to useable fromat
ALTER TABLE `ufo_sightings`.`sightings` 
CHANGE COLUMN `duration (seconds)` `duration_seconds` DOUBLE NULL DEFAULT NULL ,
CHANGE COLUMN `duration (hours/min)` `duration_hours_min` TEXT NULL DEFAULT NULL ,
CHANGE COLUMN `date posted` `date_posted` TEXT NULL DEFAULT NULL ;

-- Steps for cleaning the data
-- 1. Create a second table to perform on
-- 2. Remove Duplicates
-- 3. Standardize the data and fix errors
-- 		a. Change rows where duration_hours_min is nonsensical and make it uniform 
-- 		b. Rename countries that don’t make sense (and make the countries full names instead of abbreviation)
-- 		c. Cange date columns from text to date
-- 		d. Clean non alphabetic characters from text columns
-- 		e. Convert all blanks to nulls 
-- 4. Populate null values
-- 5. Drop columns and rows that are not needed 
-- 6. Add columns for exploration (continent column)
-- 7. I will do some breif exploration here just to have more information and context for part 2 of this project

-- ------------------------------------------------------------------------------------------------------

-- 1. Create a Second Table
-- In case we make a mistake we have the untouched database 

CREATE TABLE sightings_staging_dup
LIKE sightings;
-- "dup" at the end just indiccates that this table still contains duplicates, I will create a sightings_staging table that does
-- not have duplicates in step 2

INSERT sightings_staging_dup
SELECT * FROM sightings; 

-- ------------------------------------------------------------------------------------------------------
-- 2. Remove Duplicates
-- Firstly, I must check for duplicates

WITH duplicates AS
(
	SELECT * ,
	ROW_NUMBER() OVER(
		PARTITION BY datetime, city, state, country, shape, duration_hours_min, duration_seconds, comments, date_posted, latitude, longitude
	) AS row_num
	FROM sightings_staging_dup
)
SELECT * FROM duplicates WHERE row_num > 1;

-- The table seems to only one duplicate. I will delete this. 
-- To do this I will create a new table called sightings_staging which will include row_num column
-- and then I will insert the appropriate data 

CREATE TABLE `sightings_staging` (
  `datetime` text,
  `city` text,
  `state` text,
  `country` text,
  `shape` text,
  `duration_seconds` double DEFAULT NULL,
  `duration_hours_min` text,
  `comments` text,
  `date_posted` text,
  `latitude` double DEFAULT NULL,
  `longitude` double DEFAULT NULL,
  `row_num` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `ufo_sightings`.`sightings_staging`
(`datetime`, `city`, `state`, `country`, `shape`, `duration_seconds`, `duration_hours_min`,
`comments`, `date_posted`, `latitude`, `longitude`, `row_num`)
SELECT
`datetime`, `city`, `state`, `country`, `shape`, `duration_seconds`, `duration_hours_min`,
`comments`, `date_posted`, `latitude`, `longitude`, 
 ROW_NUMBER() OVER(
		PARTITION BY datetime, city, state, country, shape, duration_hours_min, duration_seconds, comments, date_posted, latitude, longitude
	) AS row_num 
FROM sightings_staging_dup;

-- Now I will delete rows where row_num >= 2 and then I will delete the column row_num
DELETE FROM sightings_staging
WHERE row_num >= 2;

ALTER TABLE `ufo_sightings`.`sightings_staging` 
DROP COLUMN `row_num`;

-- I will use the sightings_staging table for the rest of this project
-- I can also delete sightings_staging_dup table as it is no longer needed and if I do need it it is easy to get back

DROP TABLE sightings_staging_dup;

-- ------------------------------------------------------------------------------------------------------

-- 3. Standardize the data
-- a. work with duration_hours_min and duration_seconds --------------------------------------------------------------------------------------------------
-- I want to see the rows where the duration columns are nonsensical and unusable 

-- First I am checking where we are missing information about the duration
SELECT * 
FROM sightings_staging
WHERE (duration_hours_min = "" AND duration_seconds != 0) OR (duration_hours_min != "" AND duration_seconds = 0);

-- we can see the duration_hours_min column has a lot of nonsense entries (some of the entries are not useable (random sentences (like "my house" or "flash"), or large range of time)).
-- we want replace these random sentences with NULL

UPDATE sightings_staging
SET duration_hours_min = 
    CASE 
        WHEN (duration_hours_min LIKE '%hour%' OR duration_hours_min LIKE '%min%' OR duration_hours_min LIKE '%sec%' OR duration_hours_min LIKE '%hr%') THEN duration_hours_min
        ELSE NULL
    END
;
-- I will leave duration_hours_min as text type because we have duration_seconds which seems to be a generally more accurate way to get information about the duration of the event
-- duration_hours_min will be there to provide extra information incase it is needed during data exploration

-- b. Rename countries that don't make sense (and make the countries full names instead of abbreviation) ------------------------------------------------------------------------------------------------------

-- We want to see distinct countries
SELECT DISTINCT country FROM sightings_staging;

-- There are 5 countries (not including null). I'm going to investigate gb and de

-- country = "gb" 

SELECT * FROM sightings_staging WHERE country = "gb";

-- I noticed that a lot of the citys have (uk/something) I am going to check if they are all like this

SELECT * FROM sightings_staging WHERE country = "gb" AND city NOT LIKE "%(uk%";

-- I can see there are no instances like this. Now I will try to extract the unique instances like "(uk/something)" to see what countries are listed

SELECT distinct country, SUBSTRING(city, LOCATE('(uk', city)) AS city_substring FROM  sightings_staging
WHERE city LIKE '%(uk%' 
ORDER BY city_substring;

-- We have four main countries listed, England, Wales, Northern Ireland, Scotland. So depending on what I am planning to do with the data I can either
-- Name each country individually or I can lump them together all under "UK". For the purposes of my data exploration I will just lump these countries together and assign them all as UK 
-- I also noticed instances of ukraine under city names and I do not want to accidentally assign these to the UK
UPDATE sightings_staging
SET
	country = "united kingdom"
WHERE 
	city LIKE '%(uk%' AND city NOT LIKE "%ukraine%" ;
    
-- now I will investigate when country = "de"

SELECT * FROM sightings_staging WHERE country = "de";
-- NOTE: in the city column we have (germany) in brackets next to city name in most columns. 
-- I am going to check if this is the case for all columns (where country = "de")

SELECT * FROM sightings_staging WHERE country = "de" AND city NOT LIKE "%germany%";

-- So there are no instances like this.
-- for the sake of investigation later, I want to change all the country names so that they are the full names of the countries 
-- I will change "de" to "germany" 

UPDATE sightings_staging
SET
	country = 
    (CASE 
			WHEN country = "us" THEN "united states" 
			WHEN country = "ca" THEN "canada" 
			WHEN country = "au" THEN "australia" 
			WHEN country = "uk" THEN "united kingdom"
            WHEN country = "de" THEN "germany"
			ELSE country
	END);

-- There seem to be a lot of latiude and longitude coordinated outside of these areas but the country names we have are focused in those areas.
-- Instead of trying to pick apart all the different country names for each of these, I will leave them as blanks and in python (in patrt 2 of this project) I can get the city state and country names from the latitude and longitude coordinates

-- finally I will remove the "(...)" from the entries in the cities column
UPDATE sightings_staging
SET
    city = REGEXP_REPLACE(city, " *\\(.*?\\)", "")
WHERE 
    city LIKE '%(%';

-- c. Change date columns from text to date  --------------------------------------------------------------------------------------------------
-- First I will work on datetime column. Thankfully it looks like this coulumn is uniform and there are no weirdly formatted rows. 
-- This makes it easy to use str_to_date(datetime, "%m/%d/%Y %T") to make this a date column
-- Note the time is in 24 hour time so we have the edge case 24:00 which won't work for str_to_date. So we just need to change these instances to 00:00

UPDATE sightings_staging
SET
    datetime = REPLACE(datetime, "24:00", "00:00")
WHERE 
    datetime LIKE "%24:00%";

-- Now I will convert string to datetime format
    
UPDATE sightings_staging
SET
    datetime = str_to_date(datetime, "%m/%d/%Y %T");

-- Now I can convert the datetime column to date time type

ALTER TABLE `ufo_sightings`.`sightings_staging` 
CHANGE COLUMN `datetime` `datetime` DATETIME NULL DEFAULT NULL ;

-- Now I will work on date_posted column. Thankfully this coulumn also looks to be uniform and there are no weirdly formatted rows. 
-- But notice with this column it is only dates and no time

UPDATE sightings_staging
SET
    date_posted = str_to_date(date_posted, "%m/%d/%Y");

ALTER TABLE `ufo_sightings`.`sightings_staging` 
CHANGE COLUMN `date_posted` `date_posted` DATE NULL DEFAULT NULL ;

-- d. Clean non alphabetic characters from text columns --------------------------------------------------------------------------------------------------
-- I noticed in the city and comments columns there are some rows with non alphabetic characters (for example, maplewood&#44).
-- I am going to clean these rows so they are only alphabetic 

UPDATE sightings_staging
SET city = REGEXP_REPLACE(city, '[^a-zA-Z ]', '');

-- I am also going to remove numbers and characters from comments column
-- I am doing this because although there is extra information in the comments column where characters and numbers are being used for a valid reason I am
-- just doing sentiment analysis and getting tokens later on, so the sentences don't need to be exactly the way they would need to be if communicating 
-- the information to another person

UPDATE sightings_staging
SET
    comments = REGEXP_REPLACE(comments, '[^a-zA-Z ]', ''); 

-- e. Convert all blanks to nulls ------------------------------------------------------------------------------------------------------

-- Instead of checking each column for blank entries individually, I am going to just check for all columns except datetime, and duration_hours_min because of previous steps 
-- Before I do that, I am going to check if there are rows in the text columns that say unknown

SELECT city, state, country, shape FROM sightings_staging WHERE city LIKE "%unknown%" OR state LIKE "%unknown%" OR country LIKE "%unknown%" OR shape LIKE "%unknown%" ;

-- There are "unknown"s in the city column and the shape column.
-- I am going to check how many in blank entries are in each column before I update the table

SELECT 
  sum(CASE WHEN (city = "" OR city LIKE "%unknown%") THEN 1 ELSE 0 END) NA_city,
  sum(CASE WHEN state = "" THEN 1 ELSE 0 END) NA_state,
  sum(CASE WHEN country = "" THEN 1 ELSE 0 END) NA_country,
  sum(CASE WHEN (shape = "" OR shape LIKE "%unknown%") THEN 1 ELSE 0 END) NA_shape,
  sum(CASE WHEN duration_seconds = 0 THEN 1 ELSE 0 END) NA_duration_seconds, 
  sum(CASE WHEN comments = "" THEN 1 ELSE 0 END) NA_comments,
  sum(CASE WHEN latitude = 0 THEN 1 ELSE 0 END) NA_latitude,
  sum(CASE WHEN longitude = 0 THEN 1 ELSE 0 END) NA_longitude
FROM sightings_staging;

# NA_city | NA_state | NA_country| NA_shape | NA_duration_seconds | NA_comments | NA_latitude | NA_longitude
# 65 	  | 7407	 | 12362     | 9239     | 7027                | 39          | 1494        | 1494

-- Now I will change all blank entries to NULL (note for shape and city columns we have the entries "unkown" which I will also change to NULL)
-- We will also use trim() on some of the text columns for cleanliness and uniformity

UPDATE sightings_staging
SET
    state = (CASE WHEN state = "" THEN NULL ELSE TRIM(state) END),
	city = (CASE WHEN (city LIKE "%unknown%" OR city = "") THEN NULL ELSE TRIM(city) END),
    country = (CASE WHEN country = "" THEN NULL ELSE TRIM(country) END),
    shape = (CASE WHEN (shape = "" OR shape LIKE "%unknown%" ) THEN NULL ELSE TRIM(shape) END),
    duration_seconds = (CASE WHEN duration_seconds = 0 THEN NULL ELSE duration_seconds END),
    comments = (CASE WHEN comments = "" THEN NULL ELSE TRIM(comments) END),
    latitude = (CASE WHEN latitude = 0 THEN NULL ELSE latitude END),
    longitude = (CASE WHEN longitude = 0 THEN NULL ELSE longitude END);

-- ------------------------------------------------------------------------------------------------------

-- 4. Populate null values
-- There are a few columns where it is possible to get missing information if some of the other columns are filled 
-- For example, if we have state, city, then we might be able to get country
-- There are two cases I will focus on:
-- 		a. Have (latitude, longitude) and one of (city, state) I can get country
-- 		b. Have (city, state) I can get (counytry, latitude, longitude)
-- Note I am not using latitude and longitude to get information on city or state because this will not always be accurate

-- a. Have (latitude, longitude, city, state) and Get country --------------------------------------------------------------------------------------------------
-- To get an estimate on the range of closeness for latiitude and longitude, I googled distance between 1 degree on latitude = 69 miles and I checked the width of the countries I have
-- United States, England, Wales, Canada, Australia, Ireland, Scotland, Germany, United kingdom and the smallest width is 140 miles (Wales)
-- So an I will set the range to 1.25 because the chances of a different country with the same city or state name being that close is slim

SELECT s1.city, s1.country, s1.state, s1.longitude, s1.latitude,
	   s2.city, s2.country, s2.state, s2.longitude, s2.latitude
FROM sightings_staging s1 
JOIN sightings_staging s2 
	ON ABS(s1.latitude - s2.latitude) < 1.25
	AND ABS(s1.longitude - s2.longitude) < 1.25
WHERE (s1.country IS NULL AND s2.country IS NOT NULL)
  AND ((s1.state IS NOT NULL AND s1.state = s2.state) 
		AND (s1.city IS NOT NULL AND s1.city = s2.city)); 

-- We can see there are quite a few rows like this. So I will update the sightings_staging table

UPDATE sightings_staging s1
JOIN sightings_staging s2
	ON ABS(s1.latitude - s2.latitude) < 1.25
    AND ABS(s1.longitude - s2.longitude) < 1.25
SET s1.country = (CASE 
                  WHEN s1.country IS NULL AND s2.country IS NOT NULL THEN s2.country 
                  ELSE s1.country 
                END)
WHERE (s1.country IS NULL AND s2.country IS NOT NULL) 
	   AND (s1.state IS NOT NULL AND s1.state = s2.state) 
	   AND (s1.city IS NOT NULL AND s1.city = s2.city);
       
-- b. Have (city, state) Get (country, latitude, longitude)
-- I will repeat a similar procedure as above

SELECT s1.city, s1.country, s1.state, s1.longitude, s1.latitude,
	   s2.city, s2.country, s2.state, s2.longitude, s2.latitude
FROM sightings_staging s1 
JOIN sightings_staging s2 
	ON s1.city = s2.city
	AND s1.state = s2.state
WHERE (s1.country IS NULL AND s2.country IS NOT NULL) OR (s1.latitude IS NULL AND s2.latitude IS NOT NULL) OR (s1.longitude IS NULL AND s2.longitude IS NOT NULL); 

-- I noticed that latitude and longitude are often both missing. So I will check if there are cases where only one is missing

SELECT * FROM sightings_staging WHERE (latitude IS NULL AND longitude IS NOT NULL) or (longitude IS NULL AND latitude IS NOT NULL);

-- There are no instances like this so now when I update, I will update both in (when possible)
-- Note: latitude and longitude can slightly vary within cities and countries, but i will update so the previously null rows have an approximate value for latitude and longitude
-- Now I will update country, latitude, and longitude when possible

UPDATE sightings_staging s1
JOIN sightings_staging s2
	ON s1.city = s2.city
	AND s1.state = s2.state
SET s1.country = (CASE 
                  WHEN s1.country IS NULL AND s2.country IS NOT NULL THEN s2.country 
                  ELSE s1.country 
                END),
    s1.latitude = (CASE 
                  WHEN s1.latitude IS NULL AND s2.latitude IS NOT NULL THEN s2.latitude 
                  ELSE s1.latitude 
                END),
    s1.longitude = (CASE 
                  WHEN s1.latitude IS NULL AND s2.latitude IS NOT NULL THEN s2.latitude 
                  ELSE s1.latitude 
                END)
WHERE (s1.country IS NULL AND s2.country IS NOT NULL) 
	  OR (s1.latitude IS NULL AND s2.latitude IS NOT NULL) 
      OR (s1.longitude IS NULL AND s2.longitude IS NOT NULL) ;
      
-- Now I will check how the null values have changed (I only changed country, latitude, and longitude columns)

SELECT 
  sum(CASE WHEN country IS NULL THEN 1 ELSE 0 END) NA_country,
  sum(CASE WHEN latitude IS NULL THEN 1 ELSE 0 END) NA_latitude,
  sum(CASE WHEN longitude IS NULL THEN 1 ELSE 0 END) NA_longitude
FROM sightings_staging;

#    NA_country   | NA_latitude | NA_longitude
#    11,654       | 1366        | 1366

-- This is an improvement. Also, conisdering that the database is so large (88,000 rows approximatley) this a pretty negligible amount of NA values.
-- There are also cases where it is ok to have NULL values. For example:
--   state: because becuase there are countries like Germany, Australia and the UK which don't have "states"
-- 	 country, city: because some of these sightings may have been in the middle of the ocean ie. no country or city (or state)
-- Some of there rows where certain columns are blank might have useuful information in different columns. What is important depends on the data exploration questions

-- ------------------------------------------------------------------------------------------------------

-- 5. Drop rows and columns
-- Taking into cnsideration my specific goals and ideas for this database, I have deemed the following columns unnecessary:
-- 		duration_hours_min, duration_seconds: I am not looking in to how long the sightings lasted
-- Although some of the columns I am deleting are ones I have cleaned, this is ok because we have the scrubbed version of them in case my goals and questions change and I ever do need them

ALTER TABLE `ufo_sightings`.`sightings_staging` 
DROP COLUMN `duration_hours_min`,
DROP COLUMN `duration_seconds`;

-- Now I want to check which rows I can delete
-- The main location columns that are important for my investiation are latitude and longitude (as city, state and country can be derived from these)
-- I also want to perform a text analysis so I want there to be no nulls in the shape comments columns
-- I also do not want any nulls in the date posted columns

SELECT count(*) FROM sightings_staging 
WHERE latitude IS NOT NULL 
	AND longitude IS NOT NULL 
    AND shape IS NOT NULL
	AND date_posted IS NOT NULL
    AND comments IS NOT NULL;

-- There are 78,223 rows 
-- I want to compare this to how many rows are in the database

SELECT count(*) FROM sightings_staging; 

-- There are 88,673 rows in the entire database
-- There is not a huge difference between the two tables. And a table of 78,223 rows is still extremely large
-- So I will just delete rows with NULL values in the "important" columns

DELETE FROM sightings_staging
WHERE latitude IS NULL 
	OR longitude IS NULL 
    OR date_posted IS NULL 
    OR shape IS NULL
    OR comments IS NULL;
    
-- I want to see how large my new table is

SELECT count(*) FROM sightings_staging; 

-- There are 74,731 rows

-- I will just double check how many NULLs are in each column

SELECT 
  sum(CASE WHEN city IS NULL THEN 1 ELSE 0 END) NA_city,
  sum(CASE WHEN state IS NULL THEN 1 ELSE 0 END) NA_state,
  sum(CASE WHEN country IS NULL THEN 1 ELSE 0 END) NA_country,
  sum(CASE WHEN shape IS NULL THEN 1 ELSE 0 END) NA_shape,
  sum(CASE WHEN comments IS NULL THEN 1 ELSE 0 END) NA_comments,
  sum(CASE WHEN latitude IS NULL THEN 1 ELSE 0 END) NA_latitude,
  sum(CASE WHEN longitude IS NULL THEN 1 ELSE 0 END) NA_longitude
FROM sightings_staging;

-- there are only NULL values in the city and state and country columns as desired

-- 7. Breif exploration ------------------------------------------------------------------------------------------------------
-- I want to see how many countries have distinct states
select country, count(distinct state) from sightings_staging group by country;

-- See all the shapes that UFO's have been described as
select distinct shape from sightings_staging;

-- How many ufo sightings are in each country
select country, count(*) from sightings_staging group by country;
