#include <mpi.h>
#include <string>
#include <random>
#include <vector>
#include <cstdlib>
#include <chrono>


int main(int argc, char* argv[]) {
    MPI_Init(&argc, &argv);

    int nodeID ;

    if (argc != 3) {
        std::cerr << "Usage: " << argv[0] << " <Node_ID> <size in MB>"  << std::endl;
        MPI_Abort(MPI_COMM_WORLD, EXIT_FAILURE);
    } else {
    	try {
        	nodeID = std::stoi(argv[1]);
    	} 
    	catch (std::invalid_argument const &e) {
        	std::cerr << "Error: " << argv[1] << " is not a valid integer." << std::endl;
        	MPI_Abort(MPI_COMM_WORLD, EXIT_FAILURE);
    	} 
    	catch (std::out_of_range const &e) {
        	std::cerr << "Error: " << argv[1] << " is too large to be represented as an integer." << std::endl;
        	MPI_Abort(MPI_COMM_WORLD, EXIT_FAILURE);
    	}
    }

    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    MPI_File file;
    MPI_File_open(MPI_COMM_WORLD, "random.dat", MPI_MODE_CREATE | MPI_MODE_WRONLY, MPI_INFO_NULL, &file);

    const long long totalSize = std::atoll(argv[2]) * 1024 * 1024; // Total size of the file in bytes
    const long long chunkSize = totalSize / size; // Size of the chunk that each process will write

    std::cout << "MPI[" << nodeID << "][" << rank << "]: Start Creating random char in memory " << chunkSize / 1024 / 1024 << " MB"  << std::endl;
    std::vector<char> data(chunkSize);
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(0, 255);
    for (long long i = 0; i < chunkSize; ++i) {
        data[i] = static_cast<char>(dis(gen));
    }

    std::cout << "MPI[" << nodeID << "][" << rank << "]: Start Parallel Write "  << std::endl;
    auto start = std::chrono::high_resolution_clock::now();
    MPI_File_write_at(file, ((nodeID * chunkSize * size) + (rank * chunkSize)), data.data(), chunkSize, MPI_CHAR, MPI_STATUS_IGNORE);
    auto stop = std::chrono::high_resolution_clock::now();

    MPI_File_close(&file);

    std::chrono::duration<double> duration = stop - start;
    double timeTakenSeconds = duration.count();
    double throughputMBps = (chunkSize / (1024.0 * 1024)) / timeTakenSeconds;

    std::cout << "MPI[" << nodeID << "][" << rank << "]: Write completed Throughput " << throughputMBps << " MBps"  << std::endl;

    // Reopen the file for reading
    MPI_File_open(MPI_COMM_WORLD, "random.dat", MPI_MODE_RDONLY, MPI_INFO_NULL, &file);

    std::vector<char> readData(chunkSize);

    std::cout << "MPI[" << nodeID << "][" << rank << "]: Start Parallel Read "  << std::endl;
    auto startRead = std::chrono::high_resolution_clock::now();
    MPI_File_read_at(file, ((nodeID * chunkSize * size) + (rank * chunkSize)), readData.data(), chunkSize, MPI_CHAR, MPI_STATUS_IGNORE);
    auto stopRead = std::chrono::high_resolution_clock::now();

    MPI_File_close(&file);

    std::chrono::duration<double> durationRead = stopRead - startRead;
    double timeTakenSecondsRead = durationRead.count();
    double throughputMBpsRead = (chunkSize / (1024.0 * 1024)) / timeTakenSecondsRead;

    std::cout << "MPI[" << nodeID << "][" << rank << "]: Read completed Throughput " << throughputMBps << " MBps"  << std::endl;


    MPI_Finalize();

    return 0;
}
