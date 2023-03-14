-- Load database (local load with uploaded csv files

LOAD DATA LOCAL INFILE 'seattle_hosts.csv' INTO TABLE hosts
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 ROWS; -- If your CSV file has a row with column names
