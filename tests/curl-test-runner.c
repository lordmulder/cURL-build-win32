/* cURL Test Runner, created by LoRd_MuldeR <mulder2@gmx.de>                      */
/*                                                                                */
/* Permission is hereby granted, free of charge, to any person obtaining a copy   */
/* of this software and associated documentation files (the "Software"), to deal  */
/* in the Software without restriction, including without limitation the rights   */
/* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell      */
/* copies of the Software, and to permit persons to whom the Software is          */
/* furnished to do so, subject to the following conditions:                       */
/*                                                                                */
/* The above copyright notice and this permission notice shall be included in all */
/* copies or substantial portions of the Software.                                */
/*                                                                                */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR     */
/* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,       */
/* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE    */
/* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER         */
/* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  */
/* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE  */
/* SOFTWARE.                                                                      */

#define WIN32_LEAN_AND_MEAN 1
#include <Windows.h>
#include <stdlib.h>
#include <stdio.h>
#include <limits.h>
#include <io.h>
#include <fcntl.h>

#define MAX_PATH_LENGTH 32768U
#define MAX_CMND_LENGTH 32768U

/* ========================================================================= */
/* Utility Functions                                                         */
/* ========================================================================= */

#define __MAKE_WIDESTR(str) L##str
#define MAKE_WIDESTR(str) __MAKE_WIDESTR(str)

#define IS_PATH_SEPARATOR(x) ({ const wchar_t _x = (x); (_x == L'\\') || (_x == L'/'); })
#define NO_PATH_SEPARATOR(x) (!IS_PATH_SEPARATOR(x))

static void remove_file_spec(wchar_t *const path)
{
	size_t len = wcslen(path);
	while ((len > 0U) && IS_PATH_SEPARATOR(path[len - 1U])) {
		path[--len] = L'\0';
	}
	while ((len > 0U) && NO_PATH_SEPARATOR(path[len - 1U])) {
		path[--len] = L'\0';
	}
	while ((len > 0U) && IS_PATH_SEPARATOR(path[len - 1U])) {
		path[--len] = L'\0';
	}
}

static BOOL get_executable_directory(wchar_t *const buffer, const size_t capacity)
{
	const DWORD length = GetModuleFileNameW(NULL, buffer, capacity);
	if ((length > 0U) && (length < capacity)) {
		remove_file_spec(buffer);
		return (*buffer) ? TRUE : FALSE;
	}

	return FALSE;
}

static HANDLE open_handle(const wchar_t *const path, const BOOL inhertitable)
{
	HANDLE handle_value;
	SECURITY_ATTRIBUTES secattr;

	if (inhertitable) {
		RtlZeroMemory(&secattr, sizeof(SECURITY_ATTRIBUTES));
		secattr.nLength = sizeof(secattr);
		secattr.bInheritHandle = TRUE;
	}

	if ((handle_value = CreateFileW(path, GENERIC_WRITE, 0, inhertitable ? &secattr : NULL, OPEN_EXISTING, 0, NULL)) == INVALID_HANDLE_VALUE) {
		return NULL;
	}

	return handle_value;
}

static HANDLE get_os_handle(FILE *const stream, const BOOL inhertitable)
{
	HANDLE new_handle;
	const HANDLE source_handle = (HANDLE)_get_osfhandle(_fileno(stream));
	if (source_handle == INVALID_HANDLE_VALUE) {
		return NULL;
	}

	if (DuplicateHandle(GetCurrentProcess(), source_handle, GetCurrentProcess(), &new_handle, 0, inhertitable, DUPLICATE_SAME_ACCESS)) {
		return new_handle;
	}

	return NULL;
}

static void trim_right(wchar_t *const str)
{
	size_t len = wcslen(str);
	while ((len > 0U) && (str[len - 1U] <= 0x20)) {
		str[--len] = L'\0';
	}
}

static void print_system_error(const wchar_t *const prefix, const DWORD error_code)
{
	WCHAR *message = NULL;
	if (FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM, NULL, error_code, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), (LPWSTR)&message, 0, NULL) > 0U) {
		trim_right(message);
		fwprintf(stderr, L"%ls: %ls\n", prefix, message);
		LocalFree(message);
	} else {
		fwprintf(stderr, L"%ls! [0x%04X]\n", prefix, error_code);
	}
}

/* ========================================================================= */
/* Start Sub-process                                                         */
/* ========================================================================= */

static BOOL create_process(const wchar_t *const exe_file, wchar_t *const cmd_line, const wchar_t *const work_dir, const HANDLE handle_out, const HANDLE handle_err, int *const exit_code)
{
	STARTUPINFOW startup_info;
	PROCESS_INFORMATION process_info;
	BOOL result = FALSE;

	RtlZeroMemory(&startup_info, sizeof(STARTUPINFOW));
	RtlZeroMemory(&process_info, sizeof(PROCESS_INFORMATION));

	startup_info.cb = sizeof(STARTUPINFOW);
	startup_info.dwFlags |= STARTF_USESTDHANDLES;
	startup_info.hStdOutput = handle_out;
	startup_info.hStdError  = handle_err;

	*exit_code = -1;

	if (CreateProcessW(exe_file, cmd_line, NULL, NULL, TRUE, 0, NULL, work_dir, &startup_info, &process_info)) {
		if (WaitForSingleObject(process_info.hProcess, INFINITE) == WAIT_OBJECT_0) {
			DWORD dw_exit;
			if ((result = GetExitCodeProcess(process_info.hProcess, &dw_exit))) {
				*exit_code = (int)dw_exit;
			} else {
				fputws(L"Failed to get the process exit code!\n", stderr);
			}
		} else {
			fputws(L"Failed to wait for process -> terminating now!\n", stderr);
			TerminateProcess(process_info.hProcess, 1U);
		}
		CloseHandle(process_info.hProcess);
		CloseHandle(process_info.hThread);
	} else {
		print_system_error(L"Failed to create process", GetLastError());
	}

	return result;
}

/* ========================================================================= */
/* Test Runner                                                               */
/* ========================================================================= */

static BOOL run_test(const wchar_t *const exe_file, const wchar_t *const work_dir, const HANDLE handle_out, const HANDLE handle_err, const wchar_t *const cmd_format, ...)
{
	wchar_t cmd_line[MAX_CMND_LENGTH];
	int result;
	va_list argptr;

	va_start(argptr, cmd_format);
	result = vsnwprintf(cmd_line, MAX_CMND_LENGTH, cmd_format, argptr);
	va_end(argptr);
	if (!((result > 0) && ((size_t)result < MAX_CMND_LENGTH))) {
		fwprintf(stderr, L"Error: Failed to create the command-line string!\n");
		return FALSE;
	}

	fwprintf(stderr, L"Command: %ls\n\n", cmd_line);
	fflush(stderr);

	if (!create_process(exe_file, cmd_line, work_dir, handle_out, handle_err, &result)) {
		fwprintf(stderr, L"\nError: Failed to create process!\n");
		return FALSE;
	}

	fputws(L"\n--------\n\n", stderr);

	if (result != 0) {
		fwprintf(stderr, L"Error: Process has exited with a non-zero exit code! [%lld]\n", result);
		return FALSE;
	}

	return TRUE;
}

/* ========================================================================= */
/* MAIN                                                                      */
/* ========================================================================= */

#define RUN_TEST(COMMAND, ...) run_test(exe_file, work_dir, null_device, console_out, COMMAND, __VA_ARGS__)

int wmain(void)
{
	WCHAR work_dir[MAX_PATH_LENGTH];
	WCHAR exe_file[MAX_PATH_LENGTH];
	HANDLE null_device;
	HANDLE console_out;
	int exit_code = EXIT_FAILURE;

	SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOOPENFILEERRORBOX);
	_setmode(_fileno(stderr), _O_U8TEXT);

	fwprintf(stderr, L"cURL Test Runner [%ls]\n\n", MAKE_WIDESTR(__DATE__));
	fflush(stderr);

	if (!get_executable_directory(work_dir, MAX_PATH_LENGTH)) {
		fwprintf(stderr, L"Error: Failed to detect working directory!\n");
		return EXIT_FAILURE;
	}

	int retval = snwprintf(exe_file, MAX_PATH_LENGTH, L"%ls\\curl.exe", work_dir);
	if (!((retval > 0) && ((size_t)retval < MAX_PATH_LENGTH))) {
		fwprintf(stderr, L"Error: Failed to build cURL executable path!\n");
		return EXIT_FAILURE;
	}

	if (GetFileAttributesW(exe_file) == INVALID_FILE_ATTRIBUTES) {
		fwprintf(stderr, L"Error: cURL executable file could not be found!\n");
		return EXIT_FAILURE;
	}

	if (!(null_device = open_handle(L"\\\\.\\NUL", TRUE))) {
		fwprintf(stderr, L"Error: Failed to open the `NUL` device!\n");
		return EXIT_FAILURE;
	}

	if (!(console_out = get_os_handle(stderr, TRUE))) {
		fwprintf(stderr, L"Error: Failed to retrieve the `stderr` handle!\n");
		return EXIT_FAILURE;
	}

	fwprintf(stderr, L"cURL executable:\n%ls\n\n", exe_file);
	fflush(stderr);

	/* cURL version */
	run_test(exe_file, work_dir, console_out, null_device, L"curl.exe --version");

	/* Unicode/IDN tests */
	{
		static const wchar_t *const HOST_NAMES[] = { L"www.b\u00fccher.de", L"www.caf\u00e9.com", L"\u0219coal\u0103.ro", L"\u0444\u0443\u0442\u0431\u043e\u043b.\u0440\u0444", L"\u03bf\u03c5\u03c4\u03bf\u03c0\u03af\u03b1.\u03b4\u03c0\u03b8.\u0067\u0072", L"www.\u2668\ufe0f.com" };
		for (size_t i = 0; i < ARRAYSIZE(HOST_NAMES); ++i) {
			if (!RUN_TEST(L"curl.exe -vf --no-progress-meter \"http://%ls/\"", HOST_NAMES[i])) {
				goto cleanup;
			}
		}
	}

	/* Protocol version tests */
	{
		static const wchar_t *const HOST_NAMES[] = { L"www.google.com", L"www.facebook.com" };
		static const wchar_t *const HTTP_VERSIONS[] = { L"1.1", L"2", L"3-only" }, *const TLS_VERSIONS[] = { L"1.1", L"1.2", L"1.3" };
		for (size_t i = 0; i < ARRAYSIZE(HOST_NAMES); ++i) {
			for (size_t j = 0; j < ARRAYSIZE(HTTP_VERSIONS); ++j) {
				for (size_t k = 0; k < ARRAYSIZE(TLS_VERSIONS); ++k) {
					if (!((j == 2) && (k < 2))) {
						if (!RUN_TEST(L"curl.exe -vf --no-progress-meter --tlsv%ls --tls-max %ls --http%ls \"https://%ls/\"", TLS_VERSIONS[k], TLS_VERSIONS[k], HTTP_VERSIONS[j], HOST_NAMES[i])) {
							goto cleanup;
						}
					}
				}
			}
		}
	}

	/* Download test */
	{
		static const wchar_t *const DOWNLOAD_URL = L"ftp.mozilla.org/pub/firefox/releases/128.9.0esr/win32/en-US/Firefox%20Setup%20128.9.0esr.exe";
		static const wchar_t *const PROTOCOLS[] = { L"http", L"https" };
		for (size_t i = 0; i < ARRAYSIZE(PROTOCOLS); ++i) {
			if (!RUN_TEST(L"curl.exe -vf -o - \"%ls://%ls\"", PROTOCOLS[i], DOWNLOAD_URL)) {
				goto cleanup;
			}
		}
	}

	fputws(L"All tests completed.\n", stderr);
	exit_code = EXIT_SUCCESS;

cleanup:

	CloseHandle(console_out);
	CloseHandle(null_device);

	return exit_code;
}
