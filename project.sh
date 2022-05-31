#! /bin/bash

if ! (( "$OSTYPE" == "gnu-linux" )); then
  echo "docker-compose-wordpress-mevn-stack-dev runs only on GNU/Linux operating system. Exiting..."
  exit
fi

###############################################################################
# 1.) Assign variables and create directory structure
###############################################################################

  #PROJECT_NAME is parent directory
  PROJECT_NAME=`echo ${PWD##*/}`
  PROJECT_UID=`id -u`
  PROJECT_GID=`id -g`

  PROJECT_AUTHOR=`git config user.name`
  if [[ -z "${PROJECT_AUTHOR}" ]]; then 
    echo "ALERT: git config user.name is not set!"
    exit
  fi
    
  PROJECT_EMAIL=`git config user.email`
  if [[ -z "${PROJECT_EMAIL}" ]]; then 
    echo "ALERT: git config user.email is not set!"
    exit
  fi

############################ CLEAN SUBROUTINE #################################

clean() {
  docker-compose stop
  docker system prune -af --volumes
} 

############################ START SUBROUTINE #################################

start() {

  if [[ ! -d $PROJECT_NAME ]]; then
    # generate .git configuration with initial commit
      rm -rf .git/
      git init
      git add .
      git commit -m "feat: initial commit"
      mkdir -p tests/spec
  fi

###############################################################################
# 2.) Generate configuration files
###############################################################################

  if [[ ! -f docker-compose.yml ]]; then
    cat <<EOF> docker-compose.yml
    version: "3.8"

    services:
      mongodb:
        image: mongo:latest
#        ports:
#          - 27017:27017
        environment:
          - MONGO_INITDB_ROOT_USERNAME=$PROJECT_NAME
          - MONGO_INITDB_ROOT_PASSWORD=$PROJECT_NAME
        volumes:
          - mongodb-data
        network_mode: host

      mongo-express:
        image: mongo-express:latest
#        ports:
#          - 8081:8081
        environment:
          - ME_CONFIG_MONGODB_ADMINUSERNAME=$PROJECT_NAME
          - ME_CONFIG_MONGODB_ADMINPASSWORD=$PROJECT_NAME
          - ME_CONFIG_MONGODB_SERVER=mongodb
        network_mode: host

      node:
        image: node:16-alpine
        user: $PROJECT_UID:$PROJECT_GID
        working_dir: /home/node
        volumes:
          - .:/home/node
        environment:
          NODE_ENV: development
        network_mode: host

    volumes:
      mongodb-data:

EOF
  fi


  if [[ ! -f package.json ]]; then
    touch package.json && \
    cat <<EOF> package.json
{
    "name": "$PROJECT_NAME",
    "description": "docker-compose-mevn-stack-dev project",
    "version": "1.0.0",
    "license": "MIT",
    "author": "$PROJECT_AUTHOR <$PROJECT_EMAIL>",
    "private": true
}
EOF
  fi

###############################################################################
# 3.) Install dependencies
###############################################################################

#JavaScript
  
  if [[ ! -d ${PROJECT_NAME}_server ]]; then
    docker-compose run node sh -c "mkdir -p ${PROJECT_NAME}_server && \
      cd ${PROJECT_NAME}_server && \
      yarn init -yp && \
      yarn add mongodb express cors dotenv"
  fi

  if [[ ! -d $PROJECT_NAME ]]; then
    docker-compose run node yarn global add ynpx @vue/cli
    docker-compose run node node_modules/.bin/vue create $PROJECT_NAME
  fi

  docker-compose up -d
  sleep 5
  docker-compose -f docker-compose.yml up -d
  docker-compose run node sh -c "cd $PROJECT_NAME && yarn serve"

}

"$1"
