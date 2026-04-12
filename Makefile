ZVEC_SRC = c_src/zvec
ZVEC_BUILD = _build/zvec
PRIV_DIR = $(MIX_APP_PATH)/priv

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	SHARED_LIB = libzvec_c_api.dylib
else
	SHARED_LIB = libzvec_c_api.so
endif

CMAKE_FLAGS ?= -DCMAKE_BUILD_TYPE=Release \
	-DBUILD_C_BINDINGS=ON \
	-DBUILD_PYTHON_BINDINGS=OFF \
	-DBUILD_TOOLS=OFF \
	-DCMAKE_POLICY_VERSION_MINIMUM=3.5

NPROC := $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

.PHONY: all clean force

all: $(PRIV_DIR)/lib/$(SHARED_LIB) $(PRIV_DIR)/include/zvec/c_api.h

$(ZVEC_BUILD)/Makefile: $(ZVEC_SRC)/CMakeLists.txt
	cmake -S $(ZVEC_SRC) -B $(ZVEC_BUILD) $(CMAKE_FLAGS)

$(ZVEC_BUILD)/lib/$(SHARED_LIB): $(ZVEC_BUILD)/Makefile force
	cmake --build $(ZVEC_BUILD) --config Release --target zvec_c_api -j $(NPROC)

$(PRIV_DIR)/lib/$(SHARED_LIB): $(ZVEC_BUILD)/lib/$(SHARED_LIB)
	@mkdir -p $(PRIV_DIR)/lib
	cp $(ZVEC_BUILD)/lib/$(SHARED_LIB) $(PRIV_DIR)/lib/
ifeq ($(UNAME_S),Darwin)
	install_name_tool -id @rpath/$(SHARED_LIB) $(PRIV_DIR)/lib/$(SHARED_LIB)
endif

$(PRIV_DIR)/include/zvec/c_api.h: $(ZVEC_SRC)/src/include/zvec/c_api.h
	@mkdir -p $(PRIV_DIR)/include/zvec
	cp $(ZVEC_SRC)/src/include/zvec/c_api.h $(PRIV_DIR)/include/zvec/

clean:
	rm -rf $(ZVEC_BUILD)
	rm -f $(PRIV_DIR)/lib/$(SHARED_LIB)
	rm -rf $(PRIV_DIR)/include/zvec
