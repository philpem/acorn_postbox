* Add PC interface port
  * FT245RL chip -- USB to FIFO.
  * If USB cable is connected then the FTDI controls data transfer over the POST link.
  * If USB cable is disconnected then INPUT always returns 0 and OUTPUT goes to the LCD.
* Design PCB with Kicad
  * EPM7000S series discontinued --
    * Lattice MachXO LCMXO256 -- 3.3V VCC, TQFP100 (78 I/Os)
    * Altera 5M80ZE645C5N (MAX V) alternate. Will need 3.3V power rail and level translation.
    * Atmel ATF1504AS as a backup option?
    * Lattice iCE40?
    * Xilinx XC9500XL?
* Test suites
  * Test i/o and LCD separately (test\_output is actually test\_lcd)
