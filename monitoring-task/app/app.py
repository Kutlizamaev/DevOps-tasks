import logging
import sys
import time

from flask import Flask, Response, jsonify, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, generate_latest

app = Flask(__name__)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s level=%(levelname)s message=%(message)s",
    stream=sys.stdout,
)

# Техническая метрика HTTP-запросов
http_requests_total = Counter(
    "http_requests_total",
    "Total number of HTTP requests",
    ["method", "endpoint", "status"],
)

# Бизнес-метрика:
# количество попыток сдачи комиссии по DevOps
devops_commission_submissions_total = Counter(
    "devops_commission_submissions_total",
    "Total number of DevOps commission submissions",
)


@app.after_request
def after_request(response):
    if request.path != "/metrics":
        http_requests_total.labels(
            method=request.method,
            endpoint=request.path,
            status=response.status_code,
        ).inc()

        logging.info(
            "http_request method=%s path=%s status=%s",
            request.method,
            request.path,
            response.status_code,
        )

    return response


@app.get("/")
def index():
    return """
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <title>DevOps Commission</title>

    <style>
        * {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background: #111827;
            color: #f9fafb;
            font-family: Arial, sans-serif;
        }

        .card {
            width: 520px;
            max-width: calc(100% - 40px);
            padding: 40px;
            background: #1f2937;
            border-radius: 18px;
            text-align: center;
            box-shadow: 0 20px 50px rgba(0, 0, 0, 0.35);
        }

        .icon {
            font-size: 56px;
            margin-bottom: 15px;
        }

        h1 {
            margin-bottom: 10px;
            font-size: 32px;
        }

        p {
            color: #d1d5db;
            line-height: 1.6;
        }

        button {
            margin-top: 20px;
            padding: 15px 28px;
            border: 0;
            border-radius: 10px;
            font-size: 17px;
            font-weight: bold;
            cursor: pointer;
            background: #22c55e;
            color: #ffffff;
        }

        button:hover {
            opacity: 0.9;
        }

        button:disabled {
            cursor: not-allowed;
            opacity: 0.6;
        }

        #result {
            min-height: 50px;
            margin-top: 25px;
            padding: 15px;
            border-radius: 10px;
        }

        .success {
            background: rgba(34, 197, 94, 0.15);
            color: #86efac;
        }

        .footer {
            margin-top: 25px;
            font-size: 13px;
            color: #9ca3af;
        }
    </style>
</head>

<body>

<div class="card">

    <div class="icon">⚙️</div>

    <h1>DevOps Commission</h1>

    <p>
        Демонстрационное приложение для сдачи комиссии
        по DevOps.
    </p>

    <p>
        Приложение работает в Kubernetes,
        а события собираются системой мониторинга.
    </p>

    <button id="submitButton" onclick="submitCommission()">
        Сдать комиссию по DevOps
    </button>

    <div id="result"></div>

    <div class="footer">
        Kubernetes • Prometheus • Loki • Grafana
    </div>

</div>

<script>
async function submitCommission() {

    const button = document.getElementById("submitButton");
    const result = document.getElementById("result");

    button.disabled = true;
    button.innerText = "Комиссия проверяется...";

    try {

        const response = await fetch("/commission", {
            method: "POST"
        });

        const data = await response.json();

        result.className = "success";

        result.innerHTML =
            "✅ <strong>Комиссия по DevOps успешно сдана!</strong><br><br>" +
            "Номер попытки: " + data.submission_id;

    } catch (error) {

        result.innerText = "Ошибка при отправке результата.";

    } finally {

        button.disabled = false;
        button.innerText = "Сдать комиссию ещё раз";
    }
}
</script>

</body>
</html>
"""


@app.post("/commission")
def submit_commission():

    submission_id = int(time.time() * 1000)

    # Увеличиваем бизнес-метрику
    devops_commission_submissions_total.inc()

    # Пишем бизнес-событие в stdout.
    # Позже этот лог будет собирать Loki.
    logging.info(
        "business_event event=devops_commission_submitted submission_id=%s result=passed",
        submission_id,
    )

    return jsonify(
        {
            "status": "passed",
            "submission_id": submission_id,
            "message": "DevOps commission successfully passed",
        }
    )


@app.get("/health")
def health():
    return jsonify(
        {
            "status": "ok",
        }
    )


@app.get("/metrics")
def metrics():
    return Response(
        generate_latest(),
        mimetype=CONTENT_TYPE_LATEST,
    )


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=8000,
    )
