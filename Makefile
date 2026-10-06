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
else
	SHARED_LIB = libzvec_c_api.so
	BUILD_LIB_DIR = lib
endif

CMAKE_GENERATOR_FLAG := $(if $(wildcard $(ZVEC_BUILD)/CMakeCache.txt),,$(if $(shell command -v ninja 2>/dev/null),-G Ninja,))

CMAKE_FLAGS ?= $(CMAKE_GENERATOR_FLAG) \
	-DCMAKE_BUILD_TYPE=Release \
	-DBUILD_C_BINDINGS=ON \
	-DBUILD_PYTHON_BINDINGS=OFF \
	-DBUILD_TOOLS=OFF \
	-DCMAKE_POLICY_VERSION_MINIMUM=3.5

NPROC := $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

.PHONY: all build clean

all: build

$(ZVEC_SRC)/CMakeLists.txt:
	@if [ -e "$(ZVEC_SRC)" ]; then \
	  echo "[zvex] existing $(ZVEC_SRC) has no CMakeLists.txt; refusing to replace it" >&2; \
	  exit 1; \
	fi
	@if ! command -v git >/dev/null 2>&1; then \
	  echo "[zvex] git is required to fetch zvec sources but was not found in PATH" >&2; \
	  exit 1; \
	fi
	git clone --depth 1 --branch $(ZVEC_TAG) --recurse-submodules $(ZVEC_REPO) $(ZVEC_SRC)

build: $(ZVEC_SRC)/CMakeLists.txt
	cmake -S $(ZVEC_SRC) -B $(ZVEC_BUILD) $(CMAKE_FLAGS)
	cmake --build $(ZVEC_BUILD) --config Release --target zvec_c_api -j $(NPROC)
	@mkdir -p $(PRIV_DIR)/lib $(PRIV_DIR)/include/zvec
	cp $(ZVEC_BUILD)/$(BUILD_LIB_DIR)/$(SHARED_LIB) $(PRIV_DIR)/lib/
ifeq ($(UNAME_S),Darwin)
	install_name_tool -id @rpath/$(SHARED_LIB) $(PRIV_DIR)/lib/$(SHARED_LIB)
endif
	cp $(ZVEC_SRC)/src/include/zvec/c_api.h $(PRIV_DIR)/include/zvec/

clean:
	rm -rf $(ZVEC_BUILD)
	rm -f $(PRIV_DIR)/lib/$(SHARED_LIB)
	rm -rf $(PRIV_DIR)/include/zvec
