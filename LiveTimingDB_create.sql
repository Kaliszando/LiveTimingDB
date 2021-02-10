-- Adam Kalisz 224319
-- Jakub Janiszewski 210204

DROP DATABASE IF EXISTS LiveTiming
CREATE DATABASE LiveTiming
GO
CREATE TABLE LiveTiming..team
(
	id_team int IDENTITY(1,1),
	team_name varchar(255) NOT NULL,
	CONSTRAINT PK_team_id PRIMARY KEY (id_team),
	CONSTRAINT UQ_team_name UNIQUE (team_name)
)
GO
CREATE TABLE LiveTiming..nationality
(
	id_nationality int IDENTITY(1,1),
	country_name varchar(255) NOT NULL,
	flag_url varchar(255) NOT NULL,
	CONSTRAINT PK_nationality PRIMARY KEY (id_nationality),
	CONSTRAINT UQ_nationality_name UNIQUE (country_name),
	CONSTRAINT UQ_nationality_url UNIQUE (flag_url)
)
GO
CREATE TABLE LiveTiming..driver
(
	id_driver int IDENTITY(1,1),
	id_team int,
	id_nationality int,
	driver_name varchar(255) NOT NULL,
	CONSTRAINT PK_driver_id PRIMARY KEY (id_driver),
	CONSTRAINT FK_driver_team FOREIGN KEY (id_team) REFERENCES LiveTiming..team(id_team),
	CONSTRAINT FK_driver_nationality FOREIGN KEY (id_nationality) REFERENCES LiveTiming..nationality(id_nationality),
	CONSTRAINT UQ_driver_name UNIQUE (driver_name)
)
GO
CREATE TABLE LiveTiming..manufacturer
(
	id_manufacturer int IDENTITY(1,1),
	manufacturer_name varchar(255) NOT NULL,
	CONSTRAINT PK_manufacturer_id PRIMARY KEY (id_manufacturer),
	CONSTRAINT UQ_manufacturer_name UNIQUE (manufacturer_name)
)
GO
CREATE TABLE LiveTiming..track
(
	id_track int IDENTITY(1,1),
	track_name varchar(255) NOT NULL,
	track_length decimal(10, 3) NOT NULL
	CONSTRAINT PK_track_id PRIMARY KEY (id_track),
	CONSTRAINT UQ_track_name UNIQUE (track_name),
	CONSTRAINT CH_track_length CHECK (track_length > 0)
)
GO
CREATE TABLE LiveTiming..engine
(
	id_engine int IDENTITY(1,1),
	bhp smallint NOT NULL,
	engine_signature varchar(255),	
	engine_type varchar(5) NOT NULL,
	displacement smallint NOT NULL,
	turbo bit NOT NULL,
	CONSTRAINT PK_engine_id PRIMARY KEY (id_engine),
	CONSTRAINT CH_engine_bhp CHECK (bhp > 0),
	CONSTRAINT CH_engine_displacement CHECK (displacement > 0)
)
GO
CREATE TABLE LiveTiming..car
(
	id_car int IDENTITY(1,1),
	car_name varchar(255) NOT NULL,
	id_manufacturer int NOT NULL,
	id_engine int NOT NULL,
	drivetrain char(3) NOT NULL,
	curb_weight smallint NOT NULL,
	CONSTRAINT PK_car_id PRIMARY KEY (id_car),
	CONSTRAINT UQ_car_name UNIQUE (car_name),
	CONSTRAINT FK_car_manufacturer FOREIGN KEY (id_manufacturer) REFERENCES LiveTiming..manufacturer(id_manufacturer),
	CONSTRAINT FK_car_engine FOREIGN KEY (id_engine) REFERENCES LiveTiming..engine(id_engine),
	CONSTRAINT CH_car_drivetrain CHECK (drivetrain IN ('RWD', 'FWD', 'AWD')),
	CONSTRAINT CH_car_curb_weight CHECK (curb_weight > 0)
)
GO
CREATE TABLE LiveTiming..lap
(
	id_lap int IDENTITY(1,1),
	id_driver int NOT NULL,
	id_track int NOT NULL,
	id_car int NOT NULL,
	date_time datetime2 NOT NULL,
	laptime time NOT NULL,
	split1 time,
	split2 time,
	split3 time,
	abs_setting tinyint,
	traction_control_setting tinyint,
	esp bit,
	lap_info varchar(3),
	CONSTRAINT PK_lap_id PRIMARY KEY (id_lap),
	CONSTRAINT FK_lap_driver FOREIGN KEY (id_driver) REFERENCES LiveTiming..driver(id_driver),
	CONSTRAINT FK_lap_track FOREIGN KEY (id_track) REFERENCES LiveTiming..track(id_track),
	CONSTRAINT FK_lap_car FOREIGN KEY (id_car) REFERENCES LiveTiming..car(id_car),
	CONSTRAINT UQ_lap UNIQUE (id_driver, id_track, id_car, date_time),
	CONSTRAINT CH_lap_abs CHECK (abs_setting > 0),
	CONSTRAINT CH_lap_traction_control CHECK (traction_control_setting > 0),
	CONSTRAINT CH_lap_info CHECK (lap_info IN ('DNF', 'RET', 'DSQ', 'PIT', 'Q1', 'Q2', 'Q3'))
)
GO
USE LiveTiming
GO

-- FUNCTION 1
CREATE OR ALTER FUNCTION race_length(@id_driver int, @start_datetime datetime2, @end_datetime datetime2, @race_track varchar(255))
RETURNS time
AS
BEGIN
	DECLARE
		@length time = (
			SELECT CONVERT(varchar, DATEADD(MILLISECOND, SUM(DATEDIFF(MILLISECOND, 0, laptime)), 0), 114)
			FROM LiveTiming..lap AS l
			JOIN LiveTiming..track AS t ON l.id_track = t.id_track
			WHERE date_time BETWEEN @start_datetime AND @end_datetime
			AND track_name = @race_track
			AND id_driver = @id_driver
			GROUP BY id_driver
		)
	RETURN @length
END
GO

-- FUNCTION 2
CREATE OR ALTER FUNCTION calculate_diff(@time1 datetime2, @time2 datetime2)
RETURNS time
AS
BEGIN
	DECLARE 
		@milliseconds int = (DATEDIFF(MILLISECOND, @time2, @time1))
	DECLARE
		@time_diff time = (CONVERT(varchar, DATEADD(MILLISECOND, @milliseconds, 0), 114))

	RETURN @time_diff
END
GO

-- FUNCTION 3
CREATE OR ALTER FUNCTION percentage_drivetrain_on_track(@id_track int, @drivetrain char(3))
RETURNS DECIMAL(15, 2)
AS
BEGIN
	DECLARE
	@all float = (
		SELECT COUNT(*) FROM LiveTiming..lap AS l
			JOIN LiveTiming..car AS c ON l.id_car = c.id_car
			AND l.id_track = @id_track
		),
	@specific_counts float = (
		SELECT COUNT(*) FROM LiveTiming..lap AS l
			JOIN LiveTiming..car AS c ON l.id_car = c.id_car
			AND l.id_track = @id_track
		WHERE c.drivetrain = @drivetrain
	)
	RETURN (@specific_counts * 100) / @all
END
GO

-- PROCEDURE 1
CREATE OR ALTER PROCEDURE dbo.update_laps_info
	@id_driver int,
	@start datetime2,
	@end datetime2,
	@info char(3) = DSQ
AS
BEGIN
	UPDATE LiveTiming..lap
	SET lap_info = @info
	WHERE id_driver = @id_driver
	AND date_time BETWEEN @start AND @end
END
GO

-- PROCEDURE 2
CREATE OR ALTER PROCEDURE dbo.filter_cars
	@engine_type varchar(5),
	@turbo bit,
	@drivetrain char(3),
	@displacement int,
	@min_weight int = 0,
	@max_weight int = 100000,
	@min_bhp int = 0,
	@max_bhp int = 30000
AS
BEGIN
	IF EXISTS(SELECT * FROM sys.tables WHERE object_id = OBJECT_ID('dbo.filtered_cars'))
	DROP TABLE LiveTiming..filtered_cars

	SELECT id_car
	INTO LiveTiming..filtered_cars
	FROM LiveTiming..car AS c
	JOIN LiveTiming..engine AS e ON e.id_engine = c.id_engine
	WHERE e.engine_type = @engine_type
	AND e.turbo = @turbo
	AND c.drivetrain = @drivetrain
	AND e.displacement = @displacement
	AND c.curb_weight BETWEEN @min_weight AND @max_weight
	AND e.bhp BETWEEN @min_bhp AND @max_bhp
END
GO

-- PROCEDURE 3
CREATE OR ALTER PROCEDURE dbo.insert_driver
	@name varchar(255),
	@country_name varchar(255) = NULL,
	@team_name varchar(255) = NULL,
	@flag_url varchar(255) = NULL
AS
BEGIN
	DECLARE
		@id_country int = NULL,
		@id_team int = NULL

	IF(EXISTS (SELECT * FROM nationality WHERE country_name = @country_name))
	SET @flag_url = (
		SELECT flag_url FROM nationality WHERE country_name = @country_name
	)

	IF(@country_name IS NOT NULL AND NOT EXISTS (
	SELECT * FROM nationality WHERE @country_name = country_name))
			INSERT INTO nationality VALUES (@country_name, @flag_url)

	IF(@team_name IS NOT NULL AND NOT EXISTS (
	SELECT * FROM team WHERE @team_name = team_name))
			INSERT INTO team VALUES (@team_name)

	SET @id_country = (
		SELECT id_nationality FROM nationality
		WHERE country_name = @country_name AND flag_url = @flag_url
	)
	
	SET @id_team = (
		SELECT id_team FROM team
		WHERE team_name = @team_name
	)

	INSERT INTO driver(driver_name, id_nationality, id_team) VALUES (@name, @id_country, @id_team) 
END
GO

-- TRIGGER 1
CREATE OR ALTER TRIGGER dbo.lap_insert_trigger
ON LiveTiming..lap
AFTER INSERT
AS
BEGIN
	DECLARE @current_id_lap int

	DECLARE inserted_cursor CURSOR FOR
		SELECT id_lap FROM inserted

	OPEN inserted_cursor
	FETCH NEXT FROM inserted_cursor INTO @current_id_lap

	WHILE @@FETCH_STATUS = 0
	BEGIN
		DECLARE
		@total_millis int = (SELECT DATEDIFF(MILLISECOND, 0, laptime) FROM inserted WHERE id_lap = @current_id_lap),
		@split1_millis int = (SELECT DATEDIFF(MILLISECOND, 0, split1) FROM inserted WHERE id_lap = @current_id_lap),
		@split2_millis int = (SELECT DATEDIFF(MILLISECOND, 0, split2) FROM inserted WHERE id_lap = @current_id_lap),
		@split3_millis int = (SELECT DATEDIFF(MILLISECOND, 0, split3) FROM inserted WHERE id_lap = @current_id_lap)
		DECLARE
		@added_millis int =  @split1_millis + @split2_millis + @split3_millis

		IF(@total_millis - @added_millis NOT BETWEEN -6 AND 6)
		BEGIN
			PRINT('lap_id: ' + CAST(@current_id_lap AS varchar) + ' laptime invalidated')

			BEGIN
				UPDATE LiveTiming..lap
				SET lap_info = 'DSQ'
				WHERE id_lap = @current_id_lap
			END
		END
		FETCH NEXT FROM inserted_cursor INTO @current_id_lap
	END

	CLOSE inserted_cursor
	DEALLOCATE inserted_cursor
END
GO

-- TRIGGER 2
CREATE OR ALTER TRIGGER dbo.engine_update_trigger
ON LiveTiming..engine
INSTEAD OF UPDATE
AS
BEGIN
	IF UPDATE (bhp) OR UPDATE(engine_type) OR UPDATE(displacement) OR UPDATE(turbo)
	INSERT INTO LiveTiming..engine(bhp, engine_type, displacement, turbo, engine_signature) 
	SELECT bhp, engine_type, displacement, turbo, CONCAT(engine_signature, ' MODIFIED ', CAST(GETDATE() AS varchar))
	FROM inserted
END
GO

-- TRIGGER 3
CREATE OR ALTER TRIGGER dbo.driver_delete_tigger
ON LiveTiming..driver
INSTEAD OF DELETE
AS
BEGIN
	DECLARE 
		@id_driver int = (SELECT id_driver FROM deleted),
		@id_team int = (SELECT id_team FROM deleted),
		@id_nationality int = (SELECT id_nationality FROM deleted)

	IF NOT EXISTS (
		SELECT * FROM LiveTiming..driver AS d
		JOIN LiveTiming..team AS t ON t.id_team = d.id_team
		WHERE t.id_team = @id_team AND d.id_driver <> @id_driver
	)
	BEGIN
		ALTER TABLE LiveTiming..driver NOCHECK CONSTRAINT FK_driver_team
		DELETE FROM LiveTiming..team WHERE id_team = @id_team
		ALTER TABLE LiveTiming..driver CHECK CONSTRAINT FK_driver_team
	END

	IF NOT EXISTS (
		SELECT * FROM LiveTiming..driver AS d
		JOIN LiveTiming..nationality AS n ON n.id_nationality = d.id_nationality
		WHERE n.id_nationality = @id_nationality AND d.id_driver <> @id_driver
	)
	BEGIN
		ALTER TABLE LiveTiming..driver NOCHECK CONSTRAINT FK_driver_nationality
		DELETE FROM LiveTiming..nationality WHERE id_nationality = @id_nationality
		ALTER TABLE LiveTiming..driver CHECK CONSTRAINT FK_driver_nationality
	END

	ALTER TABLE LiveTiming..lap NOCHECK CONSTRAINT FK_lap_driver
	DELETE FROM LiveTiming..driver WHERE id_driver = @id_driver
	ALTER TABLE LiveTiming..lap CHECK CONSTRAINT FK_lap_driver
END
GO
GO

USE master