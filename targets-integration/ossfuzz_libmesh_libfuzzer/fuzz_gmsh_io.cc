#include <cstddef>
#include <cstdint>
#include <fstream>
#include <memory>
#include <string>

#include "libmesh/libmesh.h"   // libMesh::LibMeshInit, libMesh namespace
#include "libmesh/mesh.h"      // libMesh::Mesh
#include "libmesh/gmsh_io.h"   // libMesh::GmshIO

// Global initialization helper function inside an anonymous namespace
namespace {

libMesh::LibMeshInit & get_global_libmesh_init()
{
  // Use unique_ptr to ensure initialization happens exactly once 
  // and is correctly destructed at process termination.
  static std::unique_ptr<libMesh::LibMeshInit> init;

  if (!init)
  {
    int argc = 1;
    const char * argv[] = {"fuzz_gmsh_io", nullptr};

    // Corresponds to the libMeshInit constructor provided:
    // LibMeshInit(int argc, const char * const * argv, ...);
    init = std::make_unique<libMesh::LibMeshInit>(argc, argv);
  }

  return *init;
}

} // end anonymous namespace

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  // Ensure libMesh is initialized only once
  libMesh::LibMeshInit & init = get_global_libmesh_init();
  (void)init; // Avoid unused variable warning (used via init.comm() below)

  // Limit sample size to prevent extremely large inputs from degrading fuzzing performance
  if (size == 0 || size > (1u << 20)) // 1 MiB limit, adjustable as needed
    return 0;

  // Create a Mesh using the Communicator provided by LibMeshInit
  libMesh::Mesh mesh(init.comm());

  // Construct GmshIO using this mesh (gmsh_io.h includes this specific constructor)
  libMesh::GmshIO gmsh_io(mesh);

  // Write fuzz input to a temporary .msh file; GmshIO::read requires a filename
  const std::string filename = "fuzz_input.msh";

  {
    std::ofstream ofs(filename, std::ios::binary);
    if (!ofs)
      return 0;

    ofs.write(reinterpret_cast<const char *>(data),
              static_cast<std::streamsize>(size));
  }

  try
  {
    // Call the public interface for GmshIO:
    // virtual void read(const std::string &name) override;
    gmsh_io.read(filename);

    // Comments in gmsh_io.h state: the user is responsible for calling 
    // prepare_for_use() after read(). Calling it in the harness triggers 
    // additional Mesh-related logic, increasing code coverage.
    mesh.prepare_for_use();
  }
  catch (...)
  {
    // Catch all exceptions; actual bugs are identified by ASan/UBSan or crashes.
  }

  return 0;
}
