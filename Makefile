all: build

build:
	@docker build --tag=eswork/nginx .
lt:
	@docker build --tag=eswork/nginx:lt -f Dockerfile.lt .

release: build
	@docker build --tag=eswork/nginx:$(shell cat VERSION) .
release-lt: build
	@docker build --tag=eswork/nginx:$(shell cat VERSION)-lt -f Dockerfile.lt .
