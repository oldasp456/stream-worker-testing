@echo off
setlocal
cd /d "%~dp0"

REM Single-file launcher: start Tor on 127.0.0.1:9050, then vote in a loop.
set "TOR_EXE=%USERPROFILE%\Desktop\Tor Browser\Browser\TorBrowser\Tor\tor.exe"
set "TOR_DATA=%USERPROFILE%\Desktop\Tor Browser\Browser\TorBrowser\Data\Tor"
set "POLL_TIMEOUT=45000"

where node >nul 2>&1
if errorlevel 1 (
  echo [error] node is not in PATH
  exit /b 1
)
if not exist "%TOR_EXE%" (
  echo [error] tor.exe not found at "%TOR_EXE%"
  exit /b 1
)

:loop
call :ensure_tor
echo.
echo [%TIME%] voting: Shathiga --tor-streams 12 --target 500 --times 2000
node worker.mjs Shathiga --tor-streams 12 --target 500 --times 2000 --tally-each
echo [%TIME%] cycle finished; restarting in 3s ^(Ctrl+C to stop^)
ping -n 4 127.0.0.1 >nul
goto loop

:ensure_tor
REM TCP probe via node: netstat on this box can stall for minutes.
node -e "const s=require('net').connect(9050,'127.0.0.1');s.on('connect',()=>{s.destroy();process.exit(0)});s.on('error',()=>process.exit(1));setTimeout(()=>process.exit(1),1000)" >nul 2>&1
if not errorlevel 1 exit /b 0

echo [Tor] starting on 127.0.0.1:9050...
start /b "" "%TOR_EXE%" --SocksPort 9050 --DataDirectory "%~dp0.tor" --GeoIPFile "%TOR_DATA%\geoip" --GeoIPv6File "%TOR_DATA%\geoip6"

:wait_port
node -e "const s=require('net').connect(9050,'127.0.0.1');s.on('connect',()=>{s.destroy();process.exit(0)});s.on('error',()=>process.exit(1));setTimeout(()=>process.exit(1),1000)" >nul 2>&1
if errorlevel 1 (
  ping -n 2 127.0.0.1 >nul
  goto wait_port
)
echo [Tor] listening; waiting for bootstrap...

where curl >nul 2>&1
if errorlevel 1 (
  echo [Tor] curl not found; waiting 40s for bootstrap
  ping -n 41 127.0.0.1 >nul
  exit /b 0
)

:wait_boot
curl -s --max-time 60 --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip | findstr /i "IsTor" >nul
if errorlevel 1 (
  ping -n 3 127.0.0.1 >nul
  goto wait_boot
)
echo [Tor] ready.
exit /b 0
