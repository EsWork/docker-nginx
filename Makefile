all: build

build:
	@docker build --tag=johnwu/nginx .

release: build
	@docker build --tag=johnwu/nginx:$(shell cat VERSION) .
