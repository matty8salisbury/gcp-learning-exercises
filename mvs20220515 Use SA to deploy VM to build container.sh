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

#Assign appropriate roles to the service account#
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

#CREATE VM WITH THE SERVICE ACCOUNT SPECIFIED
gcloud compute instances create shiny-app-vm-test-vm \
  --address=$STATIC_IP_ADDRESS \
  --project=shinymenu-test-01 \
  --zone=europe-west2-c \
  --machine-type=e2-medium \
  --service-account=vm1-sa-001@shinymenu-test-01.iam.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --tags=http-server --tags=https-server --tags=shiny-server \
  --image=projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20220419 \
  --metadata startup-script='
  #! bin/bash

  #SCRIPT TO SET UP THE CUSTOMER END APP (ORDERAPP) ON THE SECOND VM
  #20210516

  #1. INSTALL DOCKER
  sudo apt-get remove docker docker-engine docker.io containerd runc
  sudo apt-get update 
  sudo apt-get install -y \
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

  #2. INSTALL NGINX ON VM
  sudo apt install nginx -y

  #3. INSTALL CERTBOT ON VM
  sudo snap install --classic certbot
  sudo ln -s /snap/bin/certbot /usr/bin/certbot

  #4. #INSTALL MARIADB ON VM

  sudo apt-get update && sudo apt-get install mariadb-server php php-mysql

  #CHECK MARIADB SYSTEM STATUS
  sudo systemctl status mariadb

  #CONFIGURE MARIADB - ADDS SOME SECURITY FEATURES
  sudo mysql_secure_installation

  #5. INSTALL CLOUD SDK UBUNTU
  sudo apt update && sudo apt-get install apt-transport-https ca-certificates gnupg

  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
  sudo apt-get update && sudo apt-get install google-cloud-cli

  gcloud init --console-only --skip-diagnostics --account=vm1-sa-001@shinymenu-test-01.iam.gserviceaccount.com --project=shinymenu-test-01

  #6. CREATE DOCKER DIRECTORY AND CD INTO IT
  mkdir mydocker 
  cd \mydocker

  #7. CLONE THE CUSTOMER APP (ORDERAPP) TO THE VM AND MOVE FILES TO THE RIGHT LOCATIONS#>
  git clone https://github.com/matty8salisbury/OrderApp.git
  mv OrderApp/Dockerfile Dockerfile
  git clone https://github.com/matty8salisbury/PubEnd.git

  #PULL VENUE_NAME.R FILE AND PRICE_LIST_NAME.CSV FILE IN FROM THE CLOUD STORAGE BUCKET

  gsutil cp gs://mvs20220514-bucket-shinymenu-test-0001/price_list_Bananaman1s_Bar.csv ~/mydocker/OrderApp/price_list.csv
  gsutil cp gs://mvs20220514-bucket-shinymenu-test-0001/venueinfo_Bananaman1s_Bar.R ~/mydocker/OrderApp/venueinfo.R
  sudo cp ~/mydocker/OrderApp/price_list.csv ~/mydocker/PubEnd/price_list.csv
  sudo cp ~/mydocker/OrderApp/venueinfo.R ~/mydocker/PubEnd/venueinfo.R

  #8. BUILD ORDERAPP DOCKER IMAGE, RUN AND EXIT VM1

  sudo docker container prune -a
  sudo docker image prune -a --force
  sudo docker build -t shinymenu_apps .
  sudo docker tag shinymenu_apps gcr.io/shinymenu-test-01/shinymenu_apps
  sudo docker push gcr.io/shinymenu-test-01/shinymenu_apps
  sudo docker run -d -p 3838:3838 shinymenu_apps
    
  EOF'


#8. RUN CERTBOT TO SECURE WITH HTTPS


####################################################
#SCRATCHPAD
###################################################

#SSH INTO VM1
#gcloud compute ssh shiny-app-vm-test-vm --zone=europe-west2-c











