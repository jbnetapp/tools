#include <mpi.h>
#include <string>
#include <random>
#include <vector>
#include <cstdlib>
#include <chrono>

// version beta 5
//

int main(int argc, char* argv[]) {
    MPI_Init(&argc, &argv);

    int nodeID ;
    int fileSizeMB ;
    int numIterations = 1 ;
    int counter = 0 ; 
    const char* filename ;
    const char* filenameArg ;
    std::string version = "beta 5" ;
    std::string Usage = "Usage:" + std::string(argv[0]) + " <node_ID> <sizeMB> [numIterations] [filename]";

    if (argc < 4) {
        std::cerr << Usage  << std::endl;
	MPI_Abort(MPI_COMM_WORLD, EXIT_FAILURE);
    } else {
    	try {
        	nodeID = std::stoi(argv[1]);
        	fileSizeMB = std::stoi(argv[2]);
        	numIterations = std::stoi(argv[3]);
    	} 
    	catch (std::invalid_argument const &e) {
        	//std::cerr << "Error: " << argv[1] << " is not a valid integer." << std::endl;
                std::cerr << Usage  << std::endl;
		MPI_Abort(MPI_COMM_WORLD, EXIT_FAILURE);
    	} 
    	catch (std::out_of_range const &e) {
        	//std::cerr << "Error: " << argv[1] << " is too large to be represented as an integer.\n" << std::endl;
                std::cerr << Usage  << std::endl;
		MPI_Abort(MPI_COMM_WORLD, EXIT_FAILURE);
    	}
    }

    if (argc == 5){
	    filenameArg = argv[4] ;
    } else {
	    filenameArg = "random.dat" ;
    }

    filename = filenameArg + "." + std::to_string(nodeID) + std::to_string(rank) ; 

    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    MPI_File file;

    const long long totalSize = std::atoll(argv[2]) * 1024 * 1024; // Total size of the file in bytes
    const long long chunkSize = totalSize / size; // Size of the chunk that each process will write

    std::cout << "MPI[" << nodeID << "][" << rank << "]: version: " << version  << std::endl;
    std::cout << "MPI[" << nodeID << "][" << rank << "]: Start Creating random char in memory " << chunkSize / 1024 / 1024 << " MB"  << std::endl;
    std::vector<char> data(chunkSize);
    std::random_device rd;
    std::mt19937 gen(rd());

    auto memStart = std::chrono::high_resolution_clock::now();
    std::uniform_int_distribution<> dis(0, 255);
    for (long long i = 0; i < chunkSize; ++i) {
        data[i] = static_cast<char>(dis(gen));
    }
    
    MPI_Barrier(MPI_COMM_WORLD);

    auto memStop = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> duration = memStop - memStart;
    double timeTakenSeconds = duration.count();
    if (rank == 0 ) {
        std::cout << "MPI[" << nodeID << "][" << rank << "]: memory chunk build duration [" << timeTakenSeconds << "]"  << std::endl;
    }

    auto loopStart = std::chrono::high_resolution_clock::now();
    for (int i = 0 ; i < numIterations ; i++ ) {
	counter++;
    	// open the file for writing 
        MPI_File_open(MPI_COMM_WORLD, filename , MPI_MODE_CREATE | MPI_MODE_WRONLY, MPI_INFO_NULL, &file);

    	std::cout << "MPI[" << nodeID << "][" << rank << "]: Start Parallel Write in [" << filename << "] iteration [" << counter << "]"  << std::endl;
    	auto start = std::chrono::high_resolution_clock::now();
    	MPI_File_write_at(file, ((nodeID * chunkSize * size) + (rank * chunkSize)), data.data(), chunkSize, MPI_CHAR, MPI_STATUS_IGNORE);
    	auto stop = std::chrono::high_resolution_clock::now();

    	MPI_File_close(&file);

    	std::chrono::duration<double> duration = stop - start;
    	double timeTakenSeconds = duration.count();
    	double throughputMBps = (chunkSize / (1024.0 * 1024)) / timeTakenSeconds;

    	std::cout << "MPI[" << nodeID << "][" << rank << "]: Write completed Throughput " << throughputMBps << " MBps"  << std::endl;
    
        MPI_Barrier(MPI_COMM_WORLD);

    	// Reopen the file for reading
    	MPI_File_open(MPI_COMM_WORLD, filename, MPI_MODE_RDONLY, MPI_INFO_NULL, &file);

    	std::cout << "MPI[" << nodeID << "][" << rank << "]: Start Parallel Read in [" << filename << "] iteration [" << counter << "]"  << std::endl;
    	auto startRead = std::chrono::high_resolution_clock::now();
    	MPI_File_read_at(file, ((nodeID * chunkSize * size) + (rank * chunkSize)), data.data(), chunkSize, MPI_CHAR, MPI_STATUS_IGNORE);
    	auto stopRead = std::chrono::high_resolution_clock::now();

    	MPI_File_close(&file);

    	std::chrono::duration<double> durationRead = stopRead - startRead;
    	double timeTakenSecondsRead = durationRead.count();
    	double throughputMBpsRead = (chunkSize / (1024.0 * 1024)) / timeTakenSecondsRead;

    	std::cout << "MPI[" << nodeID << "][" << rank << "]: Read completed Throughput " << throughputMBps << " MBps"  << std::endl;
	
    } 
    
    MPI_Barrier(MPI_COMM_WORLD);

    auto loopStop = std::chrono::high_resolution_clock::now();
    duration = loopStop - loopStart;
    timeTakenSeconds = duration.count();
    if (rank == 0 ) {
        std::cout << "MPI[" << nodeID << "][" << rank << "]: MPI IO duration [" << timeTakenSeconds << "]"  << std::endl;
    }

    MPI_Finalize();

    return 0;
}
