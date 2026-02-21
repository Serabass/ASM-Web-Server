; Generated at build time: scripts/embed-static.sh writes response_index.bin
; This include expects response_index.bin in the same directory (created by embed step)
response_index:
    incbin "response_index.bin"
response_index_end:
response_index_len equ response_index_end - response_index
