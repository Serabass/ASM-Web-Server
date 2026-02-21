# ASM Web Service

Минимальный HTTP-сервер на ассемблере: без libc, только Linux syscalls. Один поток, блокирующий цикл accept. Собирается в статический бинарник, запускается в Docker-образе `scratch` и в Kubernetes.

## Что это

- **x86_64:** NASM, `main.asm` → `ld -static -nostdlib`.
- **ARM64:** GAS, `main.S` → `aarch64-linux-gnu-ld -static -nostdlib`.
- Статическая HTML-страница вшивается в бинарь при сборке; размеры бинарника/образа и ссылка на GitHub подставляются патчем в уже собранный файл.
- Финальный образ — только бинарь в `scratch` (без shell, без библиотек). Порт по умолчанию: **8080**.

## Маршруты

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/` | Главная страница (HTML с описанием проекта и демо «сложить два числа») |
| GET | `/health` | Тело `OK`, код 200 — для liveness/readiness в K8s |
| GET | `/add/X/Y` | Сумма двух целых чисел в пути; ответ — plain text |

## Сборка и запуск

### Локально (один образ)

```powershell
docker build -t asm-server:latest .
docker run --rm -p 8080:8080 asm-server:latest
```

Или через docker-compose:

```powershell
docker-compose up --build
```

Открой http://localhost:8080/ и http://localhost:8080/health .

### Multi-arch (buildx / bake)

Скрипт подставляет в образ URL репозитория из `git remote get-url origin`:

```powershell
.\scripts\build.ps1
```

Ручная передача URL:  
`docker buildx bake --set "asm-server.args.GITHUB_URL=$(git remote get-url origin)"`  
Обычная сборка под несколько платформ:  
`docker buildx build --platform linux/amd64,linux/arm64 -t asm-server:latest .`

## Kubernetes

```powershell
kubectl apply -f k8s/
```

В манифестах по умолчанию образ `asm-server:latest`. Подгрузи образ в кластер (например, `kind load docker-image asm-server:latest`) или пушь в свой registry и укажи `image:` в `k8s/deployment.yaml`. Пробы liveness/readiness используют `GET /health`.

## Как устроена сборка

1. **embed-static.sh** — читает `static/index.html`, формирует HTTP-ответ (заголовки + тело), пишет в `src/response_index.bin`. Content-Length считается по длине тела.
2. **NASM (x86_64)** или **GAS (ARM64)** собирают объектник; в него через `incbin` подключается `response_index.bin`.
3. **ld -static -nostdlib** линкует один исполняемый файл без динамического линкера (чтобы работал в `scratch`).
4. **patch_binary.sh** — в уже собранный бинарь подставляет: размер бинарника и образа в плейсхолдеры на странице, URL GitHub (80 символов), при необходимости Content-Length для индекса (если в бинаре остался плейсхолдер `0000`).

## Структура репозитория

| Путь | Назначение |
|------|------------|
| `src/main.asm` | Исходник x86_64 (NASM) |
| `src/main.S` | Исходник ARM64 (GAS) |
| `src/response_index.inc` | Подключение `response_index.bin` (генерируется embed) |
| `static/index.html` | HTML главной страницы (вшивается в бинарь) |
| `scripts/embed-static.sh` | Сборка HTTP-ответа для GET / в `response_index.bin` |
| `scripts/patch_binary.sh` | Патч бинарника: BINSIZE, IMGSIZE, GITHUB_URL, при необходимости Content-Length |
| `scripts/build.ps1` | Сборка через bake с подстановкой GITHUB_URL из git |
| `Dockerfile` | Multi-stage: builder (embed + asm + ld), artifact (patch), scratch (только /server) |
| `docker-bake.hcl` | bake: образы amd64/arm64, переменная GITHUB_URL, таргеты push |
| `docker-compose.yml` | Локальный запуск сервиса |
| `k8s/deployment.yaml`, `k8s/service.yaml` | Deployment и Service для K8s |
