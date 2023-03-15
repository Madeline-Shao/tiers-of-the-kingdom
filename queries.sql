-- Queries for the program

-- 1. Simple select queries
-- Selecting all columns from video_game with sorting and filtering
-- (where publisher is Nintendo and sorted by release date asc.
SELECT * FROM video_game
WHERE publisher = 'Nintendo' ORDER BY release_date ASC;

-- Selects all columns from tierlist, ordered by username asc
SELECT * FROM tierlist ORDER BY username;

-- Selecting the names of all the tierlists a user has.
SELECT tierlist_name FROM tierlist WHERE username = 'testuser';

-- Selects all columns from tier
SELECT * FROM tier;

-- 2. Simple insert, update, delete statements
-- Add a new user
CALL sp_add_user('testuser2', 'testpw2');

-- Add a new video game, equivalent to:
-- INSERT INTO
--     video_game (game_name, developer, publisher, 
--                  release_date, sales, platform)
--     VALUES
--     ('testgame', 'devel', 'publisher', '2020-01-01', 1, 'Nintendo Switch')
CALL sp_insert_video_game('testgame', 'devel', 'publisher', 
                        '2020-01-01', 1, 'Nintendo Switch');

-- Add a new tier, equivalent to:
-- INSERT INTO tier (tier_rank, tier_name, color) VALUES
--     (8, 'G', 'white')
CALL sp_insert_tier(8, 'G', 'white');

-- Create a new tierlist, equivalent to:
-- INSERT INTO tierlist VALUES
--     ('testuser', 'testtierlist3', CURDATE())
CALL sp_insert_tierlist('testuser', 'testtierlist3');

-- Assign or update a game to a tier for a tierlist, equivalent to:
-- INSERT INTO game_tier VALUES
--     ('testuser', 'testtierlist3', 1, 1)
--     ON DUPLICATE KEY UPDATE
--         tier_id = 1
CALL sp_update_game_tier('testuser', 'testtierlist3', 1, 1);

-- Update sales of a video game, equivalent to:
-- UPDATE video_game
--     SET sales = 100
--     WHERE game_id = 431
CALL sp_update_video_game_sales(431, 100);

-- Delete a game from a tierlist, equivalent to:
-- DELETE FROM game_tier
-- WHERE username = 'testuser' AND tierlist_name = 'testtierlist3'
-- AND game_id = 1
CALL sp_delete_game_tier('testuser', 'testtierlist3', 1);

-- Delete a tierlist, equivalent to:
-- DELETE FROM tierlist
-- WHERE username = 'testuser' AND tierlist_name = 'testtierlist3'
CALL sp_delete_tierlist('testuser', 'testtierlist3');



-- 3. More complex queries
-- Selecting the game name and stats (avg, min, max rank)
-- from the view, filtering by the name of a game and 
-- ordered by avg rank asc
SELECT game_name, avg_rank, min_rank, max_rank 
FROM game_rank_stats JOIN video_game USING(game_id) 
WHERE game_name='super mario world' ORDER BY avg_rank ASC;

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
