/* A Lua C module that calls only Mesen's public recording exports.
 * It neither reads nor changes emulated memory, registers, or input.
 * API: nesdev-org/MesenCE InteropDLL/RecordApiWrapper.cpp.
 */
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int32_t codec;
    uint32_t compression;
    unsigned char system_hud;
    unsigned char input_hud;
} RecordAviOptions;
typedef void (__stdcall *RecordFn)(char *, RecordAviOptions);
typedef void (__stdcall *StopFn)(void);
typedef unsigned char (__stdcall *IsRecordingFn)(void);

__declspec(dllexport) int luaopen_capture_start(void *lua_state) {
    (void)lua_state;
    HMODULE core = GetModuleHandleW(L"MesenCore.dll");
    const char *path = getenv("MARIO_IN_CAPTURE_AVI");
    RecordFn record = core ? (RecordFn)GetProcAddress(core, "AviRecord") : NULL;
    IsRecordingFn active = core ? (IsRecordingFn)GetProcAddress(core, "AviIsRecording") : NULL;
    if (!record || !active || !path || !*path) {
        fprintf(stderr, "CAPTURE ERROR: missing Mesen recording API or output path\n");
        return 0;
    }
    RecordAviOptions options = {1, 6, 0, 0}; /* Lossless ZMBV; game screen only. */
    record((char *)path, options);
    fprintf(stderr, "CAPTURE START: active=%d path=%s\n", active(), path);
    fflush(stderr);
    return 0;
}

__declspec(dllexport) int luaopen_capture_stop(void *lua_state) {
    (void)lua_state;
    HMODULE core = GetModuleHandleW(L"MesenCore.dll");
    StopFn stop = core ? (StopFn)GetProcAddress(core, "AviStop") : NULL;
    if (stop) {
        /* Allow the native writer's final pending frame to finish. */
        Sleep(30);
        stop();
        fprintf(stderr, "CAPTURE STOP\n");
        fflush(stderr);
    }
    return 0;
}

