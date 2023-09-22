section .data
    listen_port equ 8080 ; Порт, на котором сервер будет слушать
    www_root db "/var/www/html",0 ; Корневая директория веб-сервера

section .bss
    client_fd resd 1 ; Дескриптор файла для клиента
    request_buffer resb 1024 ; Буфер для HTTP-запроса

section .text
    global _start

_start:
    ; Создаем сокет
    mov eax, 1          ; sys_socket
    mov edi, 2          ; AF_INET (IPv4)
    mov esi, 1          ; SOCK_STREAM (TCP)
    mov edx, 0          ; Protocol (0 для автоматического выбора)
    syscall
    mov dword [client_fd], eax ; Сохраняем дескриптор сокса

    ; Привязываем сокет к IP и порту
    mov eax, 49         ; sys_bind
    mov edi, eax        ; Сохраняем дескриптор сокса в edi
    mov ecx, esp        ; Указатель на структуру sockaddr (с IP и портом)
    mov edx, 16         ; Длина структуры sockaddr
    syscall

    ; Начинаем слушать сокс
    mov eax, 50         ; sys_listen
    mov edi, eax        ; Передаем дескриптор сокса в edi
    mov esi, 5          ; Максимальное количество клиентов в очереди
    syscall

listen_loop:
    ; Принимаем входящее соединение
    mov eax, 51         ; sys_accept
    mov edi, eax        ; Передаем дескриптор сокса в edi
    mov ecx, esp        ; Указатель на структуру sockaddr (будет заполнено клиентским адресом)
    mov edx, esp + 16   ; Указатель на 4 байта для длины структуры sockaddr
    syscall

    ; Читаем HTTP-запрос от клиента
    mov eax, 0          ; sys_read
    mov edi, dword [client_fd]
    mov esi, request_buffer
    mov edx, 1024
    syscall

    ; Извлекаем URL-путь из HTTP-запроса
    mov ecx, esi        ; Указатель на начало буфера
    mov ebx, ecx
    add ebx, 5          ; Пропускаем "GET /"
    movzx edx, byte [ebx] ; Длина URL-пути
    inc ebx
    mov byte [ebx + edx], 0 ; Завершаем строку
    mov esi, ebx         ; Указатель на URL-путь

    ; Открываем запрошенный файл
    mov eax, 5          ; sys_open
    mov ebx, www_root   ; Корневая директория веб-сервера
    add ebx, esi        ; Добавляем URL-путь
    mov ecx, 0          ; Флаги (O_RDONLY)
    mov edx, 0          ; Режим доступа (не используется)
    syscall
    mov edi, eax        ; Сохраняем дескриптор файла

    ; Проверяем, удалось ли открыть файл
    cmp edi, -1
    je file_not_found

    ; Отправляем HTTP-заголовки
    mov eax, 4          ; sys_write
    mov edi, dword [client_fd]
    mov esi, http_ok    ; HTTP-ответ "200 OK"
    mov edx, http_ok_len
    syscall

    ; Отправляем содержимое файла
    send_file_contents:
    mov eax, 3          ; sys_read
    mov ebx, edi        ; Дескриптор файла
    mov esi, request_buffer ; Буфер для данных
    mov edx, 1024       ; Размер буфера
    syscall

    ; Проверяем, достигнут ли конец файла
    test eax, eax
    jz file_end

    ; Отправляем данные клиенту
    mov eax, 4          ; sys_write
    mov edi, dword [client_fd]
    mov edx, eax        ; Длина данных, считанных из файла
    syscall

    ; Повторяем чтение и отправку данных
    jmp send_file_contents

    file_end:
    ; Закрываем файл
    mov eax, 6          ; sys_close
    mov edi, dword [client_fd]
    syscall

    ; Возвращаемся к ожиданию новых соединений
    jmp listen_loop

file_not_found:
    ; Отправляем HTTP-ответ "404 Not Found"
    mov eax, 4          ; sys_write
    mov edi, dword [client_fd]
    mov esi, http_not_found
    mov edx, http_not_found_len
    syscall

    ; Закрываем сокс для клиента
    mov eax, 6          ; sys_close
    mov edi, dword [client_fd]
    syscall

    ; Возвращаемся к ожиданию новых соединений
    jmp listen_loop

section .data
    http_ok db "HTTP/1.1 200 OK",0x0a,"Content-Length: ",0 ; HTTP-ответ "200 OK"
    http_not_found db "HTTP/1.1 404 Not Found",0x0a,"Content-Length: 0",0 ; HTTP-ответ "404 Not Found"
    http_ok_len equ $ - http_ok
    http_not_found_len equ $ - http_not_found
