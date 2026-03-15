#include <cstddef>
#include <cstdint>
#include <cmath>
#include <fstream>
#include <memory>
#include <string>

#include "Camera.h"
#include "MathDefs.h"
#include "ParticleSimulation.h"
#include "TwoDSceneXMLParser.h"
#include "RenderingUtilities.h"

// For simplicity, write to this fixed path. 
// Since libFuzzer executes in a single process, overwriting this file is safe.
static const char* kTmpScenePath = "/tmp/libwetcloth_fuzz_scene.xml";

extern "C" int LLVMFuzzerInitialize(int* /*argc*/, char*** /*argv*/) {
  // Initialize Eigen threads, etc. (similar to Main.cpp)
  Eigen::initParallel();
  // Lock thread count to 1 for determinism
  Eigen::setNbThreads(1);

  // Set fixed random seed to reduce non-determinism
  srand(0x0108170F);
  return 0;
}

static bool WriteInputToTempFile(const uint8_t* data, size_t size) {
  if (!data || size == 0) {
    return false;
  }

  // Limit maximum input size to avoid excessively large writes
  const size_t kMaxSize = 1 << 20; // 1MB
  if (size > kMaxSize) {
    size = kMaxSize;
  }

  std::ofstream ofs(kTmpScenePath,
                    std::ios::binary | std::ios::out | std::ios::trunc);
  if (!ofs.is_open()) {
    return false;
  }

  ofs.write(reinterpret_cast<const char*>(data),
            static_cast<std::streamsize>(size));
  if (!ofs.good()) {
    return false;
  }

  return true;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  // Inputs that are too short cannot constitute valid XML; skip them
  if (size < 4) {
    return 0;
  }

  if (!WriteInputToTempFile(data, size)) {
    return 0;
  }

  // ===== Simulate libWetCloth/App/Main.cpp::loadScene =====
  std::shared_ptr<ParticleSimulation> simulation;
  TwoDSceneXMLParser parser;

  Camera cam;
  scalar dt = 0.0;
  scalar max_time = 0.0;
  scalar steps_per_sec_cap = 100.0;

  // Default parameters matching Main.cpp
  renderingutils::Color bgcolor(1.0, 1.0, 1.0);
  std::string description;
  std::string scene_tag;
  bool cam_inited = false;

  const bool rendering_enabled = false; // Do not enter OpenGL branches
  const std::string input_bin;          // Do not restore from binary files

  try {
    parser.loadExecutableSimulation(
        std::string(kTmpScenePath),
        rendering_enabled,
        simulation,
        cam,
        dt,
        max_time,
        steps_per_sec_cap,
        bgcolor,
        description,
        scene_tag,
        cam_inited,
        input_bin);
  } catch (...) {
    // If the library throws an internal exception, swallow it to allow 
    // the fuzzer to continue with subsequent samples.
    // If you want exceptions to be treated as crashes, remove this try/catch.
    return 0;
  }

  if (!simulation) {
    return 0;
  }

  // Main.cpp calls finalInit() after loadScene; follow that here.
  simulation->finalInit();

  // ===== Run a few simulation steps =====
  // dt / max_time are read from XML; random input might result in 0 or NaN.
  if (!(dt > 0) || !std::isfinite(dt)) {
    // Return early to avoid division by zero; could also force a small dt to continue fuzzing.
    return 0;
  }

  int max_steps = 1;
  if (max_time > 0 && std::isfinite(max_time)) {
    double steps_d = std::ceil(static_cast<double>(max_time / dt));
    if (steps_d > 0.0) {
      // Limit the number of steps to avoid excessively slow calls
      if (steps_d > 4.0) {
        steps_d = 4.0;
      }
      max_steps = static_cast<int>(steps_d);
    }
  }

  for (int i = 0; i < max_steps; ++i) {
    simulation->stepSystem(dt);
  }

  return 0;
}
