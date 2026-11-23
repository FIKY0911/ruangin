@echo off
setlocal
rem ============================================================
rem  Ruangin backend - one-click start (Windows + Laragon)
rem  1. MySQL Laragon   2. migrasi   3. data demo hari ini
rem  4. scheduler (peringatan dini)  5. server API di port 8000
rem ============================================================
cd /d "%~dp0"

set "PHP=C:\laragon\bin\php\php-8.2.28-nts-Win32-vs16-x64\php.exe"
set "MYSQLD=C:\laragon\bin\mysql\mysql-8.4.3-winx64\bin\mysqld.exe"
set "MYINI=C:\laragon\bin\mysql\mysql-8.4.3-winx64\my.ini"

if not exist "%PHP%" (
  echo [X] PHP Laragon tidak ditemukan: %PHP%
  echo     Ubah variabel PHP di file ini sesuai folder PHP di C:\laragon\bin\php
  pause & exit /b 1
)
if not exist vendor\autoload.php (
  echo [..] Install dependency composer...
  "%PHP%" C:\ProgramData\ComposerSetup\bin\composer.phar install --no-interaction || (pause & exit /b 1)
)

rem --- 1. MySQL -------------------------------------------------
powershell -NoProfile -Command "exit [int](-not (Test-NetConnection 127.0.0.1 -Port 3306 -WarningAction SilentlyContinue).TcpTestSucceeded)"
if errorlevel 1 (
  echo [..] Menyalakan MySQL Laragon...
  start "" /B "%MYSQLD%" --defaults-file="%MYINI%"
  powershell -NoProfile -Command "for($i=0;$i -lt 30;$i++){ if((Test-NetConnection 127.0.0.1 -Port 3306 -WarningAction SilentlyContinue).TcpTestSucceeded){exit 0}; Start-Sleep 1 }; exit 1"
  if errorlevel 1 ( echo [X] MySQL gagal menyala. Nyalakan lewat Laragon ^> Start All. & pause & exit /b 1 )
)
echo [OK] MySQL jalan di port 3306

rem --- 2. Migrasi -----------------------------------------------
"%PHP%" artisan config:clear >nul
"%PHP%" artisan migrate --force || (echo [X] Migrasi gagal. Cek DB_* di .env & pause & exit /b 1)

rem --- 3. Data demo ---------------------------------------------
"%PHP%" artisan ruangin:demo-status
if errorlevel 1 (
  echo.
  echo Data demo bukan untuk hari ini. Reset akan MENGHAPUS semua data Ruangin
  echo dan mengisi ulang data demo. Otomatis "Y" dalam 15 detik.
  choice /C YN /T 15 /D Y /M "Reset data demo sekarang"
  if not errorlevel 2 "%PHP%" artisan ruangin:reset-demo --force
)

rem --- 4. Scheduler (peringatan dini P11) ------------------------
start "Ruangin scheduler" /MIN "%PHP%" artisan schedule:work
echo [OK] Scheduler peringatan dini jalan (jendela terminimize)

rem --- 5. Server API --------------------------------------------
echo.
echo ============================================================
echo  API Ruangin:
echo    Browser / Flutter web : http://127.0.0.1:8000/api
echo    Emulator Android      : http://10.0.2.2:8000/api
echo    HP di WiFi yang sama  : http://^<IP laptop^>:8000/api  (cek: ipconfig)
echo  Akun demo (password ruangin123):
echo    nadia@demo.ruangin.id   mahasiswa
echo    raka@demo.ruangin.id    mahasiswa
echo    rina@demo.ruangin.id    dosen
echo    hendra@demo.ruangin.id  petugas akademik
echo  Tekan Ctrl+C untuk berhenti.
echo ============================================================
"%PHP%" artisan serve --host=0.0.0.0 --port=8000
