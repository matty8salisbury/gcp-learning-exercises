#! bin/bash

#1. LOGIN, SET PROJECT AND ENABLE APIS

gcloud auth login matt@shinymenu.online
gcloud config set project shinymenu-test-01

gcloud services enable compute.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com

#2. CREATE VPC
#ALLOW INTERNAL NETWORKING AND OPEN TO HTTP AND HTTPS
#ZONE 

#3. CREATE VM
#TAG WITH NAME TO ALLOW FIREWALL RULES TO BE APPLIED IF NEEDED
#MACHINE TYPE EC2-MED
#ZONE europe-west2-c

#Create service account
gcloud iam service-accounts create vm1-sa-001 --display-name "vm1-sa-001 service account"

#Assign appropriate roles to the service account
gcloud projects add-iam-policy-binding shinymenu-test-01 --member serviceAccount:vm1-sa-001@shinymenu-test-01.iam.gserviceaccount.com --role roles/compute.instanceAdmin.v1
gcloud projects add-iam-policy-binding shinymenu-test-01 --member serviceAccount:vm1-sa-001@shinymenu-test-01.iam.gserviceaccount.com --role roles/iam.serviceAccountUser 
gcloud projects add-iam-policy-binding shinymenu-test-01 --member serviceAccount:vm1-sa-001@shinymenu-test-01.iam.gserviceaccount.com --role roles/storage.objectViewer 
gcloud projects add-iam-policy-binding shinymenu-test-01 --member serviceAccount:vm1-sa-001@shinymenu-test-01.iam.gserviceaccount.com --role roles/storage.admin

#CREATE STATIC IP

gcloud compute addresses create static-ip-business001 --region=europe-west2
STATIC_IP_ADDRESS = gcloud compute addresses describe static-ip-business001 --region=europe-west2 --format='get(address)'

#CREATE FIREWALL RULE TO OPEN PORT 3838
gcloud compute --project=shinymenu-test-01 firewall-rules create shiny-ingress --description="Open port 3838 for Shiny" --direction=INGRESS --priority=1000 --network=default --action=ALLOW --rules=tcp:3838 --source-ranges=0.0.0.0/0 --target-tags=shiny-server
gcloud compute --project=shinymenu-test-01 firewall-rules create shiny-egress --description="Open port 3838 for Shiny" --direction=EGRESS --priority=1000 --network=default --action=ALLOW --rules=tcp:3838 --source-ranges=0.0.0.0/0 --target-tags=shiny-server

gcloud compute --project=shinymenu-test-01 firewall-rules create http-ingress --description="Open port 80 for http" --direction=INGRESS --priority=1000 --network=default --action=ALLOW --rules=tcp:80 --source-ranges=0.0.0.0/0 --target-tags=shiny-server
gcloud compute --project=shinymenu-test-01 firewall-rules create https-ingress --description="Open port 443 for https" --direction=INGRESS --priority=1000 --network=default --action=ALLOW --rules=tcp:443 --source-ranges=0.0.0.0/0 --target-tags=shiny-server


#CREATE VM WITH THE SERVICE ACCOUNT SPECIFIED
gcloud compute instances create shiny-app-vm-test-vm \
--address=$STATIC_IP_ADDRESS \
--project=shinymenu-test-01 \
--zone=europe-west2-c \
--machine-type=e2-medium \
--service-account=vm1-sa-001@shinymenu-test-01.iam.gserviceaccount.com \
--scopes=https://www.googleapis.com/auth/cloud-platform \
--tags=http-server \
--tags=https-server \
--tags=shiny-server \
--image=projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20220419

#4. INSTALL NGINX, MYSQL, R, MARIADB LIBRARY, DOCKER#>

<#5. INSTALL R PACKAGES#>
#SHINY, RDBMARIA, ...

<#6. CLONE APPS FROM GITHUB#>
#REGISTRATION APP
#CUSTOMER APP
#VENUE APP

<#7. BUILD DOCKER CONTAINER AND PUSH TO REGISTRY#>

#8. TRIGGER CLOUD FUNCTION TO:
#8A. SET UP DNS
#8B. CREATE VM AND UPLOAD CONTAINER
#NB - DOES THIS NEED TO BE 
#7. SET UP NGINX CONFIGS TO REDIRECT HTTP TRAFFIC

#8. RUN CERTBOT TO SECURE WITH HTTPS


####################################################
#SCRATCHPAD
###################################################

#SSH INTO VM1
gcloud compute ssh shiny-app-vm-test-vm --zone=europe-west2-c

#! bin/bash

#SCRIPT TO SET UP THE CUSTOMER END APP (ORDERAPP) ON THE SECOND VM
#20210516

#1. INSTALL DOCKER
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update && sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update && sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo docker run hello-world

sudo usermod -a -G docker $vm1-sa-001@shinymenu-test-01.iam.gserviceaccount.com

#2. INSTALL MARIADB ON VM

sudo apt-get update && sudo apt-get install mariadb-server php php-mysql

#CHECK MARIADB SYSTEM STATUS
#sudo systemctl status mariadb

#CONFIGURE MARIADB - ADDS SOME SECURITY FEATURES
#sudo mysql_secure_installation

# Make sure that NOBODY can access the server without a password
sudo mysql -e "UPDATE mysql.user SET Password = PASSWORD('ciderBath271?') WHERE User = 'root'"
# Kill the anonymous users
sudo mysql -e "DROP USER ''@'localhost'"
# Because our hostname varies we'll use some Bash magic here.
sudo mysql -e "DROP USER ''@'$(hostname)'"
# Kill off the demo database
sudo mysql -e "DROP DATABASE test"
# Make our changes take effect
sudo mysql -e "FLUSH PRIVILEGES"
# Any subsequent tries to run queries this way will get access denied because lack of usr/pwd param

#3. INSTALL R

#LINK UBUNTU TO CRAN TO ENSURE LATEST VERSION
# update indices
sudo apt update -qq
# install two helper packages we need
sudo apt install --no-install-recommends software-properties-common dirmngr
# add the signing key (by Michael Rutter) for these repos
# To verify key, run gpg --show-keys /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc 
# Fingerprint: E298A3A825C0D65DFD57CBB651716619E084DAB9
sudo wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
# add the R 4.0 repo from CRAN -- adjust 'focal' to 'groovy' or 'bionic' as needed
sudo add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
sudo apt install --no-install-recommends r-base

sudo add-apt-repository ppa:c2d4u.team/c2d4u4.0+
sudo apt install --no-install-recommends r-cran-rstan
sudo apt install --no-install-recommends r-cran-tidyverse

#4. INSTALL R AND SHINY

sudo apt-get update && sudo apt-get install r-base-dev
sudo su - \
-c "R -e \"install.packages('shiny', repos='https://cran.rstudio.com/')\""
sudo apt-get install gdebi-core
wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.18.987-amd64.deb
sudo gdebi shiny-server-1.5.18.987-amd64.deb

#5. INSTALL REQUIRED PACKAGES
sudo apt-get update && sudo apt-get install libmariadb-dev
sudo R -e "install.packages(c('shiny', 'shinyWidgets' ,'DT', 'RMariaDB', 'DBI', 'shinyalert', 'qrcode', 'xtable'))"

#6. INSTALL NGINX ON VM
sudo apt install nginx -y

#7. INSTALL CERTBOT ON VM
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

#8. CREATE DOCKER DIRECTORY AND CD INTO IT
mkdir mydocker 
cd \mydocker

#5. BUILD BASE DOCKER IMAGE, INCLUDING DOCKER, R BASE, SHINY, REQUIRED R PACKAGES, MYSQL, LIBMARIADB, NGINX AND CERTBOT 

sudo docker container prune -a
sudo docker image prune -a --force
sudo docker build -t shinymenu_apps .
sudo docker tag shinymenu_apps gcr.io/shinymenu-test-01/shinymenu_apps
sudo docker push gcr.io/shinymenu-test-01/shinymenu_apps

#4. CREATE DOCKER DIRECTORY AND SHINYAPPS DIRECTOR AND CD INTO IT

mkdir myshinyapps 
cd \myshinyapps

#5. CLONE THE CUSTOMER APP (ORDERAPP) TO THE VM AND MOVE FILES TO THE RIGHT LOCATIONS#>
git clone https://github.com/matty8salisbury/OrderApp.git
mv OrderApp/Dockerfile Dockerfile
git clone https://github.com/matty8salisbury/PubEnd.git

#6. PULL VENUE_NAME.R FILE AND PRICE_LIST_NAME.CSV FILE IN FROM THE CLOUD STORAGE BUCKET

gsutil cp gs://mvs20220514-bucket-shinymenu-test-0001/info_matt1s_bar.sh ~/myshinyapps/info.sh
. info.sh

#6. CREATE USER IN MYSQL

sudo mysql -e "CREATE USER '${MY_UID}'@'localhost' IDENTIFIED BY '${MY_PWD}'; GRANT ALL PRIVILEGES ON *.* TO '${MY_UID}'@'localhost' WITH GRANT OPTION;FLUSH PRIVILEGES;"

gsutil cp gs://mvs20220514-bucket-shinymenu-test-0001/price_list_Bananaman1s_Bar.csv ~/myshinyapps/OrderApp/price_list.csv
gsutil cp gs://mvs20220514-bucket-shinymenu-test-0001/venueinfo_Bananaman1s_Bar.R ~/myshinyapps/OrderApp/venueinfo.R

unset MY_UID
unset MY_PWD
rm -R ~/myshinyapps/info.sh

#7. REPLACE THE INFORMATION IN VENUE R FILE WITH SPECIFIC VENUE INFO
cd OrderApp
sed -i "s/replaceThisUsername/${MY_UID}/g" venueinfo.R
sed -i "s/replaceThisPassword/${MY_PWD}/g" venueinfo.R
sed -i "s/Bananaman's Bar/${VENUE_DISPLAY}/g" venueinfo.R
sed -i "s/Bananaman1s_Bar_PE27_6TN/${VENUE}/g" venueinfo.R
sed -i "s/shinymenudb.cl5kbzs1nxfd.eu-west-2.rds.amazonaws.com/${SQL_ENDPOINT}/g" venueinfo.R
sed -i "s/mypassword/${VENUE_PASSWORD}/g" venueinfo.R

sudo cp ~/myshinyapps/OrderApp/price_list.csv ~/myshinyapps/PubEnd/price_list.csv
sudo cp ~/myshinyapps/OrderApp/venueinfo.R ~/myshinyapps/PubEnd/venueinfo.R

#8. COPY OVER APPS TO SHINY SERVER
cd /srv/shiny-server
sudo ln -s ~/myshinyapps/OrderApp .
sudo ln -s ~/myshinyapps/PubEnd .




#8. BUILD ORDERAPP DOCKER IMAGE, RUN AND EXIT VM1

sudo docker container prune -a
sudo docker image prune -a --force
sudo docker build -t shinymenu_apps .
sudo docker tag shinymenu_apps gcr.io/shinymenu-test-01/shinymenu_apps
sudo docker push gcr.io/shinymenu-test-01/shinymenu_apps
sudo docker run -d -p 3838:3838 shinymenu_apps


###############################################
#INSTALL R AND SHINY
###############################################

sudo R -e "Sys.setenv(SQL_ENDPOINT = 'localhost', SQL_PORT = 3306)"

MYSQL_USER='firstUser241'
MYSQL_USER_PASSWORD='radiatorBarking939!'
mysql -e "CREATE USER '${MY_UID}'@'localhost' IDENTIFIED BY '${MY_PWD}'; GRANT ALL PRIVILEGES ON *.* TO '${MY_UID}'@'localhost' WITH GRANT OPTION;FLUSH PRIVILEGES;"

Sys.setenv(SQL_ENDPOINT = 'localhost')
Sys.setenv(SQL_PORT = 3306)
Sys.setenv(MY_UID='firstUser241')
Sys.setenv(MY_PWD='radiatorBarking939!')

dbConnect(drv = RMariaDB::MariaDB(), username = 'firstUser241', password = 'radiatorBarking939!', host = 'localhost', port = 3306)
dbConnect(drv = RMariaDB::MariaDB(), username = options()$mysql$user, password = options()$mysql$password, host = options()$mysql$host, port = options()$mysql$port, dbname = db)


library('RMariaDB')
library('DBI')
source('venueinfo.R')
options(mysql = list(
    "host" = Sys.getenv("SQL_ENDPOINT"),
    "port" = Sys.getenv("SQL_PORT"),
    "user" = Sys.getenv("MY_UID"),
    "password" = Sys.getenv("MY_PWD")
))
conn <- function(db = db_to_use) {
      cn <- dbConnect(drv      = RMariaDB::MariaDB(),
                      username = options()$mysql$user,
                      password = options()$mysql$password,
                      host     = options()$mysql$host,
                      port     = options()$mysql$port,
                      dbname = db
                      )
      cn
    }
conn(db="")
db_to_use <- "DB001"
query1 <- sqlInterpolate(conn(db=""), "CREATE DATABASE ?db_to_create", db_to_create = SQL(db_to_use))
cr_db <- dbSendStatement(conn(db=""), query1)

0. CREATE NEW GITHUB APP FILES - ADD SOURCE COMMAND TO APP AND CHANGE SHINY ALERT COMMAND IN UI

1. CREATE A DOCKER IMAGE WITH SHINY SERVER AND MYSQL AND ALL LIBRARIES AND PACKAGES

2. COPY IN VENUE INFORMATION

3. CREATE USER FOR MYSQL

4. COPY OVER APP FILES TO /srv/shinyapps

5. BUILD THE CONTAINER AND RUN

docker run -d -p 80:3838 \
    -v /srv/shinyapps/:/srv/shiny-server/ \
    -v /srv/shinylog/:/var/log/shiny-server/ \
    rocker/shiny


#######################################################

