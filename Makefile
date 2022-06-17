CFLAGS?=-O2 -pipe -std=c11 -g -fno-common -Wall -Wno-switch
PREFIX?=/usr/local

SRCS=$(wildcard *.c)
OBJS=$(SRCS:.c=.o)

TEST_SRCS=$(wildcard test/*.c)
TESTS=$(TEST_SRCS:.c=.exe)

# Stage 1

chibicc: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(OBJS): chibicc.h

test/%.exe: chibicc test/%.c
	./chibicc -Iinclude -Itest -c -o test/$*.o test/$*.c
	$(CC) -pthread -o $@ test/$*.o -xc test/common

test: $(TESTS)
	for i in $^; do echo $$i; ./$$i || exit 1; echo; done
	test/driver.sh ./chibicc

test-all: test test-stage2

# Stage 2

stage2/chibicc: $(OBJS:%=stage2/%)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

stage2/%.o: chibicc %.c
	mkdir -p stage2/test
	./chibicc -c -o $(@D)/$*.o $*.c

stage2/test/%.exe: stage2/chibicc test/%.c
	mkdir -p stage2/test
	./stage2/chibicc -Iinclude -Itest -c -o stage2/test/$*.o test/$*.c
	$(CC) -pthread -o $@ stage2/test/$*.o -xc test/common

test-stage2: $(TESTS:test/%=stage2/test/%)
	for i in $^; do echo $$i; ./$$i || exit 1; echo; done
	test/driver.sh ./stage2/chibicc

# Install

install: chibicc
	install -c -m 755 ./chibicc ${DESTDIR}${PREFIX}/bin
	install -d -m 755 ${DESTDIR}${PREFIX}/libexec/chibicc/include/machine
	install -d -m 755 ${DESTDIR}${PREFIX}/libexec/chibicc/include/amd64
	install -c -m 444 ./include/stdarg.h ${DESTDIR}${PREFIX}/libexec/chibicc/include
	install -c -m 444 ./include/stddef.h ${DESTDIR}${PREFIX}/libexec/chibicc/include
	sed 34,57d /usr/include/machine/endian.h > ${DESTDIR}${PREFIX}/libexec/chibicc/include/machine/endian.h
	chmod 444 ${DESTDIR}${PREFIX}/libexec/chibicc/include/machine/endian.h
	install -c -m 444 ${DESTDIR}${PREFIX}/libexec/chibicc/include/machine/endian.h ${DESTDIR}${PREFIX}/libexec/chibicc/include/amd64/endian.h

# Misc.

clean:
	rm -rf chibicc tmp* $(TESTS) test/*.s test/*.exe stage2
	find * -type f '(' -name '*~' -o -name '*.o' ')' -exec rm {} ';'

.PHONY: test clean test-stage2
