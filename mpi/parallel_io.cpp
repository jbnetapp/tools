#include <mpi.h>
#include <iostream>
#include <vector>
#include <fstream>
#include <cstring>

#define FILENAME "./testfile.bin"

int main(int argc, char *argv[]) {
    MPI_Init(&argc, &argv);

    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    std::cout << "MPI[" << rank << "]: Processor rank: " << rank << " out of size:  " << size << std::endl;

    const int data_size = 100 * 1024 * 1024 ; // 100MB of integers per process
    std::vector<int> buffer(data_size, rank); // Initialize buffer with rank's ID


    MPI_File fh;
    MPI_Offset offset = rank * data_size * sizeof(int);

    // Open binary file for writing
    MPI_File_open(MPI_COMM_WORLD, FILENAME, MPI_MODE_CREATE | MPI_MODE_WRONLY, MPI_INFO_NULL, &fh);

    // Write data to file
    std::cout << "MPI[" << rank << "]: Start Parallel Write ! "  << std::endl;
    MPI_File_write_at(fh, offset, buffer.data(), data_size, MPI_INT, MPI_STATUS_IGNORE);

    MPI_File_close(&fh);

    std::cout << "MPI[" << rank << "]: Write completed ! "  << std::endl;

    // Reopen file for reading
    std::vector<int> read_buffer(data_size);
    MPI_File_open(MPI_COMM_WORLD, FILENAME, MPI_MODE_RDONLY, MPI_INFO_NULL, &fh);

    // Read back only this rank's portion
    std::cout << "MPI[" << rank << "]: Start Parallel Read ! "  << std::endl;
    MPI_File_read_at(fh, offset, read_buffer.data(), data_size, MPI_INT, MPI_STATUS_IGNORE);

    MPI_File_close(&fh);

    std::cout << "MPI[" << rank << "]: Write completed ! "  << std::endl;
    
    // Validate the read data
    bool valid = true;
    for (int i = 0; i < data_size; ++i) {
        if (read_buffer[i] != buffer[i]) {
            valid = false;
            break;
        }
    }

    if (!valid) {
        std::cerr << "Rank " << rank << ": Data validation failed!" << std::endl;
    } else if (rank == 0) {
        std::cout << "Data validation succeeded!" << std::endl;
    }

    MPI_Finalize();
    return 0;
}
