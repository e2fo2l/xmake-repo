package("dawn")
  set_homepage("https://dawn.googlesource.com/dawn")
  set_description("Dawn, a WebGPU implementation")
  set_license("BSD-3-Clause")

  add_urls("https://github.com/google/dawn/archive/refs/tags/$(version).tar.gz",
           "https://github.com/google/dawn.git")

  add_versions("v20250822.104650", "d907df9c5b14f0ee982fe3016aeddeab78e62e7c123ced64bd470e7cfa663433")

  add_deps("cmake", "python", {kind = "binary"})

  on_load(function (package)
    if package:is_plat("linux", "bsd") then
      package:add("deps", "libx11")
    end
  end)

  on_install(function (package)
    local configs = {
      "-DDAWN_ENABLE_INSTALL=ON",
      "-DDAWN_FETCH_DEPENDENCIES=ON",
      "-DDAWN_BUILD_SAMPLES=OFF",
      "-DDAWN_BUILD_TESTS=OFF",
      "-DTINT_BUILD_TESTS=OFF",
      "-DTINT_BUILD_CMD_TOOLS=OFF",
      -- DAWN_BUILD_MONOLITHIC is required to generate install targets, but it is incompatible with BUILD_SHARED_LIBS
      "-DBUILD_SHARED_LIBS=OFF"
    }

    table.insert(configs, "-DCMAKE_BUILD_TYPE=" .. (package:is_debug() and "Debug" or "Release"))
    table.insert(configs, "-DDAWN_BUILD_MONOLITHIC_LIBRARY=" .. (package:config("shared") and "SHARED" or "STATIC"))
    import("package.tools.cmake").install(package, configs)
  end)

  on_test(function (package)
    assert(package:check_cxxsnippets({test = [[
      void test() {
        wgpu::InstanceDescriptor instanceDescriptor{};
        auto instance = wgpu::CreateInstance(&instanceDescriptor);
        (void)instance;
      }
    ]]}, {configs = {languages = "c++20"}, includes = "webgpu/webgpu_cpp.h"}))
  end)
