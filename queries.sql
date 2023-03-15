-- Queries for the program

-- 1. Simple select queries
-- Selects all columnsfrom video_game
SELECT * FROM video_game;

-- Selects username, is_admin, date_registered from user_info
SELECT username, is_admin, date_registered FROM user_info;

-- Selects all columns from tierlist
SELECT * FROM tierlist;

-- Selects all columns from tier
SELECT * FROM tier;

-- Selects all columns from game_tier
SELECT * FROM game_tier;

-- 2. Simple insert, update, delete statements
-- Add a new user
CALL sp_add_user('testuser2', 'testpw2');

-- Add a new video game
INSERT INTO
    video_game (game_name, developer, publisher, release_date, sales, platform)
    VALUES
    ('testgame', 'devel', 'publisher', '2020-01-01', 1, 'Nintendo Switch');

-- Add a new tier
INSERT INTO tier (tier_rank, tier_name, color) VALUES
    (8, 'G', 'white');

-- Create a new tierlist
INSERT INTO tierlist VALUES
    ('testuser', 'testtierlist3', CURDATE());

-- Assign or update a game to a tier for a tierlist
INSERT INTO game_tier VALUES
    ('testuser', 'testtierlist3', 1, 1)
    ON DUPLICATE KEY UPDATE
        tier_id = 1;

-- Update sales of a video game
UPDATE video_game
    SET sales = 100
    WHERE game_name = 'testgame';

-- Delete a game from a tierlist
DELETE FROM game_tier
WHERE username = 'testuser' AND tierlist_name = 'testtierlist3'
AND game_id = 1;

-- Delete a tierlist
DELETE FROM tierlist
WHERE username = 'testuser' AND tierlist_name = 'testtierlist3';



-- 3. More complex queries
-- Selecting the names of all the tierlists a user has.
SELECT tierlist_name FROM tierlist WHERE username = 'testuser';

-- Selecting data from video games with sorting and filtering
SELECT * FROM video_game
WHERE publisher = 'Nintendo' ORDER BY release_date DESC;

-- RA Expression: Get the average, min, and max rank for all games
-- published by Nintendo, grouped by platform, ordered by rank asc.
-- Using explain on this query shows that it uses the idx_platform
-- index.
SELECT platform, AVG(tier_rank) AS avg_rank, MIN(tier_rank) AS min_rank,
    MAX(tier_rank) AS max_rank
FROM game_tier JOIN video_game USING (game_id) JOIN tier USING (tier_id)
WHERE publisher = 'Nintendo'
GROUP BY platform ORDER BY avg_rank ASC;

-- RA Expression: For a tierlist named “testtierlist2” by a user named
-- “testuser”,
-- return all the names of the games in the tierlist along with their rank
-- and rank color.
-- Order by tier rank asc
SELECT game_name, tier_rank, color
FROM game_tier JOIN video_game USING (game_id) JOIN tier USING (tier_id)
WHERE username = 'testuser' AND tierlist_name = 'testtierlist2'
ORDER BY tier_rank ASC;
