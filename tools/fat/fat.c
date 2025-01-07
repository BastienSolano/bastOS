#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef struct {
    uint8_t  BootJumpInstruction[3];
    uint8_t  OemIdentifier[8];
    uint16_t BytesPerSector;
    uint8_t  SectorsPerCluster;
    uint16_t ReservedSectors;
    uint8_t  FatCount;
    uint16_t DirEntryCount;
    uint16_t TotalSectors;
    uint8_t  MediaDescriptorType;
    uint16_t SectorsPerFat;
    uint16_t SectorsPerTrack;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectorCount;
    
    // extended boot record
    uint8_t  DriveNumber;
    uint8_t  _Reserved;
    uint8_t  Signature;
    uint32_t VolumeId; // serial number, value doesn't matter
    uint8_t  VolumeLabel[11]; // 11 bits, padded with spaces

    // we don't care about the code

} __attribute__((packed)) BootSector;

typedef struct {
    uint8_t Name[11];
    uint8_t Attributes;
    uint8_t _Reserved;
    uint8_t CreatedTimeTenths;
    uint16_t CreatedTime;
    uint16_t CreateDate;
    uint16_t AccessedDate;
    uint16_t FirstClusterHigh;
    uint16_t ModifiedTime;
    uint16_t ModifiedDate;
    uint16_t FirstClusterLow;
    uint32_t Size;
} __attribute__((packed)) DirectoryEntry;

BootSector g_BootSector;
uint8_t *g_Fat;
DirectoryEntry *g_RootDirectory = NULL;
uint32_t g_RootDirectoryEnd;

bool readBootSector(FILE* disk)
{
    return fread(&g_BootSector, sizeof(BootSector), 1, disk) > 0;
}

bool readSectors(FILE *disk, uint32_t lba, uint32_t count, void *oBuffer) {
    bool readOk = true;
    readOk = readOk && (fseek(disk, lba * g_BootSector.BytesPerSector, SEEK_SET) == 0);
    readOk = readOk && (fread(oBuffer, g_BootSector.BytesPerSector, count, disk) == count);
    return readOk;
}

bool readFat(FILE *disk) {
    // FAT = File Allocation Table
    g_Fat = (uint8_t *)malloc(g_BootSector.SectorsPerFat * g_BootSector.BytesPerSector);
    return readSectors(disk, g_BootSector.ReservedSectors, g_BootSector.SectorsPerFat, g_Fat);
}

bool readRootDirectory(FILE *disk) {
    uint32_t lba = g_BootSector.ReservedSectors + g_BootSector.SectorsPerFat * g_BootSector.FatCount;
    uint32_t size = sizeof(DirectoryEntry) * g_BootSector.DirEntryCount;
    uint32_t sectors = size / g_BootSector.BytesPerSector;
    if (size % g_BootSector.BytesPerSector > 0)
        sectors ++;

    g_RootDirectoryEnd = lba + sectors;
    g_RootDirectory = (DirectoryEntry *)malloc(sectors * g_BootSector.BytesPerSector);
    return readSectors(disk, lba, sectors, g_RootDirectory);
}

DirectoryEntry* findFile(const char* filename) {
    for (uint32_t i = 0; i < g_BootSector.DirEntryCount; ++i) {
        if (memcmp(filename, g_RootDirectory[i].Name, 11) == 0) {
             return &g_RootDirectory[i];
        }
    }
    return NULL;
}

bool readFile(DirectoryEntry* fileEntry, FILE* disk, uint8_t* outputBuffer) {
    bool ok = true;
    uint16_t currentCluster = fileEntry->FirstClusterLow;

    do {
        uint32_t lba = g_RootDirectoryEnd + (currentCluster - 2) * g_BootSector.SectorsPerCluster;
        ok = ok && readSectors(disk, lba, g_BootSector.SectorsPerCluster, outputBuffer);
        outputBuffer += g_BootSector.SectorsPerCluster * g_BootSector.BytesPerSector; // moving the output buffer pointer

        // look-up in the FAT to find the next cluster
        uint32_t fatIndex = currentCluster * 3 / 2;
        if (currentCluster % 2 == 0)
            currentCluster = (*(uint16_t*)(g_Fat + fatIndex)) & 0x0FFF;
        else
            currentCluster = (*(uint16_t*)(g_Fat + fatIndex)) >> 4;

    } while (ok && currentCluster < 0x0FF8);

    return ok;
}

void printFileContent(uint8_t* buffer, size_t length) {
     for (size_t i = 0; i < length; ++i) {
        if (isprint(buffer[i])) fputc(buffer[i], stdout);
        else printf("<%02x>", buffer[i]);
     }
}

int main(int argc, char **argv) {
    if (argc < 3) {
        printf("Usage: %s <disk image> <file name>\n", argv[0]);
        return -1;
    }

    FILE *disk = fopen(argv[1], "rb");
    if (!disk) {
        fprintf(stderr, "Cannot open disk image: %s\n", argv[1]);
        return -1;
    }

    if (!readBootSector(disk)) {
        fprintf(stderr, "Cannot read boot sector from disk image: %s\n", argv[1]);
        return -2;
    }

    if (!readFat(disk)) {
        fprintf(stderr, "Cannot read File Allocation Table from disk image: %s\n", argv[1]);
        free(g_Fat);
        return -3;
    }

    if (!readRootDirectory(disk)) {
        fprintf(stderr, "Cannot read Root Directory from disk image: %s\n", argv[1]);
        free(g_Fat);
        free(g_RootDirectory);
        return -4;
    }

    DirectoryEntry* fileEntry = findFile(argv[2]);
    if (fileEntry == NULL) {
        fprintf(stderr, "File %s not found on disk image %s\n", argv[2], argv[1]);
        free(g_Fat);
        free(g_RootDirectory);
        return -5;
    }

    uint8_t* buffer = (uint8_t*)malloc(fileEntry->Size + g_BootSector.BytesPerSector); // always allocating an extra sector to be safe
    if (!readFile(fileEntry, disk, buffer)) {
        fprintf(stderr, "Error while reading file %s on disk image %s\n", argv[2], argv[1]);
        free(g_Fat);
        free(g_RootDirectory);
        free(buffer);
        return -6;
    }
    printFileContent(buffer, fileEntry->Size);

    free(g_Fat);
    free(g_RootDirectory);
    free(buffer);
    return 0;
}
