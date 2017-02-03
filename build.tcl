add_files {src/alignment_detect.vhd}
add_files {src/audio_meters.vhd}
add_files {src/audio_to_db.vhd}
add_files {src/conversion_to_RGB.vhd}
add_files {src/deserialiser_1_to_10.vhd}
add_files {src/detect_interlace.vhd}
add_files {src/dvid_output.vhd}
add_files {src/edge_enhance.vhd}
add_files {src/edid_rom.vhd}
add_files {src/expand_422_to_444.vhd}
add_files {src/extract_audio_samples.vhd}
add_files {src/extract_video_infopacket_data.vhd}
add_files {src/guidelines.vhd}
add_files {src/hdmi_design.vhd}
add_files {src/hdmi_input.vhd}
add_files {src/hdmi_io.vhd}
add_files {src/input_channel.vhd}
add_files {src/line_delay.vhd}
add_files {src/pixel_processing.vhd}
add_files {src/serialiser_10_to_1.vhd}
add_files {src/symbol_dump.vhd}
add_files {src/tmds_decoder.vhd}
add_files {src/tmds_encoder.vhd}

read_xdc constraints/NexysVideo.xdc
synth_design -top hdmi_design -part xc7a200tfbg484-1 -include_dirs {}
report_utilization -hierarchical -file top_utilization_hierarchical_synth.rpt
report_utilization -file top_utilization_synth.rpt
place_design
report_utilization -hierarchical -file top_utilization_hierarchical_place.rpt
report_utilization -file top_utilization_place.rpt
report_io -file top_io.rpt
report_control_sets -verbose -file top_control_sets.rpt
report_clock_utilization -file top_clock_utilization.rpt
route_design
report_route_status -file top_route_status.rpt
report_drc -file top_drc.rpt
report_timing_summary -datasheet -max_paths 10 -file top_timing.rpt
report_power -file top_power.rpt
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
write_bitstream -force top.bit
write_cfgmem -force -format bin -interface spix4 -size 16 -loadbit "up 0x0 top.bit" -file top.bin
quit