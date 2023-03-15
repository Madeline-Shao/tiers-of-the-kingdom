-- Stored routines and triggers
-- These should be chosen appropriately; remember that a UDF function returns
-- a single value, not a set of values. 

DROP FUNCTION IF EXISTS user_owns_tierlist;
DROP PROCEDURE IF EXISTS sp_update_game_tier;
DROP PROCEDURE IF EXISTS sp_delete_game_tier;
DROP PROCEDURE IF EXISTS sp_insert_tierlist;
DROP PROCEDURE IF EXISTS sp_delete_tierlist;
DROP PROCEDURE IF EXISTS sp_insert_tier;
DROP PROCEDURE IF EXISTS sp_insert_video_game;
DROP PROCEDURE IF EXISTS sp_update_video_game_sales;
DROP TABLE IF EXISTS mv_game_rank_stats;
DROP VIEW IF EXISTS game_rank_stats;
DROP PROCEDURE IF EXISTS sp_gamestat_newgametier;
DROP TRIGGER IF EXISTS trg_gametier_insert;
DROP PROCEDURE IF EXISTS sp_gamestat_delgametier;
DROP TRIGGER IF EXISTS trg_gametier_delete;
DROP PROCEDURE IF EXISTS sp_gamestat_updategametier;
DROP TRIGGER IF EXISTS trg_gametier_update;

-- Checks if the specified username owns a tierlist of the specified
-- tierlist name in the tierlist table.
-- Returns 1 if the username, tierlist_name pair appears in the table.
-- Otherwise returns 0.
DELIMITER !
CREATE FUNCTION user_owns_tierlist(input_username VARCHAR(20), input_tierlist_name VARCHAR(50))
RETURNS TINYINT DETERMINISTIC
BEGIN
    DECLARE tierlist_exists TINYINT DEFAULT 0;

    SELECT IF(count(*) = 1, 1, 0) FROM tierlist
    WHERE username = input_username AND
        tierlist_name = input_tierlist_name 
    INTO tierlist_exists;

    RETURN tierlist_exists;
END !
DELIMITER ;



-- Client procedures
-- Inserts (or updates on duplicate key) a new game tier into game_tier
DELIMITER !
CREATE PROCEDURE sp_update_game_tier(username VARCHAR(20),
                  tierlist_name VARCHAR(50),game_id BIGINT UNSIGNED,
                  new_tier_id BIGINT UNSIGNED)
BEGIN
    INSERT INTO game_tier VALUES
        (username, tierlist_name, game_id, new_tier_id)
    ON DUPLICATE KEY UPDATE
        tier_id = new_tier_id;
END !
DELIMITER ;


-- Deletes a game tier from game_tier
DELIMITER !
CREATE PROCEDURE sp_delete_game_tier(old_username VARCHAR(20),
                old_tierlist_name VARCHAR(50), old_game_id BIGINT UNSIGNED)
BEGIN
    DELETE FROM game_tier
        WHERE username = old_username AND tierlist_name = old_tierlist_name AND
        game_id = old_game_id;
END !
DELIMITER ;


-- Inserts a new tierlist
DELIMITER !
CREATE PROCEDURE sp_insert_tierlist(username VARCHAR(20),
                    tierlist_name VARCHAR(50))
BEGIN
    INSERT INTO tierlist VALUES
        (username, tierlist_name, CURDATE());
END !
DELIMITER ;

-- Deletes a tierlist
DELIMITER !
CREATE PROCEDURE sp_delete_tierlist(old_username VARCHAR(20),
                    old_tierlist_name VARCHAR(50))
BEGIN
    DELETE FROM tierlist
        WHERE username = old_username AND tierlist_name = old_tierlist_name;
END !
DELIMITER ;

-- Admin procedures
-- Inserts a tier into tier
DELIMITER !
CREATE PROCEDURE sp_insert_tier(tier_rank SMALLINT,
                                tier_name VARCHAR(30), color VARCHAR(30))
BEGIN
    INSERT INTO tier(tier_rank, tier_name, color) VALUES
        (tier_rank, tier_name, color);
END !
DELIMITER ;

-- Adds a new video game
DELIMITER !
CREATE PROCEDURE sp_insert_video_game(
                game_name VARCHAR(125), developer VARCHAR(75),
                publisher VARCHAR(50), release_date DATE, sales INT,
                platform VARCHAR(50))
BEGIN
    INSERT INTO video_game(game_name, developer, publisher, release_date, sales,
            platform) VALUES
        (game_name, developer, publisher, release_date, sales, platform);
END !
DELIMITER ;

-- Updates sales of a video game
DELIMITER !
CREATE PROCEDURE sp_update_video_game_sales(game_id BIGINT UNSIGNED, sales INT)
BEGIN
    UPDATE video_game SET sales = sales
        WHERE game_id = game_id;
END !
DELIMITER ;

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
CREATE VIEW game_rank_stats AS
    SELECT
        game_id,
        num_ranked,
        -- Calculate avg from total and num
        sum_rank / num_ranked AS avg_rank,
        min_rank,
        max_rank
    FROM mv_game_rank_stats;


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

-- Handles new rows added to game_tier table, updates stats accordingly
CREATE TRIGGER trg_gametier_insert AFTER INSERT
       ON game_tier FOR EACH ROW
BEGIN
    CALL sp_gamestat_newgametier(NEW.game_id, NEW.tier_id);
END !
DELIMITER ;


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
