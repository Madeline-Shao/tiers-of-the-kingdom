DROP USER IF EXISTS 'appadmin'@'localhost';
DROP USER IF EXISTS 'appclient'@'localhost';

FLUSH PRIVILEGES;

CREATE USER 'appadmin'@'localhost' IDENTIFIED BY 'admins';
CREATE USER 'appclient'@'localhost' IDENTIFIED BY 'clients';

GRANT ALL PRIVILEGES ON tierlistdb.* TO 'appadmin'@'localhost';
GRANT SELECT ON tierlistdb.* TO 'appclient'@'localhost';
GRANT INSERT, UPDATE, DELETE ON tierlistdb.user_info TO 'appclient'@'localhost';
GRANT INSERT, UPDATE, DELETE ON tierlistdb.tierlist TO 'appclient'@'localhost';
GRANT INSERT, UPDATE, DELETE ON tierlistdb.game_tier TO 'appclient'@'localhost';

FLUSH PRIVILEGES;
