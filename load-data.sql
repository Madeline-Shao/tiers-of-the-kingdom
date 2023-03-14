-- Load database (local load with uploaded csv files
SET GLOBAL local_infile = 'ON';

LOAD DATA LOCAL INFILE 'nintendo_video_games.csv' INTO TABLE video_game
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

-- Create test values for other tables
INSERT INTO user_info VALUES 
    ('testuser', '12345678', SHA2(CONCAT('12345678', 'testpw'), 256), 1, CURDATE());
    
INSERT INTO tierlist VALUES 
    ('testuser', 'testtierlist', CURDATE()),
    ('testuser', 'testtierlist2', CURDATE());
    
INSERT INTO tier (tier_rank, tier_name, color) VALUES 
    (1, 'S', 'red'),
    (2, 'A', 'orange'),
    (3, 'B', 'yellow'),
    (4, 'C', 'green'),
    (5, 'D', 'blue'),
    (6, 'E', 'purple'),
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
    ('testuser', 'testtierlist2', 400, 1) -- switch
    ;
    