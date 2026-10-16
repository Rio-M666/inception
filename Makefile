NAME := inception
ENV_FILE := srcs/.env
LOGIN ?= $(shell sed -n 's/^LOGIN=//p' $(ENV_FILE))
DATA := /home/$(LOGIN)/data
DOCKER_DATA := $(DATA)/docker
COMPOSE := docker compose --project-name $(NAME) --env-file $(ENV_FILE) -f srcs/docker-compose.yml


all: check-storage
	$(COMPOSE) up -d --build


down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down --rmi all

fclean:
	$(COMPOSE) down --rmi all --volumes

re: fclean
	$(MAKE) all

.PHONY: all check-storage down clean fclean re
