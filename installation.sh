
#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'


echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}     Instalação Odoo On-Premise     ${NC}"
echo -e "${BLUE}====================================${NC}"

echo -e ""
echo -e "Selecione a versão desejada"
echo -e "Apenas versões .0 são aceitas 20.0, 19.0, 18.0"
read -rp "Qual é a versão desejada? " ODOO_VERSION
echo -e ""

if [[ ! "$ODOO_VERSION" =~ ^[0-9]+\.0$ ]]; then
    echo -e "${RED}Erro: Versão inválida. Use o formato XX.0${NC}"
    exit 1
fi

DEFAULT_DIR="odoo $ODOO_VERSION"

echo ""
echo -e "${YELLOW}Para instalar Odoo On-Premise precisamos criar a seguinte estrutura de pastas:${NC}"
echo "
$DEFAULT_DIR/
├── addons/
│   ├── enterprise/
│   └── user/
├── config/
│   └── odoo.conf
└── docker-compose.yml
"

CREATE_FOLDERS=false
while true; do
				read -rp "Podemos começar? (clique 'n' para pular essa etapa) [y/n]: " CONFIRM

				case "$CONFIRM" in
								[yY]|[yY][eE][sS])
												CREATE_FOLDERS=true
												break
												;;
								[nN]|[nN][oO])
												echo -e "${RED}Etapa pulada, espero que já tenha a estrutura de pastas correta.${NC}"
												break
												;;
								*)
												echo -e "${YELLOW}Input inválido, selecione [y/n]${NC}"
												;;
				esac
done

if [[ "$CREATE_FOLDERS" == true ]]; then

				echo ""
				echo -e "${BLUE}[1/4] Criando pastas...${NC}"

				mkdir -p "$DEFAULT_DIR/addons/enterprise"
				mkdir -p "$DEFAULT_DIR/addons/user"
				mkdir -p "$DEFAULT_DIR/config"

				echo -e "${GREEN}✔  Pastas criadas com sucesso.${NC}"

				echo -e "${BLUE}[2/4] Criando arquivo de configuração...${NC}"

				cat > "$DEFAULT_DIR/config/odoo.conf" <<'EOF'
[options]
admin_passwd = mysupersecretpassword
db_host = odoo_db
db_port = 5432
db_user = odoo
db_password = odoo
addons_path = /mnt/extra-addons/enterprise/,/mnt/extra-addons/user/
limit_time_real = 5000
log_level = info
list_db = True
http_interface = 0.0.0.0
http_port = 8069
EOF

				echo -e "${GREEN}✔  odoo.conf criado com sucesso.${NC}"

				echo -e "${BLUE}[3/4] Criando arquivos Docker...${NC}"

				cat > "$DEFAULT_DIR/docker-compose.yml" <<EOF
services:
  web:
    image: odoo:$ODOO_VERSION
    depends_on:
      - odoo_db
    ports:
      - "8069:8069"
    restart: unless-stopped
    volumes:
      - odoo-web-data$ODOO_VERSION:/var/lib/odoo 
      - ./config:/etc/odoo          
      - ./addons:/mnt/extra-addons  
  odoo_db:
    image: postgres:18
    ports:
      - "5432:5432"
    restart: unless-stopped
    environment:
      - POSTGRES_DB=postgres
      - POSTGRES_PASSWORD=odoo
      - POSTGRES_USER=odoo
      - PGDATA=/var/lib/postgresql/18/docker
    volumes:
      - odoo-db-data$ODOO_VERSION:/var/lib/postgresql/18/docker
volumes:
  odoo-web-data$ODOO_VERSION:
  odoo-db-data$ODOO_VERSION:
EOF

				echo -e "${GREEN}✔  docker-compose.yml criado com sucesso.${NC}"

				echo -e "${BLUE}[4/4] Validando arquivos...${NC}"

				if [[ -f "$DEFAULT_DIR/config/odoo.conf" && \
								-f "$DEFAULT_DIR/docker-compose.yml" && \
								-d "$DEFAULT_DIR/addons/enterprise" && \
								-d "$DEFAULT_DIR/addons/user" ]]; then

				echo -e "${GREEN}✔  Estrutura criada, agora vamos fazer o download do Odoo Enterpise.${NC}"
				else
								echo -e "${RED}✘ Algo de errado não está certo, verifique e tente novamente${NC}"
								exit 1
				fi
				
				echo ""
				echo -e "${GREEN}====================================${NC}"
				echo -e "${GREEN}       Setup inicial completo!      ${NC}"
				echo -e "${GREEN}====================================${NC}"
fi

echo ""
echo -e "${BLUE}Iniciando download Odoo Enterprise${NC}"
echo ""
read -rsp "Adicione o seu token do Github: " GITHUB_TOKEN
echo ""

if [[ -z "$GITHUB_TOKEN" ]]; then
				echo -e "${RED}Erro: Preciso do token para continuar${NC}"
				exit 1
fi

ENTERPRISE_DIR="$DEFAULT_DIR/addons/enterprise"

if [[ -n "$(ls -A "$ENTERPRISE_DIR")" ]]; then
				echo -e "${RED}Erro: Pasta para código Odoo enterprise não criada${NC}"
				echo "Faça o processo de instalação novamente"
				unset GITHUB_TOKEN
				exit 1
fi

AUTH_HEADER=$(printf "x-access-token:%s" "$GITHUB_TOKEN" | base64 | tr -d '\n')

git -c credential.helper= \
    -c http.extraHeader="AUTHORIZATION: basic $AUTH_HEADER" \
    clone --branch "$ODOO_VERSION" --single-branch --depth 1 --progress \
    "https://github.com/odoo/enterprise.git" \
    "$ENTERPRISE_DIR"

echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}     ✔  Configuração completa!      ${NC}"
echo -e "${GREEN}====================================${NC}"


echo ""
echo -e "Projeto pode ser encontrado em: ${BLUE}$(realpath "$DEFAULT_DIR")${NC}"
echo ""
echo "Para iniciar o Odoo On-Premise rode os seguintes comandos:"
echo -e "${YELLOW}cd "$DEFAULT_DIR"${NC}"
echo -e "${YELLOW}sudo docker compose up${NC}"
