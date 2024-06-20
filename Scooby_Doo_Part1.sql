/*

Cleaning Data in SQL Queries

*/
SELECT * FROM scoobydoo;

-- Steps for cleaning the data
-- 1. Create a second table to perform on
-- 2. Manage columns
-- 3. Remove Duplicates
-- 4. Standardize the data
-- 		i. Date aired needs to be date
-- 		ii. monster_name, monster_ gender, monster_type, monster_subtype, monster_species add spaces after commas
-- 5. Check Null Values

-- ------------------------------------------------------------------------------------------------------

-- 1. Create a Second Table
-- In case we make a mistake we have the untouched database 
CREATE TABLE scoobydoo_staging
LIKE scoobydoo;
-- "dup" at the end just indiccates that this table still contains duplicates, I will create a sightings_staging table that does
-- not have duplicates in step 2

INSERT scoobydoo_staging
SELECT * FROM scoobydoo; 
-- ------------------------------------------------------------------------------------------------------

-- 2. Remove columns or rows we don't need (I normally do this later but there are so many columns and this will simplify the later steps )
# Based on my exploration questions later, these are the columns I do not need
ALTER TABLE `scooby_doo`.`scoobydoo_staging` 
DROP COLUMN `fred_va`,
DROP COLUMN `daphnie_va`,
DROP COLUMN `velma_va`,
DROP COLUMN `shaggy_va`,
DROP COLUMN `scooby_va`,
DROP COLUMN `non_suspect`,
DROP COLUMN `arrested`,
DROP COLUMN `culprit_name`,
DROP COLUMN `culprit_amount`,
DROP COLUMN `snack_fred`,
DROP COLUMN `if_it_wasnt_for`,
DROP COLUMN `and_that`,
DROP COLUMN `snack_daphnie`,
DROP COLUMN `snack_velma`,
DROP COLUMN `snack_shaggy`,
DROP COLUMN `snack_scooby`;

SELECT * FROM scoobydoo_staging;

-- I also want to combine rows that seem unnecessary to have seperate 
-- This includes the captured, unmasked, guest_stars and caught columns

-- Caught
ALTER TABLE scoobydoo_staging ADD COLUMN caught_by TEXT;
#this is a column of who caught the monster

UPDATE scoobydoo_staging
SET caught_by = TRIM(BOTH ', ' FROM CONCAT(
    CASE WHEN caught_fred = 'TRUE' THEN 'Fred, ' ELSE '' END,
    CASE WHEN caught_daphnie = 'TRUE' THEN 'Daphnie, ' ELSE '' END,
    CASE WHEN caught_velma = 'TRUE' THEN 'Velma, ' ELSE '' END,
    CASE WHEN caught_shaggy = 'TRUE' THEN 'Shaggy, ' ELSE '' END,
    CASE WHEN caught_scooby = 'TRUE' THEN 'Scooby, ' ELSE '' END,
	CASE WHEN caught_other = 'TRUE' THEN 'Other, ' ELSE '' END,
	CASE WHEN caught_not = 'TRUE' THEN 'Not caught, ' ELSE '' END
));

SELECT caught_fred, caught_daphnie, caught_velma, caught_shaggy, caught_scooby, caught_other, caught_not, caught_by FROM scoobydoo_staging;

ALTER TABLE `scooby_doo`.`scoobydoo_staging` 
DROP COLUMN caught_fred,
DROP COLUMN caught_daphnie,
DROP COLUMN caught_velma,
DROP COLUMN caught_shaggy,
DROP COLUMN caught_scooby,
DROP COLUMN caught_other,
DROP COLUMN caught_not;

-- Captured
ALTER TABLE scoobydoo_staging ADD COLUMN captured TEXT;
#this is a column of who was captured by the monster 

UPDATE scoobydoo_staging
SET captured = TRIM(BOTH ', ' FROM CONCAT(
    CASE WHEN captured_fred = 'TRUE' THEN 'Fred, ' ELSE '' END,
    CASE WHEN captured_daphnie = 'TRUE' THEN 'Daphnie, ' ELSE '' END,
    CASE WHEN captured_velma = 'TRUE' THEN 'Velma, ' ELSE '' END,
    CASE WHEN captured_shaggy = 'TRUE' THEN 'Shaggy, ' ELSE '' END,
    CASE WHEN captured_scooby = 'TRUE' THEN 'Scooby, ' ELSE '' END
));

SELECT captured_fred, captured_daphnie, captured_velma, captured_shaggy, captured_scooby, captured FROM scoobydoo_staging;

ALTER TABLE `scooby_doo`.`scoobydoo_staging` 
DROP COLUMN captured_fred,
DROP COLUMN captured_daphnie,
DROP COLUMN captured_velma,
DROP COLUMN captured_shaggy,
DROP COLUMN captured_scooby;

-- Unmasked
ALTER TABLE scoobydoo_staging ADD COLUMN unmasked TEXT;
#this is a column of who unmasked the monster

UPDATE scoobydoo_staging
SET unmasked = TRIM(BOTH ', ' FROM CONCAT(
    CASE WHEN unmask_fred = 'TRUE' THEN 'Fred, ' ELSE '' END,
    CASE WHEN unmask_daphnie = 'TRUE' THEN 'Daphnie, ' ELSE '' END,
    CASE WHEN unmask_velma = 'TRUE' THEN 'Velma, ' ELSE '' END,
    CASE WHEN unmask_shaggy = 'TRUE' THEN 'Shaggy, ' ELSE '' END,
    CASE WHEN unmask_scooby = 'TRUE' THEN 'Scooby, ' ELSE '' END,
    CASE WHEN unmask_other = 'TRUE' THEN 'Other, ' ELSE '' END
));

SELECT unmask_fred, unmask_daphnie, unmask_velma, unmask_shaggy, unmask_scooby, unmask_other, unmasked FROM scoobydoo_staging;

ALTER TABLE `scooby_doo`.`scoobydoo_staging` 
DROP COLUMN unmask_fred,
DROP COLUMN unmask_daphnie,
DROP COLUMN unmask_velma,
DROP COLUMN unmask_shaggy,
DROP COLUMN unmask_scooby,
DROP COLUMN unmask_other;

-- Guest stars
ALTER TABLE scoobydoo_staging ADD COLUMN guest_stars TEXT;
#this is a column of who the guest stars of the episode are

UPDATE scoobydoo_staging
SET guest_stars = TRIM(BOTH ', ' FROM CONCAT(
    CASE WHEN batman = 'TRUE' THEN 'Batman, ' ELSE '' END,
    CASE WHEN scooby_dum = 'TRUE' THEN 'Scooby Dum, ' ELSE '' END,
    CASE WHEN scrappy_doo = 'TRUE' THEN 'Scrappy Doo, ' ELSE '' END,
    CASE WHEN hex_girls = 'TRUE' THEN 'Hex Girls, ' ELSE '' END,
    CASE WHEN blue_falcon = 'TRUE' THEN 'Blue Falcon, ' ELSE '' END
));

SELECT batman, scooby_dum, scrappy_doo, hex_girls, blue_falcon, guest_stars FROM scoobydoo_staging;

ALTER TABLE `scooby_doo`.`scoobydoo_staging` 
DROP COLUMN batman,
DROP COLUMN scooby_dum,
DROP COLUMN scrappy_doo,
DROP COLUMN hex_girls,
DROP COLUMN blue_falcon;

SELECT * FROM scoobydoo_staging;
-- ------------------------------------------------------------------------------------------------------

-- 3. Remove Duplicates
 
WITH duplicates AS
(
	SELECT * ,
	ROW_NUMBER() OVER(
		PARTITION BY series_name, network, season, title, imdb, engagement, date_aired, run_time, format, monster_name, monster_gender, monster_type, monster_subtype, monster_species, monster_real, monster_amount, trap_work_first, setting_terrain, setting_country_state, suspects_amount, culprit_gender, motive, door_gag, number_of_snacks, split_up, another_mystery, set_a_trap, jeepers, jinkies, my_glasses, just_about_wrapped_up, zoinks, groovy, scooby_doo_where_are_you, rooby_rooby_roo, caught_by, captured, unmasked, guest_stars
	) AS row_num
	FROM scoobydoo_staging
)
SELECT * FROM duplicates WHERE row_num > 1;

-- The table seems have no duplicates
-- ------------------------------------------------------------------------------------------------------

-- 4. Standardize the data
-- i. Date aired needs to be date

ALTER TABLE `scooby_doo`.`scoobydoo_staging` 
CHANGE COLUMN `date_aired` `date_aired` DATE NULL DEFAULT NULL ;

-- ii. monster_name, monster_ gender, monster_type, monster_subtype, monster_species add spaces after commas
UPDATE scoobydoo_staging
SET monster_name = REPLACE(monster_name, ',', ', '),
	monster_gender = REPLACE(monster_gender, ',', ', '),
    monster_type = REPLACE(monster_type, ',', ', '),
	monster_subtype = REPLACE(monster_subtype, ',', ', '),
    monster_species = REPLACE(monster_species, ',', ', ');
-- ------------------------------------------------------------------------------------------------------

-- 5. Null values or blank values
-- There are Null values in caught_by, captured, unmasked, guest_stars

UPDATE scoobydoo_staging
SET
    caught_by = (CASE WHEN caught_by = "" THEN NULL ELSE caught_by END),
    captured = (CASE WHEN captured = "" THEN NULL ELSE captured END),
    unmasked = (CASE WHEN unmasked = "" THEN NULL ELSE unmasked END),
    guest_stars = (CASE WHEN guest_stars = "" THEN NULL ELSE guest_stars END);

-- It is ok that there are null values in a lot of the rows because the nulls are not errors, they just don't apply to the episode
SELECT * FROM scoobydoo_staging;