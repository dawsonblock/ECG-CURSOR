## Boreal 2D Neuro-Core: Arty A7-100T Constraints (XDC)
## Target: xc7a100tcsg324-1

## Clock Signal (100MHz)
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## Reset (Active Low)
set_property -dict { PACKAGE_PIN C2    IOSTANDARD LVCMOS33 } [get_ports { rst_n }];

## Emergency Halt (Bite Switch on PMOD JB Pin 3)
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { emergency_halt_n }];

## UART TX (PMOD JB Pin 1 -> RP2040 RX)
set_property -dict { PACKAGE_PIN E15   IOSTANDARD LVCMOS33 } [get_ports { uart_tx }];

## ADS1299 SPI Interface (PMOD JA)
## Mapping to top_full ports (raw_adc_in logic)
## Note: Implementation expects external SPI controller to fill all_channels_data
set_property -dict { PACKAGE_PIN G13   IOSTANDARD LVCMOS33 } [get_ports { adc_data_ready }];
set_property -dict { PACKAGE_PIN B11   IOSTANDARD LVCMOS33 } [get_ports { adc_channel_sel[0] }];
set_property -dict { PACKAGE_PIN A11   IOSTANDARD LVCMOS33 } [get_ports { adc_channel_sel[1] }];
set_property -dict { PACKAGE_PIN D12   IOSTANDARD LVCMOS33 } [get_ports { adc_channel_sel[2] }];

## Safety Tiers (Switches)
set_property -dict { PACKAGE_PIN A8    IOSTANDARD LVCMOS33 } [get_ports { safety_tier[0] }];
set_property -dict { PACKAGE_PIN C11   IOSTANDARD LVCMOS33 } [get_ports { safety_tier[1] }];

## Debug LEDs
set_property -dict { PACKAGE_PIN H5    IOSTANDARD LVCMOS33 } [get_ports { noise_freeze_led }];
