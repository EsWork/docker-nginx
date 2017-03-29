all: build

build:
	@docker build --tag=eswork/nginx .

release: build
	@docker build --tag=eswork/nginx:$(shell cat VERSION) .
