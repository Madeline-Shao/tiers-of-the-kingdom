-- Load database (local load with uploaded csv files
SET GLOBAL local_infile = 'ON';

LOAD DATA LOCAL INFILE 'nintendo_video_games.csv' INTO TABLE video_game
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

-- Create test values for other tables
-- This is run before the add user routine in setup-passwords.sql is defined
INSERT INTO user_info VALUES
    -- admin user
    ('testuser', '12345678', SHA2('12345678testpw', 256), 1, CURDATE());

INSERT INTO tierlist VALUES
    ('testuser', 'testtierlist', CURDATE()),
    ('testuser', 'testtierlist2', CURDATE()),
    ('testuser', 'testtierlist4', CURDATE());

INSERT INTO tier (tier_rank, tier_name, color) VALUES
    (1, 'S', 'red'),
    (2, 'A', 'yellow'),
    (3, 'B', 'green'),
    (4, 'C', 'cyan'),
    (5, 'D', 'blue'),
    (6, 'E', 'magenta'),
    (7, 'F', 'gray');

INSERT INTO game_tier VALUES
    ('testuser', 'testtierlist', 1, 1), -- NES
    ('testuser', 'testtierlist', 2, 2),
    ('testuser', 'testtierlist', 3, 3),
    ('testuser', 'testtierlist', 4, 4),
    ('testuser', 'testtierlist', 5, 5),
    ('testuser', 'testtierlist', 80, 6),
    ('testuser', 'testtierlist2', 80, 1), -- 64
    ('testuser', 'testtierlist2', 120, 2), -- gameboy
    ('testuser', 'testtierlist2', 160, 3), -- gamecube
    ('testuser', 'testtierlist2', 200, 4), -- ds
    ('testuser', 'testtierlist2', 240, 5), -- ds
    ('testuser', 'testtierlist2', 280, 6), -- wii
    ('testuser', 'testtierlist2', 320, 7), -- 3ds
    ('testuser', 'testtierlist2', 360, 1), -- 3ds
    ('testuser', 'testtierlist2', 400, 1), -- 
    ('testuser', 'testtierlist4', 31, 1),
    ('testuser', 'testtierlist4', 33, 1),
    ('testuser', 'testtierlist4', 32, 1),
    ('testuser', 'testtierlist4', 34, 1),
    ('testuser', 'testtierlist4', 35, 1),
    ('testuser', 'testtierlist4', 36, 1),
    ('testuser', 'testtierlist4', 37, 1),
    ('testuser', 'testtierlist4', 18, 1),
    ('testuser', 'testtierlist4', 39, 1),
    ('testuser', 'testtierlist4', 40, 1),
    ('testuser', 'testtierlist4', 41, 1),
    ('testuser', 'testtierlist4', 43, 1),
    ('testuser', 'testtierlist4', 42, 1),
    ('testuser', 'testtierlist4', 5, 1),
    ('testuser', 'testtierlist4', 51, 1),
    ('testuser', 'testtierlist4', 52, 1),
    ('testuser', 'testtierlist4', 53, 1),
    ('testuser', 'testtierlist4', 54, 1),
    ('testuser', 'testtierlist4', 55, 1),
    ('testuser', 'testtierlist4', 56, 1),
    ('testuser', 'testtierlist4', 57, 1),
    ('testuser', 'testtierlist4', 430, 1)
    ;
