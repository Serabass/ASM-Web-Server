; x86_64 Linux HTTP server. NASM. No libc.
; Routes: GET / -> HTML index, GET /health -> "OK"
; Match "GET /" then "heal" (6-9) "th" (10-11) space (12)
; Syscalls: socket(41), bind(49), listen(50), accept(43), read(0), write(1), close(3)

BITS 64
global _start

; Linux x86_64 syscalls
%define SYS_socket  41
%define SYS_bind    49
%define SYS_listen  50
%define SYS_accept  43
%define SYS_read    0
%define SYS_write   1
%define SYS_close   3

%define AF_INET     2
%define SOCK_STREAM 1
%define PORT        0x901F          ; 8080 in network byte order

SECTION .text
_start:
    ; socket(AF_INET, SOCK_STREAM, 0)
    mov rax, SYS_socket
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    mov rdx, 0
    syscall
    cmp rax, 0
    jl exit_fail
    mov [server_fd], rax

    ; bind(server_fd, &addr, 16)
    mov rax, SYS_bind
    mov rdi, [server_fd]
    lea rsi, [sockaddr]
    mov rdx, 16
    syscall
    cmp rax, 0
    jl exit_fail

    ; listen(server_fd, 5)
    mov rax, SYS_listen
    mov rdi, [server_fd]
    mov rsi, 5
    syscall
    cmp rax, 0
    jl exit_fail

accept_loop:
    ; accept(server_fd, NULL, NULL)
    mov rax, SYS_accept
    mov rdi, [server_fd]
    xor rsi, rsi
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl accept_loop
    mov [client_fd], rax

    ; read(client_fd, buf, 512)
    mov rax, SYS_read
    mov rdi, [client_fd]
    lea rsi, [request_buf]
    mov rdx, 512
    syscall
    cmp rax, 0
    jle close_client

    ; Route: GET /health -> health; GET /add/X/Y -> sum; else -> index
    lea rdi, [request_buf]
    cmp dword [rdi], 0x20544547      ; "GET "
    jne send_index
    cmp byte [rdi+4], '/'            ; "/"
    jne send_index
    cmp byte [rdi+5], 'h'            ; "health"?
    jne try_add
    cmp dword [rdi+6], 0x746c6165   ; "ealt"
    jne send_index
    cmp word [rdi+10], 0x2068       ; "h "
    jne send_index
    mov rsi, response_health
    mov rdx, response_health_len
    jmp send_response
try_add:
    cmp dword [rdi+5], 0x2f646461   ; "add/" (bytes 5-8)
    jne send_index
    ; GET /add/X/Y - parse X at +9, Y after next /
    lea rsi, [rdi+9]
    call parse_uint
    mov rbx, rax                     ; first number
    cmp byte [rsi], '/'
    jne send_index
    inc rsi
    call parse_uint                  ; rax = second number
    add eax, ebx                     ; sum (assume 32-bit enough)
    lea rdi, [add_body_buf]
    call uint_to_str                 ; body at add_body_buf, length in rcx
    mov r8, rcx                      ; body_len
    ; Build response: header + Content-Length: <len> + "\r\n\r\n" + body
    lea rdi, [add_response_buf]
    lea rsi, [add_headers]
    mov rcx, add_headers_len
    rep movsb
    ; Convert r8 (body len 1-4) to ascii at rdi
    mov eax, r8d
    call uint_to_str                 ; writes at rdi, len in rcx
    add rdi, rcx
    mov dword [rdi], 0x0a0d0a0d     ; "\r\n\r\n"
    add rdi, 4
    lea rsi, [add_body_buf]
    mov rcx, r8
    rep movsb
    lea rsi, [add_response_buf]
    mov rdx, rdi
    sub rdx, rsi                    ; rdx = total response length
    jmp send_response
send_index:
    mov rsi, response_index
    mov rdx, response_index_len
send_response:
    mov rax, SYS_write
    mov rdi, [client_fd]
    syscall

close_client:
    mov rax, SYS_close
    mov rdi, [client_fd]
    syscall
    jmp accept_loop

; parse_uint: rsi = ptr to digit string, returns rax = value, rsi = first non-digit
parse_uint:
    xor eax, eax
.pu_loop:
    movzx ecx, byte [rsi]
    cmp cl, '0'
    jb .pu_done
    cmp cl, '9'
    ja .pu_done
    lea eax, [rax*4 + rax]
    add eax, eax
    sub ecx, '0'
    add eax, ecx
    inc rsi
    jmp .pu_loop
.pu_done:
    ret

; uint_to_str: eax = value, rdi = buffer, writes decimal string, returns rcx = length
uint_to_str:
    mov r9, rdi
    xor r10d, r10d
    test eax, eax
    jnz .uts_loop
    mov byte [rdi], '0'
    mov rcx, 1
    ret
.uts_loop:
    xor edx, edx
    mov ebx, 10
    div ebx
    add dl, '0'
    push rdx
    inc r10d
    test eax, eax
    jnz .uts_loop
    mov r11d, r10d
.uts_store:
    pop rdx
    mov [r9], dl
    inc r9
    dec r10d
    jnz .uts_store
    mov rcx, r11
    ret

exit_fail:
    mov rax, 60
    mov rdi, 1
    syscall

SECTION .data
align 4
server_fd:  dq 0
client_fd:  dq 0

; sockaddr_in: family=2, port=8080, addr=0
sockaddr:
    dw AF_INET
    dw PORT
    dd 0
    dq 0

response_health:
    db 'HTTP/1.1 200 OK', 13, 10
    db 'Content-Type: text/plain', 13, 10
    db 'Content-Length: 2', 13, 10
    db 'Connection: close', 13, 10
    db 13, 10
    db 'OK'
response_health_len equ $ - response_health

add_headers:
    db 'HTTP/1.1 200 OK', 13, 10
    db 'Content-Type: text/plain', 13, 10
    db 'Connection: close', 13, 10
    db 'Content-Length: '
add_headers_len equ $ - add_headers

; Static page from static/index.html, embedded at build time (see scripts/embed-static.sh)
%include "response_index.inc"

SECTION .bss
request_buf: resb 512
add_body_buf: resb 16
add_response_buf: resb 256
