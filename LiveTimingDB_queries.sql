SELECT * FROM LiveTiming..team
SELECT * FROM LiveTiming..nationality
SELECT * FROM LiveTiming..driver
SELECT * FROM LiveTiming..engine
SELECT * FROM LiveTiming..manufacturer
SELECT * FROM LiveTiming..car
SELECT * FROM LiveTiming..track
SELECT * FROM LiveTiming..lap

-- 1
SELECT driver_name, MIN(laptime) AS best_time, COUNT(*) AS number_of_laps,
	 CONVERT(varchar, DATEADD(SECOND, DATEDIFF(SECOND, MIN(date_time), MAX(date_time)), 0), 108) AS practice_length
	 , CONVERT(varchar, DATEADD(MILLISECOND, SUM(DATEDIFF(MILLISECOND, 0, laptime)), 0), 114) AS total_time_on_track
FROM LiveTiming..driver AS d
	JOIN LiveTiming..lap AS l ON l.id_driver = d.id_driver
	JOIN LiveTiming..track AS t ON t.id_track = l.id_track
WHERE date_time BETWEEN '2019-11-15' AND '2019-11-16'
	AND track_name = 'Autódromo José Carlos Pace'
GROUP BY driver_name
ORDER BY best_time

-- 2
SELECT DISTINCT driver_name,
	(SELECT MIN(laptime) FROM LiveTiming..lap
		JOIN LiveTiming..driver ON LiveTiming..lap.id_driver = d.id_driver
	WHERE lap_info = 'Q1'
		AND date_time BETWEEN '2019-11-16' AND '2019-11-17'
		AND track_name = 'Autódromo José Carlos Pace'
	) AS Q1, 
	(SELECT MIN(laptime) FROM LiveTiming..lap
		JOIN LiveTiming..driver ON LiveTiming..lap.id_driver = d.id_driver
	WHERE lap_info = 'Q2'
		AND date_time BETWEEN '2019-11-16' AND '2019-11-17'
		AND track_name = 'Autódromo José Carlos Pace'
	) AS Q2,
		(SELECT MIN(laptime) FROM LiveTiming..lap
		JOIN LiveTiming..driver ON LiveTiming..lap.id_driver = d.id_driver
	WHERE lap_info = 'Q3'
		AND date_time BETWEEN '2019-11-16' AND '2019-11-17'
		AND track_name = 'Autódromo José Carlos Pace'
	) AS Q3
FROM LiveTiming..driver AS d
	JOIN LiveTiming..lap AS l ON l.id_driver = d.id_driver
	JOIN LiveTiming..track AS t ON t.id_track = l.id_track
ORDER BY Q3, Q2, Q1
-- ORDER BY Q3 ASC NULLS LAST

-- 3
SELECT driver_name, d.id_driver AS driver_number, team_name, MIN(laptime) AS fastest_lap, COUNT(*) AS number_of_laps
	 , LiveTiming.dbo.race_length(d.id_driver, '2019-11-17', '2019-11-18', 'Autódromo José Carlos Pace') AS race_time
	 , LiveTiming.dbo.calculate_diff(LiveTiming.dbo.race_length(d.id_driver, '2019-11-17', '2019-11-18', 'Autódromo José Carlos Pace'),
		(SELECT DISTINCT MIN(LiveTiming.dbo.race_length(id_driver, '2019-11-17', '2019-11-18', 'Autódromo José Carlos Pace')) FROM LiveTiming..lap))
	   AS diff_to_leader
	 , RANK() OVER (ORDER BY (LiveTiming.dbo.race_length(d.id_driver, '2019-11-17', '2019-11-18', 'Autódromo José Carlos Pace')) DESC) AS pts
FROM LiveTiming..driver AS d
	JOIN LiveTiming..lap AS l ON l.id_driver = d.id_driver
	JOIN LiveTiming..track AS t ON t.id_track = l.id_track
	JOIN LiveTiming..team AS te ON te.id_team = d.id_team
WHERE date_time BETWEEN '2019-11-17' AND '2019-11-18'
	AND track_name = 'Autódromo José Carlos Pace'
GROUP BY driver_name, team_name, d.id_driver
HAVING COUNT(*) = 71
ORDER BY race_time

-- 4
SELECT  MIN(laptime) driver_fastest_lap, driver_name, car_name, bhp, curb_weight, manufacturer_name, engine_signature FROM LiveTiming..lap AS l
	JOIN LiveTiming..driver AS d ON d.id_driver = l.id_driver
	JOIN LiveTiming..track AS t ON t.id_track = l.id_track
	JOIN LiveTiming..car AS c ON c.id_car = l.id_car
	JOIN LiveTiming..manufacturer AS m ON m.id_manufacturer = c.id_manufacturer
	JOIN LiveTiming..engine AS e ON e.id_engine = c.id_engine
WHERE track_name = 'Autódromo José Carlos Pace'
GROUP BY driver_name, car_name, bhp, curb_weight, manufacturer_name, engine_signature
ORDER BY driver_fastest_lap

-- 5
SELECT
	 MIN(split1) AS fastest_split1, MIN(split2) AS fastest_split2, MIN(split3) AS fastest_split3
	, CONVERT(varchar, DATEADD(MILLISECOND, (DATEDIFF(MILLISECOND, 0, MIN(split1)) + DATEDIFF(MILLISECOND, 0, MIN(split2)) + DATEDIFF(MILLISECOND, 0, MIN(split3))), 0), 114) 
		AS possible_fastest_time
FROM LiveTiming..lap AS l
	JOIN LiveTiming..driver AS d ON d.id_driver = l.id_driver
	JOIN LiveTiming..track AS t ON t.id_track = l.id_track
WHERE track_name = 'Autódromo José Carlos Pace'

-- 6
SELECT team_name
   , RANK() OVER (ORDER BY SUM(DATEDIFF(MILLISECOND, 0, (LiveTiming.dbo.race_length(d.id_driver, '2019-11-17', '2019-11-18', 'Autódromo José Carlos Pace')))) DESC) AS pts
FROM LiveTiming..team AS te
JOIN LiveTiming..driver AS d ON d.id_team = te.id_team
GROUP BY team_name
ORDER BY pts DESC

-- 7
SELECT d.driver_name, COUNT(*) AS number_of_records FROM LiveTiming..lap l
JOIN LiveTiming..driver AS d ON d.id_driver = l.id_driver
WHERE l.laptime IN (SELECT DISTINCT MIN(laptime) OVER (PARTITION BY id_track) FROM LiveTiming..lap)
GROUP BY d.driver_name

-- 8
SELECT t.track_name, l.laptime
	, DATEDIFF(YEAR, l.date_time, GETDATE()) AS years_since_record
	, DATEDIFF(DAY, l.date_time, GETDATE()) AS days_since_record
	, d.driver_name, engine_signature, engine_type, e.displacement AS displacement_cc, e.bhp, c.drivetrain, c.curb_weight AS weight_kg
FROM LiveTiming..lap l
	JOIN LiveTiming..driver AS d ON d.id_driver = l.id_driver
	JOIN LiveTiming..track AS t ON t.id_track = l.id_track
	JOIN LiveTiming..car AS c ON c.id_car = l.id_car
	JOIN LiveTiming..engine AS e ON e.id_engine = c.id_engine
WHERE l.laptime IN (SELECT DISTINCT MIN(laptime) OVER (PARTITION BY id_track) FROM LiveTiming..lap)
ORDER BY days_since_record DESC

-- 9
SELECT DISTINCT track_name
	, LiveTiming.dbo.percentage_drivetrain_on_track(l.id_track, 'AWD') AS awd_percentage
	, LiveTiming.dbo.percentage_drivetrain_on_track(l.id_track, 'FWD') AS fwd_percentage
	, LiveTiming.dbo.percentage_drivetrain_on_track(l.id_track, 'RWD') AS rwd_percentage
FROM LiveTiming..lap AS l
JOIN LiveTiming..track AS t ON t.id_track = l.id_track

-- 10
SELECT engine_signature, engine_type, displacement, bhp,
	ROUND(bhp / (CAST(displacement AS float) / 1000), 2) AS [bhp/1l]
FROM LiveTiming..engine
ORDER BY [bhp/1l] DESC

-- 11
SELECT car_name, c.curb_weight, e.bhp, e.engine_type, e.displacement, c.drivetrain,
	ROUND(bhp / CAST(curb_weight AS float), 2) AS [hp/kg]
FROM LiveTiming..car AS c
JOIN LiveTiming..engine AS e ON c.id_engine = e.id_engine
ORDER BY [hp/kg] DESC

-- 12
SELECT DATEPART(Q, date_time) AS quarter
	, (CONVERT(varchar, DATEADD(MILLISECOND, AVG(DATEDIFF(MILLISECOND, 0, laptime)), 0), 114)) AS avg_time
FROM LiveTiming..lap AS l
JOIN LiveTiming..track AS t ON t.id_track = l.id_track
JOIN LiveTiming..driver AS d ON d.id_driver = l.id_driver
WHERE track_name = 'Yas Marina Circuit'
AND driver_name = 'Max Verstappen'
AND l.date_time BETWEEN '2019-01-01' AND '2020-01-01'
GROUP BY DATEPART(Q, date_time)

-- 13
SELECT n.country_name, COUNT(*) AS number_of_records FROM LiveTiming..lap l
JOIN LiveTiming..driver AS d ON d.id_driver = l.id_driver
JOIN LiveTiming..nationality AS n ON n.id_nationality = d.id_nationality
WHERE l.laptime IN (SELECT DISTINCT MIN(laptime) OVER (PARTITION BY id_track) FROM LiveTiming..lap)
GROUP BY n.country_name

-- 14
SELECT DISTINCT track_name
	, DATEPART(YEAR, date_time) AS [year]
	, (CONVERT(varchar, DATEADD(MILLISECOND, AVG(DATEDIFF(MILLISECOND, 0, laptime)), 0), 114)) AS avg_time
	, ROUND((MIN(t.track_length) * 1000 / AVG(DATEDIFF(SECOND, 0, laptime)) * 3.6), 2) AS [avg_speed_km/h]
	, COUNT(*) number_of_laps
	, COUNT(*) / 365.0 AS avg_no_laps_per_day
FROM LiveTiming..lap AS l
JOIN LiveTiming..track AS t ON t.id_track = l.id_track
GROUP BY track_name,  DATEPART(YEAR, date_time)

-- 15
SELECT DISTINCT track_name, car_name, DATEPART(YEAR, date_time) AS year, DATEPART(Q, date_time) as quarter, COUNT(*) as no
FROM LiveTiming..lap AS l
JOIN LiveTiming..track AS t ON t.id_track = l.id_track
JOIN LiveTiming..car AS c ON c.id_car = l.id_car
GROUP BY track_name, car_name, DATEPART(Q, date_time), DATEPART(YEAR, date_time)
ORDER BY year, quarter, no DESC

-- PROCEDURE 1 TEST
SELECT * FROM LiveTiming..lap
WHERE id_driver = 14
AND date_time BETWEEN '2019-01-01' AND '2019-04-29'

EXEC LiveTiming.dbo.update_laps_info 14, '2019-01-01 11:00:00', '2019-04-29'

EXEC LiveTiming.dbo.update_laps_info 14, '2019-01-01', '2019-04-29', NULL

-- PROCEDURE 2 TEST
EXEC LiveTiming.dbo.filter_cars 'V6', 1, 'RWD', 1600, 722

SELECT * FROM LiveTiming..filtered_cars

SELECT c.car_name, c.curb_weight, c.drivetrain, e.bhp, e.displacement, e.engine_type, e.turbo FROM LiveTiming..car AS c
JOIN LiveTiming..engine AS e ON e.id_engine = c.id_engine
JOIN LiveTiming..filtered_cars AS fc ON fc.id_car = c.id_car

-- PROCEDURE 3 TEST
EXEC LiveTiming.dbo.insert_driver 'test_driver_name', 'test_country', 'test_team', 'test_url'

SELECT * FROM LiveTiming..driver AS d
JOIN LiveTiming..team AS t ON t.id_team = d.id_team
JOIN LiveTiming..nationality AS n ON n.id_nationality = d.id_nationality
WHERE driver_name = 'test_driver_name'

-- TRIGGER 1 TEST
SELECT * FROM LiveTiming..lap 
WHERE id_lap IN (1926, 1925, 1924)
OR lap_info = 'DSQ'

-- TRIGGER 2 TEST
SELECT * FROM LiveTiming..engine

UPDATE LiveTiming..engine
SET bhp = 999
WHERE id_engine = 4

-- TRIGGER 3 TEST
SELECT * FROM LiveTiming..driver WHERE driver_name = 'Robert Kubica'
SELECT * FROM LiveTiming..team WHERE team_name = 'ROKiT Williams Racing'
SELECT * FROM LiveTiming..nationality WHERE country_name = 'Poland'

--DELETE FROM LiveTiming..driver WHERE driver_name = 'Robert Kubica'

