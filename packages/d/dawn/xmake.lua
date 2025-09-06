package("dawn")
    set_homepage("https://dawn.googlesource.com/dawn")
    set_description("Dawn, a WebGPU implementation")
    set_license("BSD-3-Clause")

    add_urls("https://github.com/google/dawn/archive/refs/tags/$(version).tar.gz",
             "https://github.com/google/dawn.git", {submodules = false})

    add_versions("v20250905.222951", "1f56c56a92dacc47a7bd624c97eef63cf1b5dda62c386623d0ee25f134c29894")

    add_configs("vulkan", {description = "Enable Vulkan backend", default = is_plat("linux", "bsd", "android"), type = "boolean", readonly = true})
    add_configs("opengl", {description = "Enable OpenGL backend", default = is_plat("linux", "bsd"), type = "boolean", readonly = true})
    add_configs("opengles", {description = "Enable OpenGL ES backend", default = is_plat("linux", "bsd", "android"), type = "boolean", readonly = true})
    add_configs("d3d11", {description = "Enable Direct3D 11 backend", default = is_plat("windows"), type = "boolean", readonly = true})
    add_configs("d3d12", {description = "Enable Direct3D 12 backend", default = is_plat("windows"), type = "boolean", readonly = true})
    add_configs("metal", {description = "Enable Metal backend", default = is_plat("macos", "iphoneos"), type = "boolean", readonly = true})
    add_configs("webgpu", {description = "Enable WebGPU backend", default = is_plat("wasm"), type = "boolean", readonly = true})

    if is_host("windows") then
        set_policy("platform.longpaths", true)
    end

    add_deps("cmake", "python", {kind = "binary"})
    add_deps("abseil")

    on_load(function (package)
        if package:is_plat("linux", "bsd") then
            package:add("deps", "libx11", "libxcb")
        end

        if package:config("vulkan") then
            package:add("deps", "vulkan-headers")
        end
        if package:config("opengl") or package:config("opengles") then
            package:add("deps", "opengl", "opengl-headers")
        end
    end)

    on_install(function (package)
        -- os.vrun("python3 -m pip install jinja2")

        -- Fix for TARGET_PDB_FILE error
        io.replace("src/cmake/DawnLibrary.cmake", "if (MSVC)", "if (MSVC AND BUILD_SHARED_LIBS)", {plain = true})

        -- Patch
        local find_packages = "\nfind_package(absl CONFIG REQUIRED)"
        if package:config("vulkan") then
            find_packages = find_packages .. "\nfind_package(VulkanHeaders CONFIG REQUIRED)"
        end
        io.replace("CMakeLists.txt", "enable_testing()", "enable_testing()" .. find_packages, {plain = true})

        local configs = {
        "-DDAWN_ENABLE_INSTALL=ON",
        "-DDAWN_FETCH_DEPENDENCIES=ON",
        -- Backend options
        "-DDAWN_ENABLE_NULL=ON",
        -- Tools/tests build options
        "-DDAWN_ENABLE_SPIRV_VALIDATION=OFF",
        "-DDAWN_FORCE_SYSTEM_COMPONENT_LOAD=OFF",
        "-DDAWN_ALWAYS_ASSERT=OFF",
        "-DDAWN_USE_BUILT_DXC=OFF",
        "-DDAWN_DXC_ENABLE_ASSERTS_IN_NDEBUG=OFF",
        "-DDAWN_BUILD_SAMPLES=OFF",
        "-DDAWN_BUILD_TESTS=OFF",
        "-DDAWN_BUILD_NODE_BINDINGS=OFF",
        "-DDAWN_ENABLE_SWIFTSHADER=OFF",
        "-DDAWN_BUILD_BENCHMARKS=OFF",
        "-DDAWN_BUILD_PROTOBUF=OFF",
        "-DTINT_ENABLE_INSTALL=OFF",
        "-DTINT_BUILD_CMD_TOOLS=OFF",
        "-DTINT_BUILD_SPV_READER=OFF",
        "-DTINT_BUILD_WGSL_READER=OFF",
        "-DTINT_BUILD_GLSL_WRITER=OFF",
        "-DTINT_BUILD_GLSL_VALIDATOR=OFF",
        "-DTINT_BUILD_HLSL_WRITER=OFF",
        "-DTINT_BUILD_MSL_WRITER=OFF",
        "-DTINT_BUILD_SPV_WRITER=OFF",
        "-DTINT_BUILD_WGSL_WRITER=OFF",
        "-DTINT_BUILD_IR_BINARY=OFF",
        "-DTINT_BUILD_FUZZERS=OFF",
        "-DTINT_BUILD_BENCHMARKS=OFF",
        "-DTINT_BUILD_TESTS=OFF",
        "-DTINT_BUILD_AS_OTHER_OS=OFF",
        "-DTINT_BUILD_TINTD=OFF",
        "-DTINT_ENABLE_IR_VALIDATION=OFF"
        -- DAWN_BUILD_MONOLITHIC is required to generate install targets, but it is incompatible with BUILD_SHARED_LIBS
        "-DBUILD_SHARED_LIBS=OFF"
        }

        table.insert(configs, "-DCMAKE_BUILD_TYPE=" .. (package:is_debug() and "Debug" or "Release"))
        table.insert(configs, "-DDAWN_BUILD_MONOLITHIC_LIBRARY=" .. (package:config("shared") and "SHARED" or "STATIC"))

        -- Backends
        table.insert(configs, "-DDAWN_ENABLE_VULKAN=" .. (package:config("vulkan") and "ON" or "OFF"))
        table.insert(configs, "-DDAWN_ENABLE_DESKTOP_GL=" .. (package:config("opengl") and "ON" or "OFF"))
        table.insert(configs, "-DDAWN_ENABLE_OPENGLES=" .. (package:config("opengles") and "ON" or "OFF"))
        table.insert(configs, "-DDAWN_ENABLE_D3D11=" .. (package:config("d3d11") and "ON" or "OFF"))
        table.insert(configs, "-DDAWN_ENABLE_D3D12=" .. (package:config("d3d12") and "ON" or "OFF"))
        table.insert(configs, "-DDAWN_ENABLE_METAL=" .. (package:config("metal") and "ON" or "OFF"))
        table.insert(configs, "-DDAWN_ENABLE_WEBGPU_ON_WEBGPU=" .. (package:config("webgpu") and "ON" or "OFF"))

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
