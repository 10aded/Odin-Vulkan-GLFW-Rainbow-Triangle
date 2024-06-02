// A "minimal" example of a Vulkan app in Odin which renders a rainbow triangle.
//
// Created by 10aded March 2024 - June 2024.
//
// The code in this file can be compiled and ran from a terminal
// with the SINGLE command:
//
//     odin run rainbow-triangle.odin -file -o:speed
//
// where odin is the Odin compiler, available at
//
//      https://odin-lang.org/
//
// The most recent version of the compiler that the project was tested with
// is: dev-2024-06:c07a46a
// 
// When compiled as above, the project does not require any external dependancies
// (Vulkan drivers aside). Odin's vendor:glfw and vendor:vulkan libraries ---
// included with the compiler by default --- are enough.
//
// The entire setup process / logic has been annotated with print statements, 
// which are activated when compiled (and ran) in -debug mode.
// (For example, printing out the the available extensions of the selected
// physical device (graphics card).)
//
// The code can be compiled and ran in debug mode with
//
//    odin run rainbow-triangle.odin -file -debug
//
// Debug mode does, however, require the "VK_LAYER_KHRONOS_validation" layer,
// which is included with the default Vulkan SDK available at:
//
// https://vulkan.lunarg.com/
//
// (Of course, should you wish to compile the program in -debug mode without
// downloading the SDK, you can simply comment the line containing
// "VK_LAYER_KHRONOS_validation" below.)
//
// This code was written by following the canonical "Vulkan Tutorial" by
// (presumably) Alexander Overvoorde (bizarrely the home page does not state
// who the author of the tutorial actually is) at:
//
//     https://vulkan-tutorial.com/
//
// The code there, however, is in C++, so has been adapted to Odin.
//
// This code is available on github at:
//
//     https://github.com/10aded/Odin-Vulkan-GLFW-Rainbow-Triangle
//
// and was posted for education purposes.
//
// USED VERBATIM, THE CODE HERE IS LIKELY UNSUITABLE AS PRODUCTION CODE.
// (It may help get you started, though.)
//
// +--------------+
// | Code Summary |
// +--------------+
//
//     "A journey of a thousand miles begins with a single step"
//                                                     --- Laozi 6th cent. BCE
// 0. Spawn a .glfw window.
// 1. Load vulkan functions needed to setup an instance.
// 2. Specify the application info.
// 3. Check that the required / available layers and extensions are compatible.
//     a. Get / specify the required layers,     a list of strings.
//     b. Get / specify the required extensions, a list of strings.
//     c. Get the available layers,              a list of vk structs.
//     d. Get the available extensions,          a list of vk structs.
//     e. Compare the above arrays.
// 4. Create an instance.
// 5. Load the rest of the vulkan functions.
// 6. Create a window surface.
// 7. Select a graphics card (physical device).
//     a. Create a list of the available physical devices.
//     b. Get / specify the required physical device extensions.
//     c. For each physical device, get its supported extensions.
//     d. Choose a physical device that contains the desired extensions.
//        (In this code, we choose the first that contains VK_KHR_swapchain.)
// 8. Check that the window surface is compatible with a swapchain, and choose
//    its settings.
//     a. Get the surface capabilities.
//     b. Get the possible surface formats.
//     c. Get the possible present modes.
//     d. Check that there is at least 1 surface format and present mode.
//     e. Choose a surface format for the swapchain.
//     f. Choose a present mode for the swapchain.
//     g. Choose a swap extent for the swapchain.
//     h. Choose an image count.
// 9. Choose appropriate queue families.
//     a. Get the available queue families.
//     b. Find a queue family that supports GRAPHICS.
//     c. Find a queue family that can present to the surface.
// 10. Set up a logical device to interact with the physical device
//     for each queue family.
//     a. Specify the desired graphics queues to be created.
//     b. Specify the desired presentation queues to be created.
//     c. Specify the set of device features to be used, using queue info in a, b.
//     d. Create a logical device using the struct in c.
// 11. Obtain a handle to the queues from the logical device.
// 12. Create the swapchain using the settings chosen in 8.
// 13. Obtain vk.ImageView s for the swapchain.
//     a. Obtain handles to the vk.Images in the swapchain.
//     b. Create a vk.ImageView for each vk.Image
// 14. Create graphics pipeline.
//     a. Include shaders in the pipeline.
//         i. Create shader modules.
//        ii. Create pipeline shader create infos.
//     b. Specify the dynamic states (or not).
//     c. Describe the format of the vertex data, and how to use triangles.
//     d. Specify viewports and scissors.
//     e. Specify the rasterizer.
//     f. Specify multisampling.
//     g. Specify depth and stencil testing. [skipped]
//     h. Specify color blending.
//     i. Specify pipeline layout (uniforms)
//     j. Create the render pass.
//         i. Specify the framebuffer attachments.
//        ii. Specify the subpasses and dependencies.
//       iii. Create the render pass.
//     k. Finally, create the pipeline with a massive struct using the above!
// 15. Create swapchain framebuffers.
// 16. Record drawing commands in a command buffer.
//     a. Create a command pool.
//     b. Create a command buffer.
//     c. Draw the commands to the command buffer.
//         i. Begin the command buffer.
//        ii. Start a render pass.
//       iii. Bind pipeline.
//        iv. Draw commands.
//         v. End render pass and command buffer.
// 17. Initialize synchronization objects.
// 18. Write the procedure that renders a frame.
//     a. Wait for the previous frame to finish.
//     b. Acquire a swapchain image, reset objects.
//     c. Record drawing commands with the swapchain image.
//     d. Submit the command buffer.
//     e. Present the frame to the swapchain.

package vulkan_tutorial

import f    "core:fmt"
import      "core:dynlib"
import      "core:strings"
import glfw "vendor:glfw"
import vk   "vendor:vulkan"

WINDOW_WIDTH :: 800
WINDOW_HIDTH :: 800

// Change to false to disable verbose debug printing.
DEBUG_VERBOSE :: true

DB    :: "DEBUG:"
DBVB  :: "DEBUG (VERBOSE):"
ERROR :: "ERROR:"
WARNING :: "WARNING:"

// Load the compiled SPIR-V vertex and fragment shader bytecode at compile-time
// as constants.
vertex_shader_bytecode   :: #load("./shaders/vertex.spv")
fragment_shader_bytecode :: #load("./shaders/fragment.spv")

// Globals.
window_handle       : glfw.WindowHandle
instance            : vk.Instance
device              : vk.Device
graphics_queue      : vk.Queue
present_queue       : vk.Queue
surface             : vk.SurfaceKHR
extent              : vk.Extent2D
format              : vk.Format
swapchain           : vk.SwapchainKHR
swapchain_images    : [dynamic] vk.Image
imageviews          : [dynamic] vk.ImageView
vertex_shader_mod   : vk.ShaderModule
fragment_shader_mod : vk.ShaderModule
render_pass         : vk.RenderPass
pipeline_layout     : vk.PipelineLayout
graphics_pipeline   : vk.Pipeline
swapchain_fbs       : [dynamic] vk.Framebuffer
command_pool        : vk.CommandPool
command_buffer      : vk.CommandBuffer

// Synchronization objects
image_available_semaphore : vk.Semaphore
render_finished_semaphore : vk.Semaphore
in_flight_fence           : vk.Fence

init_vulkan :: proc() {
    // 1. Load vulkan functions needed to setup an instance.

    // !!!                !!!
    // !!! Important Step !!!
    // !!!                !!!
    
    // (vk.CreateInstance will otherwise not work.)
    //
    // See "Initializing Vulkan with GLFW" in #help-forum in the Odin Discord.
    // for more information.
    
    vulkan_lib, loaded := dynlib.load_library("vulkan-1.dll")
    assert(loaded)
    
    vkGetInstanceProcAddr, found := dynlib.symbol_address(vulkan_lib, "vkGetInstanceProcAddr")
    assert(found)

    // Load a the Vulkan functions needed to setup an instance.
    vk.load_proc_addresses_global(vkGetInstanceProcAddr)

    // 2. Specify the application info.
    // (Techncially optional.)
    appinfo : vk.ApplicationInfo
    appinfo.sType              = vk.StructureType.APPLICATION_INFO
    appinfo.pApplicationName   = "Rainbow Triangle"
    appinfo.applicationVersion = vk.MAKE_VERSION(1,0,0)
    appinfo.pEngineName        = "Minimal Example Engine"
    appinfo.engineVersion      = vk.MAKE_VERSION(1,0,0)
    appinfo.apiVersion         = vk.API_VERSION_1_0

    // 3. Check that the required / available Vulkan layers
    // and extensions are compatible.

    // 3a. Get / specify the required layers, a list of strings.
    required_layers : [dynamic] cstring
    defer delete(required_layers)

    when ODIN_DEBUG {
        append(&required_layers, "VK_LAYER_KHRONOS_validation")
    }
    
    // 3b. Get / specify the required extensions, a list of strings.
    required_extensions : [] cstring
    required_extensions = glfw.GetRequiredInstanceExtensions()

    // In -debug VERBOSE mode, print out the required layer names and extensions.
    when ODIN_DEBUG && DEBUG_VERBOSE {
        f.println("")
        f.println(DBVB, "Required layers:")
        for rlayer in required_layers {
            f.printf("    %s\n", rlayer)
        }
        f.println("")
        
        f.println(DBVB, "Required extensions:")
        for rextension in required_extensions {
            f.printf("    %s\n", rextension)
        }
        f.println("")
    }
    
    // 3c. Get the available layers, a list of vk structs.    
    // Make a dynamic lists of the supported layers and extensions.
    supported_layers      : [dynamic] vk.LayerProperties
    supported_layer_count : u32

    // Create, then populate, supported_layers.
    // Note: query the number supported layers by leaving the last parameter empty.
    slc_ok := vk.EnumerateInstanceLayerProperties(&supported_layer_count, nil)
    vkok(slc_ok)
    
    supported_layers = make([dynamic] vk.LayerProperties, supported_layer_count)
    defer delete(supported_layers)

    // Fill the empty list with the layer properties.    
    slfill_ok := vk.EnumerateInstanceLayerProperties(&supported_layer_count, raw_data(supported_layers))
    vkok(slfill_ok)


    // 3d. Get the available extensions, a list of vk structs.
    // Basically the same process as in 3c.
    supported_extensions      : [dynamic] vk.ExtensionProperties
    supported_extension_count : u32    
    sec_ok := vk.EnumerateInstanceExtensionProperties(nil, &supported_extension_count, nil)
    vkok(sec_ok)
    supported_extensions = make([dynamic] vk.ExtensionProperties, supported_extension_count)
    defer delete(supported_extensions)
    secfill_ok := vk.EnumerateInstanceExtensionProperties(nil, &supported_extension_count, raw_data(supported_extensions))
    vkok(secfill_ok)
    
    // In -debug VERBOSE mode, print out the supported layers and extensions.
    when ODIN_DEBUG && DEBUG_VERBOSE {
        f.println(DBVB, "Supported layers:")
        // Iterate in a by-reference manner.
        for layer in supported_layers {
            hardcoded_bytes := layer.layerName
            name_slice      := hardcoded_bytes[:]
            lname           := cstring(raw_data(name_slice))
            f.println(lname)
        }
        f.println("")
        
        f.println(DBVB, "Supported extensions:")
        // Iterate in a by-reference manner.
        for extension in supported_extensions {
            hardcoded_bytes := extension.extensionName
            name_slice      := hardcoded_bytes[:]
            ename           := cstring(raw_data(name_slice))
            f.println(ename)
        }
        f.println("")
    }

    // 3e. Compare the above arrays.
    // Check that all of the required layers and glfwExtensions are actually in
    // supported_layers / supported_extensions.

    // Layers first.
    required_layers_available := true
    l1: for layername1 in required_layers {
        for sl in supported_layers {
            hardcoded_bytes := sl.layerName
            name_slice      := hardcoded_bytes[:]
            layername2      := cstring(raw_data(name_slice))
            if layername1 == layername2 { continue l1 }
        }
        // If execution has reached here, a required layer has not been found.
        f.println(ERROR, "A required layer:", layername1, "is missing!")
        required_layers_available = false
        break l1
    }

    // Now check extensions, same as above.
    required_extensions_available := true
    l2: for extensionname1 in required_extensions {
        for sl in supported_extensions {
            hardcoded_bytes := sl.extensionName
            name_slice      := hardcoded_bytes[:]
            extensionname2      := cstring(raw_data(name_slice))
            if extensionname1 == extensionname2 { continue l2 }
        }
        f.println(ERROR, "A required extension:", extensionname1, "is missing!")
        required_extensions_available = false
        break l2
    }
    
    assert(required_layers_available && required_extensions_available)

    when ODIN_DEBUG {
        f.println(DB, "The required layers and extensions are in the supported layers and extensions.\n")
    }
    
    // +-------------------------------------------------------------------+
    // | Now that we have verified the required layers and extensions are  |
    // | supported, we can make a vk.Instance.                             |
    // +-------------------------------------------------------------------+
    //
    // 4. Create an instance.
    
    // Set up the info required to make an instance.
    icreateinfo : vk.InstanceCreateInfo
    icreateinfo.sType                   = vk.StructureType.INSTANCE_CREATE_INFO
    icreateinfo.pApplicationInfo        = &appinfo
    icreateinfo.enabledLayerCount       = u32(len(required_layers))
    icreateinfo.ppEnabledLayerNames     = raw_data(required_layers)
    icreateinfo.enabledExtensionCount   = u32(len(required_extensions))
    icreateinfo.ppEnabledExtensionNames = raw_data(required_extensions)

    // Create the Instance (finally)!
    ci_ok := vk.CreateInstance(&icreateinfo, nil, &instance)
    vkok(ci_ok)

    // 5. Load the rest of the vulkan functions.
    // +----------------------------------------------------------------+
    // | REMEMBER TO LOAD THE OTHER VULKAN FUNCTIONS WITH THE INSTANCE. |
    // +----------------------------------------------------------------+
    vk.load_proc_addresses(instance)

    // 6. Create a window surface.
    ws_ok := glfw.CreateWindowSurface(instance, window_handle, nil, &surface)
    vkok(ws_ok)
    
    // 7. Select a graphics card (physical device) or whatever's available.
    physical_device  : vk.PhysicalDevice
    physical_devices : [dynamic] vk.PhysicalDevice
    pds_count        : u32

    // 7a. Create a list of the available physical devices.
    // Note: query the number of physical devices by making the last param nil.
    pdc_ok := vk.EnumeratePhysicalDevices(instance, &pds_count, nil)
    vkok(pdc_ok)
    if pds_count == 0 {
        f.eprintln(ERROR, "Number of physical devices is 0!") ; assert(false)
    }
    physical_devices = make([dynamic] vk.PhysicalDevice, pds_count)

    // Get the pds. Physical devices are just rawptrs.
    pdfill_ok := vk.EnumeratePhysicalDevices(instance, &pds_count, raw_data(physical_devices))
    vkok(pdfill_ok)

    // In -debug VERBOSE mode, print out the available physical devices.
    when ODIN_DEBUG && DEBUG_VERBOSE {
        f.println(DBVB, "Possible physical devices:")
        for pd in physical_devices {
            pd_props :  vk.PhysicalDeviceProperties
            vk.GetPhysicalDeviceProperties(pd, &pd_props)
            f.printf("    %s\n", pd_props.deviceName)
        }
        f.println("")
    }    

    // 7b. Get / specify the required physical device extensions.
    pdevice_required_extensions := [] cstring{
        vk.KHR_SWAPCHAIN_EXTENSION_NAME,
    }

    // 7c. For each physical device, get its supported extensions.
    at_least_one_pdevice_okay := false
    okay_pdevice : vk.PhysicalDevice
    pdevice_properties : vk.PhysicalDeviceProperties
    
    for pdevice in physical_devices {
        pd_properties : vk.PhysicalDeviceProperties
        // Bizarrely, this doesn't return a vk.Result
        vk.GetPhysicalDeviceProperties(pdevice, &pd_properties)

        pdevice_supported_extensions       : [dynamic] vk.ExtensionProperties
        pdevice_supported_extensions_count : u32
        
        pdec_ok := vk.EnumerateDeviceExtensionProperties(pdevice, nil, &pdevice_supported_extensions_count, nil)
        vkok(pdec_ok)
        
        pdevice_supported_extensions = make([dynamic] vk.ExtensionProperties, pdevice_supported_extensions_count)
        depfill_ok := vk.EnumerateDeviceExtensionProperties(pdevice, nil, &pdevice_supported_extensions_count, raw_data(pdevice_supported_extensions))
        vkok(depfill_ok)

        pdname := transmute(cstring) &pd_properties.deviceName
        
        when ODIN_DEBUG && DEBUG_VERBOSE {
            f.println(DBVB, "Supported extensions of", pdname, ":")
            // Iterate in a by-reference manner.
            for pse in pdevice_supported_extensions {
                hardcoded_bytes := pse.extensionName
                name_slice      := hardcoded_bytes[:]
                ename  := cstring(raw_data(name_slice))
                f.printf("    %s\n", ename)
            }
            f.println("")
        }
        
        // 7d. Choose a physical device that contains the desired extensions.
        //    (In our case, choose the first such physical device.)
        required_pdevice_extensions_available := true
        l3: for extensionname1 in pdevice_required_extensions {
            for pse in pdevice_supported_extensions {
                hardcoded_bytes := pse.extensionName
                name_slice      := hardcoded_bytes[:]
                extensionname2  := cstring(raw_data(name_slice))
                if extensionname1 == extensionname2 { continue l3 }
            }
            f.println(WARNING, "A required extension:", extensionname1, "is missing from:", pdname)
            required_pdevice_extensions_available = false
            break l3
        }
        if required_pdevice_extensions_available {
            at_least_one_pdevice_okay = true
            okay_pdevice = pdevice
            pdevice_properties = pd_properties
        } else {
            continue
        }
    }        

    if ! at_least_one_pdevice_okay {
        f.eprintln("No physical devices have all the required extensions")
        assert(false)
    }

    pdevice := okay_pdevice

    when ODIN_DEBUG {
        f.println(DB, "A physical device has been chosen.")
        f.println(DB, "The physical device has name / type:")
        name := transmute(cstring) &pdevice_properties.deviceName
        f.printf("    %s", name)
        f.println("    /    ", pdevice_properties.deviceType)
        f.println("")
    }

    // 8. Check that the window surface is compatible with a swapchain, and choose
    //    its settings.
    
    // Note: In a more advanced implementation, this could be factored into the
    // physical device selection itself, but we omit this for simplicity.
    
    surface_capabilities            : vk.SurfaceCapabilitiesKHR
    supported_surface_formats       : [dynamic] vk.SurfaceFormatKHR
    supported_present_modes         : [dynamic] vk.PresentModeKHR
    supported_surface_formats_count : u32
    supported_present_modes_count   : u32

    // 8a. Get the surface capabilities.
    vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(pdevice, surface, &surface_capabilities)
    
    // 8b. Get the possible surface formats.
    sfc_ok := vk.GetPhysicalDeviceSurfaceFormatsKHR(pdevice, surface, &supported_surface_formats_count, nil)
    vkok(sfc_ok)

    if supported_surface_formats_count != 0 {
        supported_surface_formats = make([dynamic] vk.SurfaceFormatKHR, supported_surface_formats_count)
        gpdsf_ok := vk.GetPhysicalDeviceSurfaceFormatsKHR(pdevice, surface, &supported_surface_formats_count, raw_data(supported_surface_formats))
        vkok(gpdsf_ok)
    }
    
    // 8c. Get the possible present modes.
    pmc_ok := vk.GetPhysicalDeviceSurfacePresentModesKHR(pdevice, surface, &supported_present_modes_count, nil)
    vkok(pmc_ok)
    
    if supported_present_modes_count != 0 {
        supported_present_modes = make([dynamic] vk.PresentModeKHR, supported_present_modes_count)
        gpdspm_ok := vk.GetPhysicalDeviceSurfacePresentModesKHR(pdevice, surface, &supported_present_modes_count, raw_data(supported_present_modes))
        vkok(gpdspm_ok)
    }
    
    when ODIN_DEBUG && DEBUG_VERBOSE {
        f.println(DBVB, "Supported surface capabilities:")
        f.printf("    ")
        f.println(surface_capabilities)
        f.println("")
        
        f.println(DBVB, "Supported surface formats:")
        for sf in supported_surface_formats {
            f.printf("    ")
            f.println(sf)
        }
        f.println("")
        
        f.println(DBVB, "Supported present modes:")
        for pm in supported_present_modes {
            f.printf("    ")
            f.println(pm)
        }
        f.println("")
    }

    // 8d. Check that there is at least 1 surface format and present mode.
    if supported_surface_formats_count == 0 {
        f.eprint(ERROR, "There are no surface formats!")
        assert(false)
    }
    if supported_present_modes_count == 0 {
        f.eprint(ERROR, "There are no present modes!")
        assert(false)
    }

    // 8e. Choose a surface format for the swapchain.
    surface_format         := supported_surface_formats[0]
    desired_surface_format := vk.SurfaceFormatKHR{
        format     = .B8G8R8A8_SRGB,
        colorSpace = .SRGB_NONLINEAR,
    }
    
    for sf in supported_surface_formats {
        if sf == desired_surface_format {
            surface_format = desired_surface_format
            break
        }
    }

    // Set the global format
    format = surface_format.format
    
    when ODIN_DEBUG {
        f.println(DB, "Surface format selected:")
        f.printf("    ")
        f.println(surface_format)
        f.println("")
    }

    // 8f. Choose a present mode for the swapchain.
    // Note: Per the VkPresentModeKHR(3) manual page,
    // FIFO is required to be supported, so the initial assignment below is safe.
    present_mode         := vk.PresentModeKHR.FIFO
    desired_present_mode := vk.PresentModeKHR.MAILBOX
    
    for pm in supported_present_modes {
        if pm == desired_present_mode {
            present_mode = desired_present_mode
        }
    }
    
    when ODIN_DEBUG {
        f.println(DB, "Present mode selected:")
        f.printf("    ")
        f.println(present_mode)
        f.println("")
    }

    // 8g. Choose a swap extent for the swapchain.
    extent_special_value := vk.Extent2D{
        max(u32),
        max(u32),
    }
    // Per the VkSurfaceCapabilitiesKHR(3) man page,
    // if the current extent is extent_special_value,
    // then we have to specify this ourselves.
    // In such a case, we'll just choose the .minImageExtent.
    
    extent = surface_capabilities.currentExtent
    if extent == extent_special_value {
        extent = surface_capabilities.minImageExtent
    }

    when ODIN_DEBUG {
        f.println(DB, "Extent chosen:")
        f.printf("    ")
        f.println(extent)
        f.println("")
    }

    // 8h. Choose an image count.
    surface_image_count := min(surface_capabilities.minImageCount + 1, surface_capabilities.maxImageCount)

    // 9. Choose appropriate queue families.
    
    // 9a. Get the available queue families.
    qf_properties : [dynamic] vk.QueueFamilyProperties
    queue_count   : u32    

    // Note: query the number of extensions by leaving the last parameter empty.
    // Bizarrely, this doesn't return a .SUCCESS value.
    vk.GetPhysicalDeviceQueueFamilyProperties(pdevice, &queue_count, nil)
    qf_properties = make([dynamic] vk.QueueFamilyProperties, queue_count)
    vk.GetPhysicalDeviceQueueFamilyProperties(pdevice, &queue_count, raw_data(qf_properties))

    // IN -debug VERBOSE mode, print out the available queue families.
    when ODIN_DEBUG && DEBUG_VERBOSE {
        f.println(DBVB, "Queue family properties:")
        for qf, qfi in qf_properties {
            f.printf("    Queue %d:\n", qfi)
            f.printf("        Flags:\t")
            f.println(qf.queueFlags)
            f.printf("        Count:\t")
            f.println(qf.queueCount)
            f.printf("        timestampValidBits / minImageTransferGranularity:\t")
            f.println(qf.timestampValidBits, qf.minImageTransferGranularity)
        }
        f.println("")
    }

    // The queue families supporting graphics and presentation may actually
    // be different. (But in many cases they are the same.)
    // As such, find each individually.
    
    // 9b. Find a queue family that supports GRAPHICS.
    // Recall the "e in A" Odin syntax for bit_sets.
    graphics_family_queue_index : u32
    found_gqf := false

    for qf, i in qf_properties {
        if vk.QueueFlag.GRAPHICS in qf.queueFlags {
            graphics_family_queue_index = u32(i)
            found_gqf = true
            break
        }
    }
    
    if ! found_gqf {
        f.eprintln(ERROR, "Unable to find a valid .GRAPHICS Queue family!")
        assert(false)
    }
    
    when ODIN_DEBUG {
        f.println(DB, "Graphics Family Queue Index Found:", graphics_family_queue_index)
        f.println("")
    }

    // 9c. Find a queue family that can present to the surface.
    surface_presentation_queue_index : u32
    found_pqf := false
    
    for qf, i in qf_properties {
        qf_supports_window : b32
        qf_window_support_check_ok := vk.GetPhysicalDeviceSurfaceSupportKHR(pdevice, u32(i), surface, &qf_supports_window)
        vkok(qf_window_support_check_ok)
        
        if qf_supports_window {
            surface_presentation_queue_index = u32(i)
            found_pqf = true
            break
        }
    }
    
    if ! found_pqf {
        f.eprintln(ERROR, "Unable to find a valid Queue family for surface presentation!")
        assert(false)
    }
    when ODIN_DEBUG {
        f.println(DB, "Surface Presentation Family Queue Index Found:", surface_presentation_queue_index)
        f.println("")
    }

    // 10. Set up a logical device to interact with the physical device
    // for each queue family.

    // 10a. Specify the desired graphics queues to be created.
    qci_graphics : vk.DeviceQueueCreateInfo
    queue_priority_graphics : f32 = 1

    qci_graphics.sType            = vk.StructureType.DEVICE_QUEUE_CREATE_INFO
    qci_graphics.queueFamilyIndex = graphics_family_queue_index
    qci_graphics.queueCount       = 1.0
    qci_graphics.pQueuePriorities = &queue_priority_graphics

    // 10b. Specify the desired presentation queues to be created.
    qci_present := qci_graphics
    qci_present.queueFamilyIndex = surface_presentation_queue_index

    // 10c. Specify the set of device features to be used, using queue info in a, b.
    
    // !!           !!
    // !! Important !!
    // !!           !!
    //
    // NOTE: Per the vkDeviceCreateInfo(3) manual page,
    // 
    //     "The queueFamilyIndex member of each element of pQueueCreateInfos must
    //      be unique within pQueueCreateInfos, except that two members can share
    //      the same queueFamilyIndex if one describes protected-capable queues
    //      and one describes queues that are not protected-capable."
    //
    // As such, if graphics_family_queue_index == surface_presentation_queue_index,
    // we should only pass in a single qci when calling vk.CreateDevice.
    
    queue_create_infos := make([dynamic] vk.DeviceQueueCreateInfo)
    defer delete(queue_create_infos)
    
    append(&queue_create_infos, qci_graphics)
    
    if (graphics_family_queue_index != surface_presentation_queue_index) {
        append(&queue_create_infos, qci_present)
    }

    // To be filled in later when we begin to do interesting things.
    device_features : vk.PhysicalDeviceFeatures
    
    // Specify the device features for the graphics and presenation queue.
    dci : vk.DeviceCreateInfo
    dci.sType                   = vk.StructureType.DEVICE_CREATE_INFO
    dci.queueCreateInfoCount    = u32(len(queue_create_infos))
    dci.pQueueCreateInfos       = raw_data(queue_create_infos)
    dci.pEnabledFeatures        = &device_features
    dci.enabledExtensionCount   = u32(len(pdevice_required_extensions))
    dci.ppEnabledExtensionNames = raw_data(pdevice_required_extensions)

    // In up-to-date implementations,
    // dci.enabledLayerCount and dci.ppEnabledLayerNames can be ignored.
    // (these would otherwise be the same as the required_extensions in
    // the instance setup).

    // 10d. Create a logical device using the struct in c.
    cd_ok := vk.CreateDevice(pdevice, &dci, nil, &device)
    vkok(cd_ok)

    // 11. Obtain a handle to the queues from the logical device.
    // Queues are created with the logical device, so obtain a handle to them.
    // Note: the procedure below doesn't return a value.
    vk.GetDeviceQueue(device, graphics_family_queue_index, 0, &graphics_queue)
    vk.GetDeviceQueue(device, graphics_family_queue_index, 0, &present_queue)

    when ODIN_DEBUG && DEBUG_VERBOSE {
        f.println(DBVB, "Graphics queue handle:", graphics_queue, "\n")
        f.println(DBVB, "Present queue handle:",  present_queue,  "\n")
    }

    // 12. Create the swapchain using the settings chosen in 8.
    
    swpcnci : vk.SwapchainCreateInfoKHR
    swpcnci.sType            = .SWAPCHAIN_CREATE_INFO_KHR
    swpcnci.surface          = surface
    swpcnci.minImageCount    = surface_image_count
    swpcnci.imageFormat      = format
    swpcnci.imageColorSpace  = surface_format.colorSpace
    swpcnci.imageExtent      = extent
    swpcnci.imageArrayLayers = 1 // 1 for non-stereoscopic-3D apps, per man page.
    swpcnci.imageUsage       = { vk.ImageUsageFlag.COLOR_ATTACHMENT }

    // The next three fields of swpcnci depend on whether or not
    // the graphics_family_queue and the surface_presentation_queue
    // are the same, similar to 10c.
    if graphics_family_queue_index != surface_presentation_queue_index {
        swpcnci.imageSharingMode = vk.SharingMode.CONCURRENT
        swpcnci.queueFamilyIndexCount = 2
        swpcnci.pQueueFamilyIndices = raw_data([]u32{
            graphics_family_queue_index,
            surface_presentation_queue_index,
        })
    } else {
        swpcnci.imageSharingMode = .EXCLUSIVE
    }
    swpcnci.preTransform   = surface_capabilities.currentTransform
    swpcnci.compositeAlpha = { vk.CompositeAlphaFlagKHR.OPAQUE }
    swpcnci.presentMode    = present_mode
    swpcnci.clipped        = true

    // Create the swapchain!
    swapchaincreation_ok := vk.CreateSwapchainKHR(device, &swpcnci, nil, &swapchain)
    vkok(swapchaincreation_ok)
    when ODIN_DEBUG {
        f.println(DB, "Swapchain successfully created!")
    }

    // 13. Obtain vk.ImageView s for the swapchain.
    
    // 13a. Obtain handles to the vk.Images in the swapchain.
    // The swapchain may have increased the surface_image_count, so we need to
    // get its (possibly) new value.
    device_image_count := surface_image_count
    dic_ok := vk.GetSwapchainImagesKHR(device, swapchain, &device_image_count, nil)
    vkok(dic_ok)
    
    swapchain_images = make([dynamic] vk.Image, device_image_count)
    gsci_ok := vk.GetSwapchainImagesKHR(device, swapchain, &device_image_count, raw_data(swapchain_images))
    vkok(gsci_ok)

    when ODIN_DEBUG && DEBUG_VERBOSE {
        f.println(DBVB, "Number of swapchain images:", device_image_count)
        f.println("")
    }

    // 13b. Create a vk.ImageView for each vk.Image
    imageviews = make([dynamic] vk.ImageView, device_image_count)
    for i in 0..<device_image_count {
        imvci : vk.ImageViewCreateInfo
        imvci.sType = .IMAGE_VIEW_CREATE_INFO
        imvci.image = swapchain_images[i]
        imvci.viewType = vk.ImageViewType.D2
        imvci.format = format
        imvci.components = {
			r = .IDENTITY,
			g = .IDENTITY,
			b = .IDENTITY,
			a = .IDENTITY,
		}
        imvci.subresourceRange = {
            aspectMask     = { .COLOR },
            baseMipLevel   = 0,
            levelCount     = 1,
            baseArrayLayer = 0,
            layerCount     = 1,
        }
        cimvok := vk.CreateImageView(device, &imvci, nil, &imageviews[i])
        vkok(cimvok)
    }
    when ODIN_DEBUG && DEBUG_VERBOSE {
        f.println(DBVB, "ImageViews:")
        f.println(imageviews)
        f.println("")
    }

    // 14. Create graphics pipeline.

    // 14a. Include shaders in the pipeline.
    
    // 14a.i. Create shader modules.
    vsci : vk.ShaderModuleCreateInfo
    vsci.sType    = .SHADER_MODULE_CREATE_INFO
    vsci.codeSize = len(vertex_shader_bytecode)
    vsci.pCode    = cast(^u32) raw_data(vertex_shader_bytecode)

    fsci : vk.ShaderModuleCreateInfo
    fsci.sType    = .SHADER_MODULE_CREATE_INFO
    fsci.codeSize = len(fragment_shader_bytecode)
    fsci.pCode    = cast(^u32) raw_data(fragment_shader_bytecode)

    vs_loaded_ok := vk.CreateShaderModule(device, &vsci, nil, &vertex_shader_mod)
    vkok(vs_loaded_ok)
    fs_loaded_ok := vk.CreateShaderModule(device, &fsci, nil, &fragment_shader_mod)
    vkok(fs_loaded_ok)

    // 14a.ii. Create pipeline shader create infos.
    vspssci : vk.PipelineShaderStageCreateInfo
    vspssci.sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO
	vspssci.stage  = { .VERTEX }
	vspssci.module = vertex_shader_mod
	vspssci.pName  = "main"

    fspssci : vk.PipelineShaderStageCreateInfo
    fspssci.sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO
	fspssci.stage  = { .FRAGMENT }
	fspssci.module = fragment_shader_mod
	fspssci.pName  = "main"

    shader_stages := [] vk.PipelineShaderStageCreateInfo{
        vspssci,
        fspssci,
    }

    // 14b. Specify the dynamic states (or not).

    // (We'll make these concrete for now.)
    /*
    dynamic_states := [] vk.DynamicState{
            .VIEWPORT,
            .SCISSOR,
    }
    pdsci : vk.PipelineDynamicStateCreateInfo
    pdsci.sType             = .PIPELINE_DYNAMIC_STATE_CREATE_INFO
    pdsci.dynamicStateCount = u32(len(dynamic_states))
    pdsci.pDynamicStates    = raw_data(dynamic_states)
    */

    // 14c. Describe the format of the vertex data, and how to use triangles.
    // (Vertex data skipped for now, will come back to later.)
    pvisci : vk.PipelineVertexInputStateCreateInfo
    pvisci.sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
    pvisci.vertexBindingDescriptionCount   = 0
	pvisci.pVertexBindingDescriptions      = nil
	pvisci.vertexAttributeDescriptionCount = 0
	pvisci.pVertexAttributeDescriptions    = nil
    
    piasci : vk.PipelineInputAssemblyStateCreateInfo
    piasci.sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
    piasci.topology = vk.PrimitiveTopology.TRIANGLE_LIST
    piasci.primitiveRestartEnable = false

    // 14d. Specify viewports and scissors.

    // The last two coordinates are the min and maxDepth.
    // This is done differently if doing dynamically, but
    // not for now.
    viewport := vk.Viewport{0, 0, f32(extent.width), f32(extent.height), 0, 1}
    scissor := vk.Rect2D{
        {0,0},
        extent,
    }

    pvsci : vk.PipelineViewportStateCreateInfo
    pvsci.sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO
    pvsci.viewportCount = 1
    pvsci.pViewports    = &viewport
    pvsci.scissorCount  = 1
    pvsci.pScissors     = &scissor

    // 14e. Specify the rasterizer.
    prsci : vk.PipelineRasterizationStateCreateInfo
    prsci.sType                   = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO
	prsci.depthClampEnable        = false
	prsci.rasterizerDiscardEnable = false
	prsci.polygonMode             = vk.PolygonMode.FILL
	prsci.cullMode                = { .BACK }
	prsci.frontFace               = vk.FrontFace.CLOCKWISE
	prsci.depthBiasEnable         = false
	prsci.lineWidth               = 1

    // 10f. Specify multisampling.
    // This will be revisited later.

    pmsci : vk.PipelineMultisampleStateCreateInfo
    pmsci.sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
    pmsci.rasterizationSamples = { vk.SampleCountFlag._1 }
    pmsci.sampleShadingEnable = false

    // 14g. Depth and stencil testing. [skipped]

    // 14h. Specify color blending.
    pcbas : vk.PipelineColorBlendAttachmentState
    pcbas.blendEnable = true
    pcbas.srcColorBlendFactor = vk.BlendFactor.SRC_ALPHA
    pcbas.dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA
    pcbas.colorBlendOp        = .ADD
    pcbas.srcAlphaBlendFactor = .ONE
    pcbas.dstAlphaBlendFactor = .ZERO
    pcbas.alphaBlendOp        = .ADD
    pcbas.colorWriteMask            = { .R, .G, .B, .A }

    pcbsci : vk.PipelineColorBlendStateCreateInfo
    pcbsci.sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
    pcbsci.logicOpEnable   = false
    pcbsci.attachmentCount = 1
    pcbsci.pAttachments    = &pcbas

    // 14i. Specify pipeline layout (uniforms)
    
    plci : vk.PipelineLayoutCreateInfo
    plci.sType = .PIPELINE_LAYOUT_CREATE_INFO
    plci.setLayoutCount = 0

    plc_ok := vk.CreatePipelineLayout(device, &plci, nil, &pipeline_layout)
    vkok(plc_ok)

    // 14j. Create the render pass.
    
    // 14j.i. Specify the framebuffer attachments.
    cad : vk.AttachmentDescription
    cad.format         = format
    cad.samples        = { ._1 }
    cad.loadOp         = vk.AttachmentLoadOp.CLEAR
    cad.storeOp        = vk.AttachmentStoreOp.STORE
    cad.stencilLoadOp  = .DONT_CARE
    cad.stencilStoreOp = .DONT_CARE
    cad.initialLayout  = vk.ImageLayout.UNDEFINED
    cad.finalLayout    = .PRESENT_SRC_KHR

    // 14j.ii. Specify the subpasses and dependencies.
    caf : vk.AttachmentReference
    caf.attachment = 0
    caf.layout = vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL

    subdes : vk.SubpassDescription
    subdes.pipelineBindPoint    = vk.PipelineBindPoint.GRAPHICS
    subdes.colorAttachmentCount = 1
    subdes.pColorAttachments    = &caf

	subdep : vk.SubpassDependency
	subdep.srcSubpass    = vk.SUBPASS_EXTERNAL
	subdep.dstSubpass    = 0
	subdep.srcStageMask  = { .COLOR_ATTACHMENT_OUTPUT }
	subdep.dstStageMask  = { .COLOR_ATTACHMENT_OUTPUT }
	subdep.dstAccessMask = { .COLOR_ATTACHMENT_WRITE }

    // 14j.iii. Create the render pass.
    rpci : vk.RenderPassCreateInfo
    rpci.sType           = .RENDER_PASS_CREATE_INFO
    rpci.attachmentCount = 1
    rpci.pAttachments    = &cad
    rpci.subpassCount    = 1
    rpci.pSubpasses      = &subdes
    rpci.dependencyCount = 1
    rpci.pDependencies   = &subdep

    rpc_ok := vk.CreateRenderPass(device, &rpci, nil, &render_pass)
    vkok(rpc_ok)

    when ODIN_DEBUG && DEBUG_VERBOSE {
        f.println(DBVB, "Render pass:", render_pass)
        f.println("")
    }
    
    // 14k. Finally, create the pipeline with a massive struct using the above!
    gpci : vk.GraphicsPipelineCreateInfo
    gpci.sType               = .GRAPHICS_PIPELINE_CREATE_INFO
    gpci.stageCount          = 2
    gpci.pStages             = raw_data(shader_stages)
    gpci.pVertexInputState   = &pvisci
    gpci.pInputAssemblyState = &piasci
    gpci.pViewportState      = &pvsci
    gpci.pRasterizationState = &prsci
    gpci.pMultisampleState   = &pmsci
    gpci.pColorBlendState    = &pcbsci
    gpci.layout              = pipeline_layout
    gpci.renderPass          = render_pass
    gpci.subpass             = 0

    cgp_ok := vk.CreateGraphicsPipelines(device, 0, 1, &gpci, nil, &graphics_pipeline)
    vkok(cgp_ok)

    when ODIN_DEBUG {
        f.println(DB, "Graphics pipeline successfully created!")
    }
    when ODIN_DEBUG && DEBUG_VERBOSE {
        f.println(DBVB, "Graphics Pipeline:", graphics_pipeline)
        f.println("")
    }
    

    // 15. Create swapchain framebuffers.
    assert(device_image_count == u32(len(imageviews)))
    swapchain_fbs = make([dynamic] vk.Framebuffer, device_image_count)
    for i in 0..<device_image_count {
        fbci : vk.FramebufferCreateInfo
        fbci.sType = .FRAMEBUFFER_CREATE_INFO
        fbci.renderPass = render_pass
        fbci.attachmentCount = 1
        fbci.pAttachments = &imageviews[i]
        fbci.width = extent.width
        fbci.height = extent.height
        fbci.layers = 1
        
        cfb_ok := vk.CreateFramebuffer(device, &fbci, nil, &swapchain_fbs[i])
        vkok(cfb_ok)
    }

    when ODIN_DEBUG && DEBUG_VERBOSE {
        f.println(DBVB, "Swapchain Framebuffers")
        f.println(swapchain_fbs)
        f.println("")
    }

    // 16. Record drawing commands in a command buffer.
    // 16a. Create a command pool.
        
    cpci : vk.CommandPoolCreateInfo
    cpci.sType            = .COMMAND_POOL_CREATE_INFO
    cpci.flags            = { vk.CommandPoolCreateFlags.RESET_COMMAND_BUFFER }
    cpci.queueFamilyIndex = graphics_family_queue_index

    ccp_ok := vk.CreateCommandPool(device, &cpci, nil, &command_pool)
    vkok(ccp_ok)

    // 16b. Create a command buffer.
    cbai : vk.CommandBufferAllocateInfo
    cbai.sType              = .COMMAND_BUFFER_ALLOCATE_INFO
    cbai.commandPool        = command_pool
    cbai.level              = .PRIMARY
    cbai.commandBufferCount = 1

    acb_ok := vk.AllocateCommandBuffers(device, &cbai, &command_buffer)
    vkok(acb_ok)    

    // 17. Initialize synchronization objects.
    sci : vk.SemaphoreCreateInfo
    sci.sType = .SEMAPHORE_CREATE_INFO

    fci : vk.FenceCreateInfo
    fci.sType = .FENCE_CREATE_INFO
    fci.flags = { .SIGNALED }

    s1_ok := vk.CreateSemaphore(device, &sci, nil, &image_available_semaphore)
    vkok(s1_ok)
    s2_ok := vk.CreateSemaphore(device, &sci, nil, &render_finished_semaphore)
    vkok(s2_ok)
    f1_ok := vk.CreateFence(device, &fci, nil, &in_flight_fence)
    vkok(f1_ok)

    when ODIN_DEBUG && DEBUG_VERBOSE {
        f.println(DBVB, "Semaphores and fences created.\n")
    }
}

vkok :: proc(result : vk.Result, loc := #caller_location) {
    #partial switch result {
        case .SUCCESS:
        case .ERROR_OUT_OF_HOST_MEMORY:
        f.eprintln(ERROR, "Out of host memory.")
        case .ERROR_OUT_OF_DEVICE_MEMORY:
        f.eprintln(ERROR, "Out of device memory.")
        case .ERROR_INITIALIZATION_FAILED:
        f.eprintln(ERROR, "Initialization failed.")
        case .ERROR_LAYER_NOT_PRESENT:
        f.eprintln(ERROR, "Layer not present.")
        case .ERROR_EXTENSION_NOT_PRESENT:
        f.eprintln(ERROR, "Extension not present.")        
        case .ERROR_INCOMPATIBLE_DRIVER:
        f.eprintln(ERROR, "Incompatible driver.")
        case:
        f.eprintln(ERROR, "Other Spec 1.3 Error!")
    }
    if result != .SUCCESS {
        f.println(ERROR, "vk function result was not .SUCCESS")
        f.println(    "Result was instead:", result)
        f.println("    Error at:")
        f.println("    ", loc)
        assert(false)
    }
}

main :: proc() {
    // 0. Spawn a .glfw window.
    glfw.Init()
    defer glfw.Terminate()

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)

    window_handle = glfw.CreateWindow(1000, 1000, "Vulkan Window", nil, nil)
    assert(window_handle != nil)
    defer glfw.DestroyWindow(window_handle)

    init_vulkan()
    
    for (! glfw.WindowShouldClose(window_handle)) {
        glfw.PollEvents()
        render_frame()
    }

    // Doesn't seem to be needed.
    // vk.DestroyDevice(device, nil)
}

// 16c. Draw the commands to the command buffer.
record_command_buffer :: proc(cmdbuf : vk.CommandBuffer, stage_index : u32) {
    // 16c.i. Begin the command buffer.
    cbbi : vk.CommandBufferBeginInfo
    cbbi.sType = .COMMAND_BUFFER_BEGIN_INFO

    bcb_ok := vk.BeginCommandBuffer(command_buffer, &cbbi)
    vkok(bcb_ok)


    
    // 16c.ii. Start a render pass.
    clear_color := vk.ClearValue{
        color = { float32 = {0,0,0,1}}
    }
    
    rpbi : vk.RenderPassBeginInfo
    rpbi.sType = .RENDER_PASS_BEGIN_INFO
    rpbi.renderPass = render_pass
    rpbi.framebuffer = swapchain_fbs[stage_index]
    rpbi.renderArea = {
        offset = {0,0},
        extent = extent,
    }
    rpbi.clearValueCount = 1
    rpbi.pClearValues = &clear_color

    vk.CmdBeginRenderPass(command_buffer, &rpbi, vk.SubpassContents.INLINE)

    // 16c.iii. Bind pipeline.
    vk.CmdBindPipeline(command_buffer, vk.PipelineBindPoint.GRAPHICS, graphics_pipeline)
    //  16c.iv. Draw commands.
    // 1200 Lines of setup code have lead to this.
    
    vk.CmdDraw(command_buffer, 3, 1, 0, 0)

    //  16c.v. End render pass and command buffer.
    vk.CmdEndRenderPass(command_buffer)

    ecb_ok := vk.EndCommandBuffer(command_buffer)
    vkok(ecb_ok)
}

// 18. Write the procedure that renders a frame.
render_frame :: proc() {
    // 18a. Wait for the previous frame to finish.
    wff_ok := vk.WaitForFences(device, 1, &in_flight_fence, true, max(u64))
    vkok(wff_ok)

    // 18b. Acquire a swapchain image, reset objects.
    image_index : u32
    ani_ok := vk.AcquireNextImageKHR(device, swapchain, max(u64), image_available_semaphore, 0, &image_index)
    vkok(ani_ok)

    rf_ok := vk.ResetFences(device, 1, &in_flight_fence)
    vkok(rf_ok)
    
    rcb_ok := vk.ResetCommandBuffer(command_buffer, {})
    vkok(rcb_ok)

    // 18c. Record drawing commands with the swapchain image.
    record_command_buffer(command_buffer, image_index)

    // 18d. Submit the command buffer.
    submit_info : vk.SubmitInfo
    submit_info.sType = .SUBMIT_INFO
    submit_info.waitSemaphoreCount = 1
    submit_info.pWaitSemaphores = &image_available_semaphore
    submit_info.pWaitDstStageMask = &vk.PipelineStageFlags{ .COLOR_ATTACHMENT_OUTPUT }
    submit_info.commandBufferCount = 1
    submit_info.pCommandBuffers = &command_buffer
    submit_info.signalSemaphoreCount = 1
    submit_info.pSignalSemaphores = &render_finished_semaphore

    qs_ok := vk.QueueSubmit(graphics_queue, 1, &submit_info, in_flight_fence)
    vkok(qs_ok)

    // 18e. Present the frame to the swapchain.
    present_info : vk.PresentInfoKHR
	present_info.sType = .PRESENT_INFO_KHR
	present_info.waitSemaphoreCount = 1
	present_info.pWaitSemaphores = &render_finished_semaphore
	present_info.swapchainCount = 1
	present_info.pSwapchains = &swapchain
	present_info.pImageIndices = &image_index

    vk.QueuePresentKHR(present_queue, &present_info)
}
