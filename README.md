# Acorn POST code reader

Acorn ARM computers (e.g. A-series, R-series and RiscPC) have a POST code output port which outputs useful test diagnostic data during the boot process. Unfortunately, in order to read these codes, an Acorn/Atomwide "POST box". These boxes are extremely rare and hard to find.

This is a Verilog module which implements the Acorn POST Box / POST interface protocol and can display POST messages on an HD44780-based LCD.

In its current form, it will run on an FPGA Arcade DIP28 CPLD board (based on an Altera MAX7064S) and translate the POST protocol into a stream of clocked bytes for the LCD. A 2MHz external clock signal is required.
