# DevOps Commission Monitoring

Учебный проект по контейнеризации, Kubernetes и мониторингу.

Приложение представляет собой веб-страницу для демонстрационной сдачи комиссии по DevOps.

При нажатии кнопки:

`Сдать комиссию по DevOps`

приложение создаёт бизнес-событие, увеличивает Prometheus-метрику и записывает событие в stdout.

## Используемые технологии

- Docker
- Minikube
- Kubernetes
- Flask
- Gunicorn
- Prometheus
- Loki
- Promtail
- Grafana

## Архитектура

```text
                       ┌──────────────┐
                       │    User      │
                       └──────┬───────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │ Monitoring App   │
                    │ Flask + Gunicorn │
                    └───────┬──────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
          /metrics                     stdout
              │                           │
              ▼                           ▼
        ┌────────────┐              ┌──────────┐
        │ Prometheus │              │ Promtail │
        └──────┬─────┘              └────┬─────┘
               │                         │
               │                         ▼
               │                     ┌──────┐
               │                     │ Loki │
               │                     └──┬───┘
               │                        │
               └──────────┬─────────────┘
                          ▼
                     ┌─────────┐
                     │ Grafana │
                     └─────────┘
```

## Namespace

Все ресурсы приложения размещаются в Kubernetes namespace:

```text
fanil20261005
```

## Приложение

Приложение предоставляет следующие endpoint:

```text
GET  /
POST /commission
GET  /health
GET  /metrics
```

`POST /commission` имитирует успешную сдачу комиссии по DevOps.

Пример ответа:

```json
{
  "message": "DevOps commission successfully passed",
  "status": "passed",
  "submission_id": 1791239074616
}
```

## Бизнес-метрика

Приложение экспортирует Prometheus-метрику:

```text
devops_commission_submissions_total
```

Метрика показывает общее количество сдач комиссии по DevOps.

При каждом запросе:

```text
POST /commission
```

значение метрики увеличивается на единицу.

## Централизованные логи

Приложение пишет бизнес-события в stdout.

Пример:

```text
business_event event=devops_commission_submitted submission_id=1791239074616 result=passed
```

Promtail собирает логи Kubernetes Pod и передаёт их в Loki.

Grafana получает логи из Loki.

## Grafana

Grafana использует два datasource:

```text
Prometheus
Loki
```

Dashboard:

```text
DevOps Commission Monitoring
```

содержит:

- общее количество сдач комиссии;
- график изменения бизнес-метрики;
- централизованные логи сдачи комиссии.

Конфигурация dashboard хранится в:

```text
grafana/devops-commission-dashboard.json
```

## Docker image

Приложение собирается с помощью multi-stage Dockerfile.

Первая стадия создаёт Python wheels с зависимостями.

Вторая стадия содержит только runtime приложения и необходимые зависимости.

Приложение запускается не от root-пользователя.

## Сборка приложения

Для сборки используется:

```bash
./scripts/build.sh -t v1
```

Параметр:

```text
-t
```

задаёт Docker image tag.

В результате создаётся образ:

```text
fanil-monitoring-app:v1
```

После сборки образ автоматически загружается в Minikube.

## Развёртывание

Для полного развёртывания используется:

```bash
./scripts/deploy.sh -t v1
```

Скрипт разворачивает:

```text
Monitoring App
Prometheus
Loki
Promtail
Grafana
```

## Запуск Minikube

Пример запуска локального Kubernetes-кластера:

```bash
minikube start \
  --driver=docker \
  --cpus=2 \
  --memory=4096
```

Проверка:

```bash
minikube status
kubectl get nodes
```

Kubernetes node должен иметь состояние:

```text
Ready
```

## Проверка Kubernetes

```bash
kubectl get pods -n fanil20261005
```

В работающем окружении должны присутствовать:

```text
monitoring-app
prometheus
loki
promtail
grafana
```

Для просмотра сервисов:

```bash
kubectl get services -n fanil20261005
```

## Доступ к приложению

```bash
kubectl port-forward \
  -n fanil20261005 \
  service/monitoring-app \
  8081:80
```

После этого:

```text
http://localhost:8081
```

## Доступ к Prometheus

```bash
kubectl port-forward \
  -n fanil20261005 \
  service/prometheus \
  9090:9090
```

Адрес:

```text
http://localhost:9090
```

Проверка бизнес-метрики:

```promql
devops_commission_submissions_total
```

## Доступ к Loki

```bash
kubectl port-forward \
  -n fanil20261005 \
  service/loki \
  3100:3100
```

Проверка:

```bash
curl http://localhost:3100/ready
```

## Доступ к Grafana

```bash
kubectl port-forward \
  -n fanil20261005 \
  service/grafana \
  3000:3000
```

Grafana:

```text
http://localhost:3000
```

Данные для входа:

```text
Login: admin
Password: admin
```

Dashboard:

```text
DevOps
→ DevOps Commission Monitoring
```

## Проверка логов

Loki-запрос:

```logql
{job="kubernetes-pods", filename=~".*monitoring-app.*"}
|= "business_event event=devops_commission_submitted"
```

## Результат

В результате реализовано контейнеризированное веб-приложение, развёрнутое в Minikube.

Prometheus собирает бизнес-метрику приложения.

Promtail централизованно собирает Kubernetes-логи и передаёт их в Loki.

Grafana отображает метрики Prometheus и логи Loki на одном dashboard.
