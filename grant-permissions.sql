CREATE USER 'appadmin'@'localhost' IDENTIFIED BY 'adminpw';
CREATE USER 'appclient'@'localhost' IDENTIFIED BY 'clientpw';

GRANT ALL PRVILEGES ON tierlistdb.* TO 'appadmin'@'localhost';
GRANT SELECT ON tierlistdb.* TO 'appclient'@'localhost';

FLUSH PRIVILEGES;
