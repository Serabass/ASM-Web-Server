/* ARM64 Linux HTTP server. GAS. Routes: GET / and GET /health */
/* Syscalls: socket(198), bind(200), listen(201), accept(202), read(63), write(64), close(57) */

.section .text
.global _start

.equ SYS_socket,  198
.equ SYS_bind,    200
.equ SYS_listen,  201
.equ SYS_accept,  202
.equ SYS_read,    63
.equ SYS_write,   64
.equ SYS_close,   57

.equ AF_INET,     2
.equ SOCK_STREAM, 1
.equ PORT,        0x901F   /* 8080 network order */

_start:
    /* socket(AF_INET, SOCK_STREAM, 0) */
    mov x8, #SYS_socket
    mov x0, #AF_INET
    mov x1, #SOCK_STREAM
    mov x2, #0
    svc #0
    cmp x0, #0
    b.lt exit_fail
    adr x9, server_fd
    str x0, [x9]

    /* bind(server_fd, &sockaddr, 16) */
    mov x8, #SYS_bind
    ldr x0, [x9]
    adr x1, sockaddr
    mov x2, #16
    svc #0
    cmp x0, #0
    b.lt exit_fail

    /* listen(server_fd, 5) */
    mov x8, #SYS_listen
    ldr x0, [x9]
    mov x1, #5
    svc #0
    cmp x0, #0
    b.lt exit_fail

accept_loop:
    /* accept(server_fd, NULL, NULL) */
    mov x8, #SYS_accept
    ldr x0, [x9]
    mov x1, #0
    mov x2, #0
    svc #0
    cmp x0, #0
    b.lt accept_loop
    adr x10, client_fd
    str x0, [x10]

    /* read(client_fd, request_buf, 512) */
    mov x8, #SYS_read
    ldr x0, [x10]
    adr x1, request_buf
    mov x2, #512
    svc #0
    cmp x0, #0
    b.le close_client

    /* Route: "GET /health " -> health (same as x86: byte4='/', byte5='h', "ealt", "h ") */
    adr x1, request_buf
    ldr w2, [x1]
    ldr w3, req_get_space    /* "GET " */
    cmp w2, w3
    b.ne send_index
    ldrb w2, [x1, #4]
    cmp w2, #0x2F            /* '/' */
    b.ne send_index
    ldrb w2, [x1, #5]
    cmp w2, #0x68            /* 'h' */
    b.ne send_index
    ldr w2, [x1, #6]
    ldr w3, req_ealt         /* "ealt" */
    cmp w2, w3
    b.ne send_index
    ldrh w2, [x1, #10]
    cmp w2, #0x2068          /* "h " (byte10='h', byte11=' ') */
    b.ne send_index

    adr x1, response_health
    adr x2, response_health_end
    sub x2, x2, x1
    b send_response
send_index:
    adr x1, response_index
    adr x2, response_index_end
    sub x2, x2, x1
send_response:
    mov x8, #SYS_write
    ldr x0, [x10]
    svc #0

close_client:
    mov x8, #SYS_close
    ldr x0, [x10]
    svc #0
    b accept_loop

exit_fail:
    mov x8, #93   /* exit */
    mov x0, #1
    svc #0

.section .data
.align 4
req_get_space:  .word 0x20544547   /* "GET " */
req_ealt:       .word 0x746c6165   /* "ealt" (e,a,l,t) bytes 6-9 */

server_fd:  .quad 0
client_fd:  .quad 0

sockaddr:
    .hword AF_INET
    .hword PORT
    .word 0
    .quad 0

response_health:
    .ascii "HTTP/1.1 200 OK\r\n"
    .ascii "Content-Type: text/plain\r\n"
    .ascii "Content-Length: 2\r\n"
    .ascii "Connection: close\r\n"
    .ascii "\r\n"
    .ascii "OK"
response_health_end:

/* Static page from static/index.html, embedded at build (scripts/embed-static.sh) */
response_index:
    .incbin "response_index.bin"
response_index_end:
.equ response_index_len, response_index_end - response_index

.section .bss
.align 8
request_buf: .space 512
