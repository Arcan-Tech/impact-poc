# Impact POC
This repository contains the base code for POC demonstrations of impact analysis, and in particular of the `impact-change-propagation-model` repository.

# Installing
To install run the following commands:
```bash
sudo apt install apache2-utils
./run.sh create_user [username] [password]
./run.sh setup_env
docker compose pull
```
This should set up a new `.env` file (if none other exists) and pull the images.
Note that if no username or password are provided for the application, `arcan` will be used as default username and a randomly generated string as password.
Credentials will be saved in `nginx/.htpasswd` in plain text for reference.

# Running
Simply run `docker compose up` and the dashboard should be available on the configured port (usually `8000`).
Use the credent

# Loading datasets
Loading datasets mean you need to have a Neo4j dump file and put it into the `datasets` folder.
Next, you can run:
```bash
./run switch_dataset datasets/<FILE>
```
Wait until the script stops neo4j, loads the dataset, and restarts the database.

# Restoring passwords
Just run
```bash
./run.sh create_user <username>
```
and it will replace the old password of the given user

