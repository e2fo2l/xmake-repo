package("dawn")
    set_homepage("https://dawn.googlesource.com/dawn")
    set_description("Dawn, a WebGPU implementation")
    set_license("BSD-3-Clause")

    add_urls("https://github.com/google/dawn/archive/refs/tags/$(version).tar.gz",
             "https://github.com/google/dawn.git", {submodules = false})

    add_versions("v20250822.104650", "d907df9c5b14f0ee982fe3016aeddeab78e62e7c123ced64bd470e7cfa663433")

    if is_host("windows") then
        set_policy("platform.longpaths", true)
    end

    add_deps("cmake", "python", {kind = "binary"})
    add_deps("abseil", "spirv-headers", "vulkan-headers", "vulkan-utility-libraries")

    on_load(function (package)
        if package:is_plat("linux", "bsd") then
            package:add("deps", "libx11", "libxcb")
        end
    end)

    on_install("windows", "linux", "macosx", "bsd", "mingw", "msys", "cross", function (package)
        os.vrun("python3 -m pip install jinja2")

        -- Fix for TARGET_PDB_FILE error
        io.replace("src/cmake/DawnLibrary.cmake", "if (MSVC)", "if (MSVC AND BUILD_SHARED_LIBS)", {plain = true})

        -- Patch
        io.replace("third_party/CMakeLists.txt", "SPIRV-Headers", "SPIRV-Headers::SPIRV-Headers", {plain = true})
        io.replace("CMakeLists.txt", "enable_testing()", [[
        enable_testing()
        find_package(absl CONFIG REQUIRED)
        find_package(SPIRV-Headers CONFIG REQUIRED)
        find_package(VulkanHeaders CONFIG REQUIRED)
        find_package(VulkanUtilityLibraries CONFIG REQUIRED)
        ]], {plain = true})

        local configs = {
        "-DDAWN_ENABLE_INSTALL=ON",
        -- Backend options
        "-DDAWN_ENABLE_NULL=ON",
        "-DDAWN_ENABLE_VULKAN=ON",
        "-DDAWN_ENABLE_DESKTOP_GL=OFF", -- TODO: Fix OpenGL backend (currently requires the script to download third parties)
        "-DDAWN_ENABLE_OPENGLES=OFF",
        "-DDAWN_ENABLE_D3D11=OFF",
        "-DDAWN_ENABLE_D3D12=OFF",
        "-DDAWN_ENABLE_METAL=OFF",
        "-DDAWN_ENABLE_WEBGPU_ON_WEBGPU=OFF",
        -- Tools/tests build options
        "-DDAWN_FETCH_DEPENDENCIES=OFF",
        "-DDAWN_USE_GLFW=OFF",
        "-DDAWN_USE_BUILD_DXC=OFF",
        "-DDAWN_BUILD_SAMPLES=OFF",
        "-DDAWN_BUILD_TESTS=OFF",
        "-DDAWN_BUILD_BENCHMARKS=OFF",
        "-DDAWN_BUILD_PROTOBUF=OFF",
        "-DDAWN_ENABLE_SPIRV_VALIDATION=OFF",
        "-DTINT_ENABLE_INSTALL=OFF",
        "-DTINT_BUILD_TESTS=OFF",
        "-DTINT_BUILD_BENCHMARKS=OFF",
        "-DTINT_BUILD_CMD_TOOLS=OFF",
        "-DTINT_BUILD_TINTD=OFF",
        "-DTINT_BUILD_PROTOBUF=OFF",
        "-DTINT_BUILD_SPV_READER=OFF",
        "-DTINT_BUILD_SPV_WRITER=OFF",
        "-DTINT_BUILD_GLSL_WRITER=OFF",
        "-DTINT_BUILD_GLSL_VALIDATOR=OFF",
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
