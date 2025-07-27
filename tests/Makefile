TARGET_ARCH := $(if $(filter x86_64-%,$(shell $(CC) -dumpmachine)),x86-64,i486)

.PHONY: all

all: curl-test-runner.exe

%.exe: %.c
	$(CC) -municode -Wall -Wextra -Werror -march=$(TARGET_ARCH) -Os -static -Wl,-s -o $@ $<
