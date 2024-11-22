#include <mpi.h>
#include <random>
#include <vector>
#include <cstdlib>
#include <chrono>

int main(int argc, char* argv[]) {
    MPI_Init(&argc, &argv);

    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <size in MB>" << std::endl;
        MPI_Abort(MPI_COMM_WORLD, EXIT_FAILURE);
    }

    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    MPI_File file;
    MPI_File_open(MPI_COMM_WORLD, "random.dat", MPI_MODE_CREATE | MPI_MODE_WRONLY, MPI_INFO_NULL, &file);

    const long long totalSize = std::atoll(argv[1]) * 1024 * 1024; // Total size of the file in bytes
    const long long chunkSize = totalSize / size; // Size of the chunk that each process will write

    std::vector<char> data(chunkSize);
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(0, 255);
    std::cout << "MPI[" << rank << "]: Start Creating random char in memory " << chunkSize / 1024 / 1024 << " MB"  << std::endl;
    for (long long i = 0; i < chunkSize; ++i) {
        data[i] = static_cast<char>(dis(gen));
    }

    std::cout << "MPI[" << rank << "]: Start Parallel Write "  << std::endl;
    auto start = std::chrono::high_resolution_clock::now();
    MPI_File_write_at(file, rank * chunkSize, data.data(), chunkSize, MPI_CHAR, MPI_STATUS_IGNORE);
    auto stop = std::chrono::high_resolution_clock::now();

    MPI_File_close(&file);

    std::chrono::duration<double> duration = stop - start;
    double timeTakenSeconds = duration.count();
    double throughputMBps = (chunkSize / (1024.0 * 1024)) / timeTakenSeconds;

    std::cout << "MPI[" << rank << "]: Write completed Throughput " << throughputMBps << " MBps"  << std::endl;

    // Reopen the file for reading
    MPI_File_open(MPI_COMM_WORLD, "random.dat", MPI_MODE_RDONLY, MPI_INFO_NULL, &file);

    std::vector<char> readData(chunkSize);

    std::cout << "MPI[" << rank << "]: Start Parallel Read "  << std::endl;
    auto startRead = std::chrono::high_resolution_clock::now();
    MPI_File_read_at(file, rank * chunkSize, readData.data(), chunkSize, MPI_CHAR, MPI_STATUS_IGNORE);
    auto stopRead = std::chrono::high_resolution_clock::now();

    MPI_File_close(&file);

    std::chrono::duration<double> durationRead = stopRead - startRead;
    double timeTakenSecondsRead = durationRead.count();
    double throughputMBpsRead = (chunkSize / (1024.0 * 1024)) / timeTakenSecondsRead;

    std::cout << "MPI[" << rank << "]: Read completed Throughput " << throughputMBps << " MBps"  << std::endl;


    MPI_Finalize();

    return 0;
}

