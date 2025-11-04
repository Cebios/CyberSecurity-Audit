FROM postman/newman:latest

# Installer le reporter HTML
RUN npm install -g newman-reporter-htmlextra

# Définir le répertoire de travail
WORKDIR /etc/newman

# Commande par défaut
ENTRYPOINT ["newman"]