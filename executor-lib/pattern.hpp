// executor-lib\pattern.hpp
// Signature scanner. Masks: 'x' must match, '?' skip.
#pragma once
#include <windows.h>
#include <cstdint>

namespace sig {

inline bool matchByte(uint8_t data, uint8_t sig, char mask)
{
    return mask == '?' || data == sig;
}

inline uint8_t* scan(uint8_t* start, size_t len,
                     const uint8_t* sig, const char* mask)
{
    size_t sigLen = lstrlenA(mask);
    if (sigLen == 0 || len < sigLen)
        return nullptr;

    for (size_t i = 0; i <= len - sigLen; ++i) {
        size_t j = 0;
        while (j < sigLen && matchByte(start[i + j], sig[j], mask[j]))
            ++j;
        if (j == sigLen)
            return start + i;
    }
    return nullptr;
}

inline uint8_t* moduleRange(HMODULE mod, size_t& outSize)
{
    auto dos = reinterpret_cast<PIMAGE_DOS_HEADER>(mod);
    if (dos->e_magic != IMAGE_DOS_SIGNATURE)
        return nullptr;
    auto nt = reinterpret_cast<PIMAGE_NT_HEADERS>(
        reinterpret_cast<uint8_t*>(mod) + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE)
        return nullptr;
    outSize = nt->OptionalHeader.SizeOfImage;
    return reinterpret_cast<uint8_t*>(mod);
}

} // namespace sig