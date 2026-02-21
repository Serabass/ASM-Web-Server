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
    cmp w2, #0x2068          /* "h " */
    b.ne try_add

    adr x1, response_health
    adr x2, response_health_end
    sub x2, x2, x1
    b send_response
try_add:
    ldr w2, [x1, #5]
    ldr w3, req_add_slash    /* "add/" */
    cmp w2, w3
    b.ne send_index
    add x1, x1, #9
    bl parse_uint_arm        /* x0 = first num, x1 = next ptr */
    mov x19, x0
    ldrb w2, [x1]
    cmp w2, #0x2F            /* '/' */
    b.ne send_index
    add x1, x1, #1
    bl parse_uint_arm        /* x0 = second num */
    add w0, w19, w0          /* sum */
    adr x1, add_body_buf
    bl uint_to_str_arm       /* x1 = buf, x2 = len */
    mov x20, x2              /* body_len */
    adr x21, add_response_buf
    adr x22, add_headers
    mov x23, #add_headers_len
copy_hdr:
    ldrb w24, [x22], #1
    strb w24, [x21], #1
    subs x23, x23, #1
    b.ne copy_hdr
    mov w0, w20
    mov x1, x21
    bl uint_to_str_arm       /* write Content-Length digits */
    add x21, x21, x2
    mov w24, #0x0a0d
    movk w24, #0x0a0d, lsl #16
    str w24, [x21], #4
    adr x22, add_body_buf
    mov x23, x20
copy_body:
    ldrb w24, [x22], #1
    strb w24, [x21], #1
    subs x23, x23, #1
    b.ne copy_body
    adr x1, add_response_buf
    sub x2, x21, x1
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

/* parse_uint_arm: x1 = ptr to digits, returns x0 = value, x1 = first non-digit */
parse_uint_arm:
    mov w0, #0
1:  ldrb w2, [x1]
    cmp w2, #0x30
    b.lt 2f
    cmp w2, #0x39
    b.hi 2f
    add w0, w0, w0, lsl #2   /* x0 *= 5 */
    add w0, w0, w0           /* x0 *= 2 => x0 *= 10 */
    sub w2, w2, #0x30
    add w0, w0, w2
    add x1, x1, #1
    b 1b
2:  ret

/* uint_to_str_arm: w0 = value, x1 = buffer; writes string, x2 = length */
uint_to_str_arm:
    mov w4, w0
    mov w9, #10
    cbz w4, u2s_zero
    add x5, x1, #15          /* write digits backwards */
    mov w6, #0
u2s_loop:
    udiv w7, w4, w9          /* quotient */
    msub w8, w7, w9, w4      /* remainder */
    add w8, w8, #0x30
    strb w8, [x5], #-1
    add w6, w6, #1
    mov w4, w7
    cbnz w4, u2s_loop
    add x5, x5, #1
    mov w2, w6
u2s_copy:
    ldrb w7, [x5], #1
    strb w7, [x1], #1
    subs w6, w6, #1
    b.ne u2s_copy
    ret
u2s_zero:
    mov w7, #0x30
    strb w7, [x1]
    mov x2, #1
    ret

exit_fail:
    mov x8, #93   /* exit */
    mov x0, #1
    svc #0

.section .data
.align 4
req_get_space:  .word 0x20544547   /* "GET " */
req_ealt:       .word 0x746c6165   /* "ealt" */
req_add_slash:  .word 0x2f646461   /* "add/" */

add_headers:
    .ascii "HTTP/1.1 200 OK\r\n"
    .ascii "Content-Type: text/plain\r\n"
    .ascii "Connection: close\r\n"
    .ascii "Content-Length: "
add_headers_end:
.equ add_headers_len, add_headers_end - add_headers

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
request_buf:     .space 512
add_body_buf:    .space 16
add_response_buf: .space 256
