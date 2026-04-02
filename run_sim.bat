@echo off
echo ===== COMPILING =====
iverilog -s tb_ringflasher -o simv tb_ringflasher.v ringflasher.v

if errorlevel 1 (
    echo Compile failed!
    pause
    exit /b
)

echo ===== RUNNING =====
vvp simv

echo ===== DONE =====
pause