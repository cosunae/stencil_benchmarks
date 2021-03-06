-include Makefile.user

CXXFLAGS=-std=c++11 -O3 -MMD -MP -Wall -fopenmp -DNDEBUG -Isrc $(USERFLAGS)
NVCCFLAGS=-std=c++11 -arch=sm_60 -O3 -g -Xcompiler -fopenmp -DNDEBUG -Isrc $(USERFLAGS_CUDA)
LIBS=$(USERLIBS)

CXXFLAGS_KNL=-DPLATFORM_KNL
LIBS_KNL=
CXXFLAGS_CUDA=-DPLATFORM_CUDA
LIBS_CUDA=
CXXFLAGS_KNLCPU=-DPLATFORM_KNL -DKNL_NO_HBWMALLOC -march=native -mtune=native
LIBS_KNLCPU=

CXXVERSION=$(shell $(CXX) --version)
ifneq (,$(findstring icpc,$(CXXVERSION)))
	CXXFLAGS_KNL+=-xmic-avx512 -ffreestanding
	CXXFLAGS_KNLCPU+=-ffreestanding
else ifneq (,$(findstring g++,$(CXXVERSION)))
	LIBS+=-lgomp
	CXXFLAGS+=-Wno-unknown-pragmas -Wno-unused-variable
	CXXFLAGS_KNL+=-march=knl -mtune=knl -fvect-cost-model=unlimited
	CXXFLAGS_KNLCPU+=-fvect-cost-model=unlimited
	LIBS_KNL+=-lmemkind
endif


SRCS=$(wildcard src/*.cpp)
OBJS=$(SRCS:src/%.cpp=%.o)
DEPS=$(SRCS:src/%.cpp=%.d)

SRCS_KNL=$(wildcard src/knl/*.cpp)
OBJS_KNL=$(SRCS_KNL:src/knl/%.cpp=%.o)
DEPS_KNL=$(SRCS_KNL:src/knl/%.cpp=%.d)

SRCS_CUDA=$(wildcard src/cuda/*.cu)
OBJS_CUDA=$(SRCS_CUDA:src/cuda/%.cu=%.o)

%.o: src/%.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

%.o: src/knl/%.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

%.o: src/cuda/%.cu
	$(CXX) $(CXXFLAGS) -c $< -o $@

.PHONY: default
default:
	$(error Please specify the target platform, i.e. use 'make knl' for Intel KNL, \
		'make cuda' for NVIDIA CUDA GPUs or 'make knl-cpu' to compile the KNL implementation for common CPUs)

.PHONY: knl
knl: sbench_knl

.PHONY: cuda
cuda: sbench_cuda

.PHONY: knl-cpu
knl-cpu: sbench_knlcpu

sbench_knl: CXXFLAGS+=$(CXXFLAGS_KNL)
sbench_knl: $(OBJS) $(OBJS_KNL)
	$(CXX) $(CXXFLAGS) $+ $(LIBS) $(LIBS_KNL) -o $@

sbench_cuda: CXX=nvcc
sbench_cuda: CXXFLAGS=$(NVCCFLAGS) $(CXXFLAGS_CUDA)
sbench_cuda: $(OBJS) $(OBJS_CUDA)
	$(CXX) $(CXXFLAGS) $+ $(LIBS) $(LIBC_CUDA) -o $@

sbench_knlcpu: CXXFLAGS+=$(CXXFLAGS_KNLCPU)
sbench_knlcpu: $(OBJS) $(OBJS_KNL)
	$(CXX) $(CXXFLAGS) $+ $(LIBS) $(LIBS_KNLCPU) -o $@

-include $(DEPS) $(DEPS_KNL)

.PHONY: clean
clean:
	rm -f $(OBJS) $(DEPS) $(OBJS_KNL) $(DEPS_KNL) $(OBJS_CUDA) sbench_*

.PHONY: format
format:
	clang-format -i src/*.cpp src/*.h src/*/*.cpp src/*/*.h src/*/*.cu
