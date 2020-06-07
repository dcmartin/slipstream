# A simple pythonn example using NVIDIA's Deepstream 5

# An example public RTSP stream you can use for development:
#  export RTSPINPUT=rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mov

NAME:="slipstream"
VERSION:="1.0.0"

# Get the Open-Horizon architecture type, and IP address for this host
ARCH:=$(shell ./helper -a)
IPADDR:=$(shell ./helper -i)


# Different base images for different hardware architectures:
BASE_IMAGE.aarch64:=nvcr.io/nvidia/deepstream-l4t:4.0.2-19.12-base
BASE_IMAGE.amd64:=nvcr.io/nvidia/deepstream:5.0-dp-20.04-triton

run: validate-rtspinput clean
	@echo "\n\n"
	@echo "***   Using RTSP input URI: $(RTSPINPUT)"
	@echo "***   Output stream URI is: rtsp://$(IPADDR):8554/ds"
	@echo "\n\n"
	docker run -d \
	  --name ${NAME} \
	  --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864 \
	  -e RTSPINPUT=${RTSPINPUT} \
	  -e ARCH=$(ARCH) \
	  -e IPADDR=$(IPADDR) \
	  -p 8554:8554 \
	  $(NAME)_$(ARCH):$(VERSION)

dev: validate-rtspinput clean
	docker run -it -v `pwd`:/outside \
	  --name ${NAME} \
	  --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864 \
	  -e RTSPINPUT=${RTSPINPUT} \
	  -e ARCH=$(ARCH) \
	  -e IPADDR=$(IPADDR) \
	  -p 8554:8554 \
	  $(NAME)_$(ARCH):$(VERSION) /bin/bash

build: 
	docker build --build-arg BASE_IMAGE=$(BASE_IMAGE.$(ARCH)) -t $(NAME)_$(ARCH):$(VERSION) .

push: 
	docker push $(DOCKERHUB_ID)/$(NAME)_$(ARCH):$(VERSION) 

clean: 
	@docker rm -f ${NAME} >/dev/null 2>&1 || :


#
# Sanity check targets
#


validate-rtspinput:
	@if [ -z "${RTSPINPUT}" ]; \
          then { echo "***** ERROR: \"RTSPINPUT\" is not set!"; exit 1; }; \
          else echo "  NOTE: Using RTSP input stream: \"${RTSPINPUT}\""; \
        fi
	@sleep 1


.PHONY: build run dev push clean validate-dockerhubid validate-rtspinput 
