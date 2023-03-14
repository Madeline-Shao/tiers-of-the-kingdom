# Tiers of the Kingdom
By Madeline Shao

Tiers of the Kingdom is a tier list maker that uses an SQL database and a command line app.
Users can create tierlists for Nintendo video games.

Data sourced from https://www.kaggle.com/datasets/codefantasy/list-of-best-selling-nintendo-games.

## Loading data
To load data, in MySQL, run the following:
```
CREATE DATABASE tierlistdb;
USE tierlistdb;
source setup.sql;
source load-data.sql;
source setup-routines.sql;
source setup-passwords.sql;
source grant-permissions.sql;
```

## Running the app
To run the command line app, run
`python3 app.py`
