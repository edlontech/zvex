ZVEC_SRC = c_src/zvec
ZVEC_BUILD = _build/zvec
PRIV_DIR = $(MIX_APP_PATH)/priv

ZVEX_VERSION ?= 0.4.0
ZVEC_REPO ?= https://github.com/alibaba/zvec.git
ZVEC_TAG ?= v$(ZVEX_VERSION)

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	SHARED_LIB = libzvec_c_api.dylib
	BUILD_LIB_DIR = lib
else ifneq (,$(filter MINGW% MSYS% CYGWIN%,$(UNAME_S)))
	SHARED_LIB = zvec_c_api.dll
	BUILD_LIB_DIR = bin
else
	SHARED_LIB = libzvec_c_api.so
	BUILD_LIB_DIR = lib
endif

CMAKE_FLAGS ?= -DCMAKE_BUILD_TYPE=Release \
	-DBUILD_C_BINDINGS=ON \
	-DBUILD_PYTHON_BINDINGS=OFF \
	-DBUILD_TOOLS=OFF \
	-DCMAKE_POLICY_VERSION_MINIMUM=3.5

NPROC := $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

.PHONY: all build clean force

all:
	@if [ -f "$(PRIV_DIR)/lib/$(SHARED_LIB)" ] && [ -f "$(PRIV_DIR)/include/zvec/c_api.h" ]; then \
	  echo "[zvex] using existing $(SHARED_LIB) in $(PRIV_DIR)/lib (run 'mix clean' to force rebuild)"; \
	else \
	  $(MAKE) build; \
	fi

build: $(PRIV_DIR)/lib/$(SHARED_LIB) $(PRIV_DIR)/include/zvec/c_api.h

$(ZVEC_SRC)/CMakeLists.txt:
	@if [ ! -f "$@" ]; then \
	  if ! command -v git >/dev/null 2>&1; then \
	    echo "[zvex] git is required to fetch zvec sources but was not found in PATH" >&2; \
	    exit 1; \
	  fi; \
	  echo "[zvex] fetching zvec $(ZVEC_TAG) from $(ZVEC_REPO)"; \
	  rm -rf $(ZVEC_SRC); \
	  git clone --depth 1 --branch $(ZVEC_TAG) --recurse-submodules $(ZVEC_REPO) $(ZVEC_SRC); \
	fi

$(ZVEC_BUILD)/CMakeCache.txt: $(ZVEC_SRC)/CMakeLists.txt
	cmake -S $(ZVEC_SRC) -B $(ZVEC_BUILD) $(CMAKE_FLAGS)

$(ZVEC_BUILD)/$(BUILD_LIB_DIR)/$(SHARED_LIB): $(ZVEC_BUILD)/CMakeCache.txt force
	cmake --build $(ZVEC_BUILD) --config Release --target zvec_c_api -j $(NPROC)

$(PRIV_DIR)/lib/$(SHARED_LIB): $(ZVEC_BUILD)/$(BUILD_LIB_DIR)/$(SHARED_LIB)
	@mkdir -p $(PRIV_DIR)/lib
	cp $(ZVEC_BUILD)/$(BUILD_LIB_DIR)/$(SHARED_LIB) $(PRIV_DIR)/lib/
ifeq ($(UNAME_S),Darwin)
	install_name_tool -id @rpath/$(SHARED_LIB) $(PRIV_DIR)/lib/$(SHARED_LIB)
endif

$(PRIV_DIR)/include/zvec/c_api.h: $(ZVEC_SRC)/CMakeLists.txt
	@mkdir -p $(PRIV_DIR)/include/zvec
	cp $(ZVEC_SRC)/src/include/zvec/c_api.h $(PRIV_DIR)/include/zvec/

clean:
	rm -rf $(ZVEC_BUILD)
	rm -f $(PRIV_DIR)/lib/$(SHARED_LIB)
	rm -rf $(PRIV_DIR)/include/zvec
