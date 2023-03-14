-- Stored routines and triggers
-- These should be chosen appropriately; remember that a UDF function returns
-- a single value, not a set of values. If you have an un-parameterized 
-- procedure that does not modify any data, then it is probably better defined as a VIEW.

DROP FUNCTION IF EXISTS get_avg_game_rank;
DROP PROCEDURE IF EXISTS sp_update_game_tier;
DROP PROCEDURE IF EXISTS sp_delete_game_tier;
DROP PROCEDURE IF EXISTS sp_insert_tierlist;
DROP PROCEDURE IF EXISTS sp_delete_tierlist;
DROP PROCEDURE IF EXISTS sp_update_tier;
DROP PROCEDURE IF EXISTS sp_update_video_game;

-- Gets the average rank of a given game from all the tierlists in the 
-- database.
DELIMITER !
CREATE FUNCTION get_avg_game_rank(game_name VARCHAR(125))
RETURNS FLOAT DETERMINISTIC
BEGIN
    DECLARE authenticate TINYINT DEFAULT 0;
    
    SELECT IF(count(*) = 1, 1, 0) FROM user_info WHERE user_info.username = username AND password_hash = SHA2(CONCAT(salt, password), 256) INTO authenticate;
    RETURN authenticate;
END !
DELIMITER ;



-- Client procedures
-- Inserts or updates a new game tier into game_tier
DELIMITER !
CREATE PROCEDURE sp_update_game_tier(username VARCHAR(20), tierlist_name VARCHAR(50), 
                    game_id BIGINT UNSIGNED, tier_id BIGINT UNSIGNED)
BEGIN
    INSERT INTO game_tier VALUES 
        (username, tierlist_name, game_id, tier_id) 
    ON DUPLICATE KEY UPDATE 
        tier_id = tier_id;
END !
DELIMITER ;


-- Deletes a game tier from game_tier
DELIMITER !
CREATE PROCEDURE sp_delete_game_tier(username VARCHAR(20), tierlist_name VARCHAR(50), 
                    game_id BIGINT UNSIGNED)
BEGIN
    DELETE FROM game_tier WHERE 
        username = username AND 
        tierlist_name = tierlist_name AND
        game_id = game_id;
END !
DELIMITER ;


-- Inserts a new tierlist
DELIMITER !
CREATE PROCEDURE sp_insert_tierlist(username VARCHAR(20), tierlist_name VARCHAR(50))
BEGIN
    INSERT INTO tierlist VALUES 
        (username, tierlist_name);
--     ON DUPLICATE KEY UPDATE 
--         tier_id = tier_id;
END !
DELIMITER ;

-- Deletes a tierlist
DELIMITER !
CREATE PROCEDURE sp_delete_tierlist(username VARCHAR(20), tierlist_name VARCHAR(50))
BEGIN
    DELETE FROM tierlist WHERE 
        username = username AND 
        tierlist_name = tierlist_name;
END !
DELIMITER ;

-- Admin procedures
-- Insert or updates a tier
DELIMITER !
CREATE PROCEDURE sp_update_tier(tier_id BIGINT UNSIGNED, tier_rank SMALLINT, 
                                tier_name VARCHAR(30), color VARCHAR(30))
BEGIN
    INSERT INTO tier VALUES 
        (tier_id, tier_rank, tier_name, color)
    ON DUPLICATE KEY UPDATE 
        tier_rank = tier_rank,
        tier_name = tier_name,
        color = color;
END !
DELIMITER ;

-- Insert or updates a video game
DELIMITER !
CREATE PROCEDURE sp_update_video_game(game_id BIGINT UNSIGNED, 
                game_name VARCHAR(125), developer VARCHAR(75), 
                publisher VARCHAR(50), release_date DATE, sales INT, 
                platform VARCHAR(50))
BEGIN
    INSERT INTO video_game VALUES 
        (game_id, game_name, developer, publisher, release_date, sales, 
            platform)
    ON DUPLICATE KEY UPDATE 
        game_name = game_name,
        developer = developer,
        publisher = publisher,
        release_date = release_date,
        sales = sales,
        platform = platform;
END !
DELIMITER ;




-- CREATE INDEX idx_branch_name ON account(branch_name)

DROP TABLE IF EXISTS mv_game_rank_stats;

-- Materialized view for summary of rank stats of each video game
CREATE TABLE mv_game_rank_stats (
    game_id BIGINT UNSIGNED,
    -- number of tierlists that have ranked this game
    num_ranked INT NOT NULL,
    -- the sum of all the ranks the game has been given
    sum_rank INT NOT NULL, 
    min_rank INT NOT NULL,
    max_rank INT NOT NULL,
    PRIMARY KEY (game_id)
);


-- Set up the materialized view
INSERT INTO mv_game_rank_stats 
SELECT game_id, COUNT(tier_rank), SUM(tier_rank), MIN(tier_rank), 
    MAX(tier_rank)
FROM game_tier JOIN tier USING (tier_id)
GROUP BY game_id;


-- Create the view based on the materialized view
DROP VIEW IF EXISTS game_rank_stats;
CREATE VIEW game_rank_stats AS
    SELECT 
        game_id,
        num_ranked,
        -- sum_rank,
        -- Calculate avg from total and num
        sum_rank / num_ranked AS avg_rank,
        min_rank,
        max_rank
    FROM mv_game_rank_stats;


DROP PROCEDURE IF EXISTS sp_gamestat_newgametier;
DROP TRIGGER IF EXISTS trg_gametier_insert;

DELIMITER !

-- A procedure to execute when inserting a new game tier
-- to the game rank stats materialized view (mv_game_rank_stats).
-- If a game is already in view, its current rank is updated
-- to account for total rank and adjusted min/max ranks.
CREATE PROCEDURE sp_gamestat_newgametier(
    new_game_id BIGINT UNSIGNED,
    new_tier_id BIGINT UNSIGNED
)
BEGIN 
    DECLARE new_tier_rank SMALLINT DEFAULT NULL;
    
    SELECT tier_rank FROM tier 
    WHERE tier_id = new_tier_id INTO new_tier_rank;
    
    
    INSERT INTO mv_game_rank_stats 
        -- game not already in view; add row
        VALUES (new_game_id, 1, new_tier_rank, new_tier_rank, new_tier_rank)
    ON DUPLICATE KEY UPDATE 
        -- game already in view; update existing row
        num_ranked = num_ranked + 1,
        sum_rank = sum_rank + new_tier_rank,
        min_rank = LEAST(min_rank, new_tier_rank),
        max_rank = GREATEST(max_rank, new_tier_rank);
END !

-- Handles new rows added to account table, updates stats accordingly
CREATE TRIGGER trg_gametier_insert AFTER INSERT
       ON game_tier FOR EACH ROW
BEGIN
    CALL sp_gamestat_newgametier(NEW.game_id, NEW.tier_id);
END !
DELIMITER ;


DROP PROCEDURE IF EXISTS sp_gamestat_delgametier;
DROP TRIGGER IF EXISTS trg_gametier_delete;

DELIMITER !

-- A procedure to execute when deleting a new game and its tier
-- to the game rank stats materialized view (mv_game_rank_stats).
-- If the game tier is the last one for the game, then the game's entry
-- is deleted. Otherwise, its current rank stats are updated
-- to account for total rank and adjusted min/max ranks.
CREATE PROCEDURE sp_gamestat_delgametier(
    old_game_id BIGINT UNSIGNED,
    old_tier_id BIGINT UNSIGNED
)
BEGIN 
    DECLARE new_min_rank SMALLINT DEFAULT NULL;
    DECLARE new_max_rank SMALLINT DEFAULT NULL;
    DECLARE old_tier_rank SMALLINT DEFAULT NULL;
    
    -- Check if the game tier was the last one in the game (since after
    -- row trigger, should be deleted from game_tier already). If so, 
    -- delete the game from the MV.
    IF old_game_id NOT IN (SELECT DISTINCT game_id FROM game_tier) THEN
        DELETE FROM mv_game_rank_stats 
            WHERE game_id = old_game_id;
    ELSE
        -- If game tier is not the last one in the game, update the stats.
        -- Find the new min and max rank for that game.
        SELECT min(tier_rank), max(tier_rank) 
        FROM game_tier JOIN tier USING(tier_id)
        WHERE game_id = old_game_id INTO new_min_rank, new_max_rank;
        
        SELECT tier_rank 
        FROM tier
        WHERE tier_id = old_tier_id INTO old_tier_rank;
        
        UPDATE mv_game_rank_stats
        SET
            num_ranked = num_ranked - 1,
            sum_rank = sum_rank - old_tier_rank,
            min_rank = new_min_rank,
            max_rank = new_max_rank
        WHERE game_id = old_game_id;
    END IF;
END !

-- Handles rows deleted from game tier table, updates stats accordingly
CREATE TRIGGER trg_gametier_delete AFTER DELETE
       ON game_tier FOR EACH ROW
BEGIN
    CALL sp_gamestat_delgametier(OLD.game_id, OLD.tier_id);
END !
DELIMITER ;


DROP PROCEDURE IF EXISTS sp_gamestat_updategametier;
DROP TRIGGER IF EXISTS trg_gametier_update;

DELIMITER !

-- A procedure to execute when updating a game tier
-- to the game rank stats materialized view (mv_game_rank_stats).
-- The current rank stats are updated
-- to account for total rank and adjusted min/max ranks.
CREATE PROCEDURE sp_gamestat_updategametier(
    old_game_id BIGINT UNSIGNED,
    old_tier_id BIGINT UNSIGNED,
    new_game_id BIGINT UNSIGNED,
    new_tier_id BIGINT UNSIGNED
)
BEGIN 
    -- Update is same as deleting old row and inserting again with new values
    CALL sp_gamestat_delgametier(old_game_id, old_tier_id);
    CALL sp_gamestat_newgametier(new_game_id, new_tier_id);
END !

-- Handles rows updated in game_tier table, updates stats accordingly
CREATE TRIGGER trg_gametier_update AFTER UPDATE
       ON game_tier FOR EACH ROW
BEGIN
    CALL sp_gamestat_updategametier(OLD.game_id, OLD.tier_id, 
                                  NEW.game_id, NEW.tier_id);
END !
DELIMITER ;

