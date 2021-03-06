CXX ?= g++


# g++ 5 and clang++-3.7 have binary compatibility problems 
# & dynamic linking with boost libraries causes arbitrary segv's for g++
# So this is currently the GCD : statically link the boost stuff

OPTIMIZATION = 0
WARNINGS = \
	-Wall -Wextra -Wno-unknown-pragmas -Wctor-dtor-privacy -Wsign-promo \
	-Woverloaded-virtual -Wnon-virtual-dtor
FLAGS = -std=c++11 -ggdb3 -gdwarf-3 -O$(OPTIMIZATION) -fPIC 

CMD = $(CXX) $(WARNINGS) $(FLAGS) -I./include

LIBDIRS = -L/usr/lib/x86_64-linux-gnu -L/usr/local/lib -L/usr/lib

LIBS_lib = -lboost_system -lboost_thread -lboost_log -lpthread -lboost_program_options

LIBS_exec = -L/usr/local/lib \
	-Wl,-Bstatic -lboost_log -lboost_system -lboost_thread -lboost_program_options \
	-Wl,-Bdynamic -L./lib -lalba -lrdmacm -lpthread 


all: compile_lib compile_tests

	mkdir -p ./lib
	$(CXX) -shared -Wl,-soname,libalba.so.1 \
	    $(LIBDIRS) $(LIBS_lib) \
	    -o lib/libalba.so.1.0.1 src/lib/alba_logger.o \
	    src/lib/checksum.o src/lib/io.o src/lib/llio.o src/lib/proxy_client.o \
	    src/lib/proxy_protocol.o src/lib/stuff.o

	cd lib && ln -f -s libalba.so.1.0.1 libalba.so.1
	cd lib && ln -f -s libalba.so.1 libalba.so

	mkdir -p ./bin

	$(CXX) \
            src/tests/llio_test.o \
	    src/tests/proxy_client_test.o \
	    src/tests/main.o \
	    $(LIBDIRS) \
            $(LIBS_exec) -lgtest -lrdmacm \
	    -o bin/unit_tests.out

	$(CXX) \
	    src/examples/test_client.o \
	    $(LIBDIRS) $(LIBS_exec) -o bin/test_client.out

compile_lib:
	$(CMD) -c src/lib/stuff.cc -o src/lib/stuff.o
	$(CMD) -c src/lib/alba_logger.cc -o src/lib/alba_logger.o
	$(CMD) -c src/lib/proxy_protocol.cc -o src/lib/proxy_protocol.o
	$(CMD) -c src/lib/llio.cc -o src/lib/llio.o
	$(CMD) -c src/lib/checksum.cc -o src/lib/checksum.o
	$(CMD) -c src/lib/io.cc -o src/lib/io.o
	$(CMD) -c src/lib/proxy_client.cc -o src/lib/proxy_client.o

compile_tests:
	$(CMD) -I/usr/include/gtest \
	-c src/tests/llio_test.cc -o src/tests/llio_test.o

	$(CMD) -I/usr/include/gtest \
	-c src/tests/proxy_client_test.cc -o src/tests/proxy_client_test.o
	$(CMD) -I/usr/include/gtest \
	-c ./src/tests/main.cc -o src/tests/main.o

	$(CMD) -c src/examples/test_client.cc -o src/examples/test_client.o

clean:
	find -name "*.o" | xargs rm

format:
	find -name "*.cc" | xargs clang-format-3.6 -i
