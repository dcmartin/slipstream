###
## Makefile
###

## architecture
BUILD_ARCH ?= $(if $(wildcard BUILD_ARCH),$(shell cat BUILD_ARCH),$(shell uname -m | sed -e 's/aarch64.*/arm64/' -e 's/x86_64.*/amd64/' -e 's/armv.*/arm/'))

## ip address of host
IPADDR := $(shell ifconfig | egrep 'inet ' | awk '{ print $$2 }' | egrep -v '^172.|^10.|^127.|^169.' | head -1)

## nvidia runtime
NVIDIA_RUNTIME := $(shell docker info --format '{{ json . }}' | jq '.DefaultRuntime=="nvidia"')

## CUDA version
CUDA := $(shell /usr/local/cuda/bin/nvcc --version | egrep '^Cuda' | awk -F, '{ print $$2 $$3 }')
CUDA := $(if ${CUDA},$(shell echo "${CUDA}" | awk '{ print $$2 }'),)
BASE := $(if ${CUDA},$(shell jq -r '.[]|to_entries[]|select(.key=="'${BUILD_ARCH}-${CUDA}'").value' build.json 2> /dev/null),)

## test if ready-to-go
ifeq ($(BASE),)
default: nobase
else
ifeq ($(NVIDIA_RUNTIME), true)
default: run
else
default: fixruntime
endif
endif

nobase:
	@echo "No BASE image identified; is CUDA installed?  CUDA: ${CUDA}" > /dev/stderr
	exit 1

fixruntime:
	@echo "Docker default-runtime NOT nvidia; edit /etc/docker/daemon.json" > /dev/stderr
	exit 1

###
### MAIN
###

NAME := slipstream
VERSION := 1.0.0
RTSPINPUT := $(if ${RTSPINPUT},${RTSPINPUT},rtsp://192.168.1.163/img/video.sav)

build:
	@echo "Building for CUDA: ${CUDA}; BASE: ${BASE}"
	docker build --build-arg BASE=${BASE} -t ${NAME}:${VERSION} .

push: 
	docker login -a 
	docker push $(NAME):$(VERSION) 


run: build
	docker run -d \
	  --name ${NAME} \
	  --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864 \
	  -e RTSPINPUT=${RTSPINPUT} \
	  -e ARCH=$(BUILD_ARCH) \
	  -e IPADDR=$(IPADDR) \
	  -p 8554:8554 \
	  $(NAME):$(VERSION)

test: build
	docker run -it -v `pwd`:/outside \
	  --name ${NAME} \
	  --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864 \
	  -e RTSPINPUT=${RTSPINPUT} \
	  -e ARCH=$(BUILD_ARCH) \
	  -e IPADDR=$(IPADDR) \
	  -p 8554:8554 \
	  $(NAME):$(VERSION) /bin/bash

clean: 
	@docker rm -f ${NAME} >/dev/null 2>&1 || :

.PHONY: build run test push clean
