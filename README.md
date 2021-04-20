Instructions for setting up remote docker SSH.
Add the SSH user to the docker group to get privileges
Shouldn't need to configure the docker daemon over any ports or anything
Start the ssh-agent
ssh-add
ssh-add -ls

on the VM, install docker. install azure cli

# Introduction 
For initial environment setup

#Setting up local machine
docker  run  -v `pwd`:`pwd` -w `pwd` -it  terraform

#Need a compose file of different environments


version: "3.4"
services:
  mole-web:
    build:
      context: ./oxy-mole-ng
      args:
        API_URL: 'http:\/\/localhost:1258'
    container_name: mole-web
    image: iotpoc2018.azurecr.io/mole-web:${MOLE_APP_VERSION}-amd64
    networks:
      - default
    ports:
      #The host machine's port 5000 will host the web
      - "5000:8080"
  mole-api:
    build: ./Oxy.Mole.Api
    container_name: mole-api
    image: iotpoc2018.azurecr.io/mole-api:${MOLE_APP_VERSION}-amd64
    networks:
      - default
    ports:
      #The host machine's port 1258 will host the API
      - "1258:8080"
    environment:
      MOLE_APP__DBCONNECTION__SQLMOLECONTEXT: "data source=sql,1433;initial catalog=Mole;persist security info=True;user id=sa;password=${MOLE_APP_SQL_SA_PASSWORD};"
      MOLE_APP__DBCONNECTION__SQLDRILLTREKCONTEXT: "data source=OHYWSQL11-S;initial catalog=Mole;persist security info=True;user id=mole_user;password=${DRILLTREK_APP_SQL_SA_PASSWORD};"
      #A workaround to bypass the default authorization policy (requiring authorized user) - Mole-1842
      MOLE_ENV: "IoT"
      ASPNETCORE_URLS: "http://[::]:8080"
  mole-analytics:
    build: ./Oxy.Mole.Analytics
    container_name: mole-analytics
    image: iotpoc2018.azurecr.io/mole-analytics:${MOLE_APP_VERSION}-amd64
    networks:
      - default
    volumes:
      #For log and WITSML archive files
      - type: bind
        source: C:\temp
        target: /opt/app/log_files
    environment:
      #Connection string will be set using this environment variable
      MOLE_ENV: "iot"
      MOLE_INPUT: "scheduler"
      MOLE_APPOPTIONS__CONNECTIONSTRINGS__SQLMOLECONTEXT: "data source=mole-sql,1433;initial catalog=Mole;persist security info=True;user id=sa;password=${MOLE_APP_SQL_SA_PASSWORD};"
      MOLE_APPOPTIONS__APPSETTINGS__PYTHONEXEFILENAME: "/opt/app/mole-analytics/BPE_engine/main.py"
  #      WELL_API: ""

  mole-sql:
    build: ./Oxy.Mole.Sql
    container_name: mole-sql
    image: iotpoc2018.azurecr.io/mole-sql:${MOLE_APP_VERSION}-amd64
    networks:
      - default
    ports:
      - "1433:1433"
    volumes:
      #SQL Server stores its data files in /var/opt/mssql
      #We'll mount the file system of the Docker host (developer laptop) to this directory
      #This way, data will persist beyond the lifetime of the container
      - sqlVolume:/var/opt/mssql
    environment:
      #Connection string will be set using this environment variable
      SA_PASSWORD: "${MOLE_APP_SQL_SA_PASSWORD}"
      TZ: "America/Mexico_City"
volumes:
  sqlVolume:
networks:
  default:
    external: false
    driver: bridge
