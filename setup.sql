-- DDL for the database, including indexes defined after DDL

-- DROP TABLE commands:
DROP TABLE IF EXISTS game_tier;
DROP TABLE IF EXISTS tierlist;
DROP TABLE IF EXISTS tier;
DROP TABLE IF EXISTS video_game;
DROP TABLE IF EXISTS user_info;

-- CREATE TABLE commands:
-- Table representing a video game. All attributes except sales are
-- not null
CREATE TABLE video_game (
    game_id SERIAL PRIMARY KEY,
    game_name VARCHAR(125) NOT NULL,
    -- ex: Nintendo EAD
    developer VARCHAR(75) NOT NULL,
    -- ex: Nintendo
    publisher VARCHAR(50) NOT NULL,
    release_date DATE NOT NULL,
    -- number of sales. Can be null if game is not released yet
    sales INT,
    -- ex: Nintendo DS
    platform VARCHAR(50) NOT NULL
);

-- This table holds information for authenticating users based on
-- a password.  Passwords are not stored plaintext so that they
-- cannot be used by people that shouldn't have them.
-- You may extend that table to include an is_admin or role attribute if you
-- have admin or other roles for users in your application
-- (e.g. store managers, data managers, etc.)
CREATE TABLE user_info (
    -- Usernames are up to 20 characters.
    username VARCHAR(20) PRIMARY KEY,
    -- Salt will be 8 characters all the time, so we can make this 8.
    salt CHAR(8) NOT NULL,
    -- We use SHA-2 with 256-bit hashes.  MySQL returns the hash
    -- value as a hexadecimal string, which means that each byte is
    -- represented as 2 characters.  Thus, 256 / 8 * 2 = 64.
    -- We can use BINARY or CHAR here; BINARY simply has a different
    -- definition for comparison/sorting than CHAR.
    password_hash BINARY(64) NOT NULL,
    -- 1 if is admin, 0 if not admin
    is_admin TINYINT NOT NULL DEFAULT 0,
    -- date the account was created
    date_registered DATE NOT NULL,
    CHECK (is_admin IN (0,1))
);

-- Table representing a tierlist belonging to a user. All attributes
-- are not null.
CREATE TABLE tierlist (
    username VARCHAR(20),
    tierlist_name VARCHAR(50),
    date_created DATE NOT NULL,
    -- username, tierlist_name is primary key since
    -- a tierlist name may not be unique between users, but is
    -- unique for one user
    PRIMARY KEY (username, tierlist_name),
    -- if a user account is deleted, their tierlists should be deleted
    FOREIGN KEY (username) REFERENCES user_info(username) ON DELETE CASCADE
);

-- Table representing a tier, common across all tierlists.
-- All attributes are not null
CREATE TABLE tier (
    tier_id SERIAL PRIMARY KEY,
    -- Highest tier is rank 1. Each tier should have a unique rank. Rank
    -- is not used as primary key since it is possible it could change.
    -- SMALLINT is used because rank should not be particularly large.
    tier_rank SMALLINT UNIQUE NOT NULL,
    tier_name VARCHAR(30) NOT NULL,
    color VARCHAR(30) NOT NULL DEFAULT 'gray'
);

-- Relation table representing what tier each object is in a particular
-- tierlist. All attributes are not null.
CREATE TABLE game_tier (
    username VARCHAR(20),
    tierlist_name VARCHAR(50),
    game_id BIGINT UNSIGNED,
    tier_id BIGINT UNSIGNED NOT NULL,
    -- username, tierlist_name, game_id is the primary key since a game can only appear
    -- once in a user's tierlist
    PRIMARY KEY (username, tierlist_name, game_id),
    -- Object tier should be deleted if any of the foreign keys are deleted.
    FOREIGN KEY (username, tierlist_name) REFERENCES tierlist(username, tierlist_name) ON DELETE CASCADE,
    FOREIGN KEY (game_id) REFERENCES video_game(game_id) ON DELETE CASCADE,
    FOREIGN KEY (tier_id) REFERENCES tier(tier_id) ON DELETE CASCADE
);

-- Index
CREATE INDEX idx_platform ON video_game(platform);
