NAME := inception
ENV_FILE := srcs/.env
LOGIN ?= $(shell sed -n 's/^LOGIN=//p' $(ENV_FILE))
DATA := /home/$(LOGIN)/data
COMPOSE := docker compose --project-name $(NAME) --env-file $(ENV_FILE) -f srcs/docker-compose.yml


all:
	mkdir -p $(DATA)/wordpress $(DATA)/mariadb
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down --rmi all

fclean:
	$(COMPOSE) down --rmi all --volumes
	sudo rm -rf $(DATA)

re: fclean all

.PHONY: all down clean fclean re