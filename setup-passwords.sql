-- File for Password Management section of Final Project
-- (Provided) This function generates a specified number of characters for using as
-- a salt in passwords.
SET GLOBAL log_bin_trust_function_creators = 1;
DROP FUNCTION IF EXISTS make_salt;
DROP PROCEDURE IF EXISTS sp_add_user;
DROP FUNCTION IF EXISTS authenticate;
DROP PROCEDURE IF EXISTS sp_change_password;

DELIMITER !
CREATE FUNCTION make_salt(num_chars INT)
RETURNS VARCHAR(20) NOT DETERMINISTIC
BEGIN
    DECLARE salt VARCHAR(20) DEFAULT '';
    -- Don't want to generate more than 20 characters of salt.
    SET num_chars = LEAST(20, num_chars);
    -- Generate the salt!  Characters used are ASCII code 32 (space)
    -- through 126 ('z').
    WHILE num_chars > 0 DO
        SET salt = CONCAT(salt, CHAR(32 + FLOOR(RAND() * 95)));
        SET num_chars = num_chars - 1;
    END WHILE;
    RETURN salt;
END !
DELIMITER ;

-- [Problem 1a]
-- Adds a new user to the user_info table, using the specified password (max
-- of 20 characters). Salts the password with a newly-generated salt value,
-- and then the salt and hash values are both stored in the table.
DELIMITER !
CREATE PROCEDURE sp_add_user(new_username VARCHAR(20), password VARCHAR(20))
BEGIN
    DECLARE salt CHAR(8);
    DECLARE password_hash BINARY(64);
    
    -- create salt and get hashed password
    SET salt = make_salt(8);
    SET password_hash = SHA2(CONCAT(salt, password), 256); 
    
    -- add new record to user_info with username, salt, salted password
    -- assume that app has verified that username is available
    INSERT INTO user_info
        -- branch not already in view; add row
        VALUES (new_username, salt, password_hash, 0, CURDATE());
END !
DELIMITER ;

-- [Problem 1b]
-- Authenticates the specified username and password against the data
-- in the user_info table.  Returns 1 if the user appears in the table, and the
-- specified password hashes to the value for the user. Otherwise returns 0.
DELIMITER !
CREATE FUNCTION authenticate(username VARCHAR(20), password VARCHAR(20))
RETURNS TINYINT DETERMINISTIC
BEGIN
    DECLARE authenticate TINYINT DEFAULT 0;
    
    SELECT IF(count(*) = 1, 1, 0) FROM user_info WHERE user_info.username = username AND password_hash = SHA2(CONCAT(salt, password), 256) INTO authenticate;
    RETURN authenticate;
END !
DELIMITER ;

-- [Problem 1c]
-- Add at least two users into your user_info table so that when we run this file,
-- we will have examples users in the database.
-- use sp_add_user

CALL sp_add_user('princess_zelda', 'triforce');
CALL sp_add_user('link', 'mastersword');

-- [Problem 1d]
-- Optional: Create a procedure sp_change_password to generate a new salt and
-- change the given
-- user's password to the given password (after salting and hashing)
DELIMITER !
CREATE PROCEDURE sp_change_password(username VARCHAR(20), new_password VARCHAR(20))
BEGIN
    DECLARE salt CHAR(8);
    DECLARE password_hash BINARY(64);
    
    -- create salt and get hashed password
    SET salt = make_salt(8);
    SET password_hash = SHA2(CONCAT(salt, new_password), 256); 
    
    -- update with new password
    -- assume that app has verified that username already exists
    UPDATE user_info
        SET user_info.password_hash = password_hash, user_info.salt = salt
        WHERE user_info.username = username;
END !
DELIMITER ;