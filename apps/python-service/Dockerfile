FROM python:3.12-slim AS builder

WORKDIR /app

RUN pip install --no-cache-dir --upgrade pip

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

COPY proto/greeter.proto .
RUN python -m grpc_tools.protoc \
      -I. \
      --python_out=. \
      --grpc_python_out=. \
      greeter.proto && \
    mv greeter_pb2.py greet_pb2.py && \
    mv greeter_pb2_grpc.py greet_pb2_grpc.py

FROM python:3.12-slim

WORKDIR /app

RUN useradd -r -u 1001 appuser
COPY --from=builder /install /usr/local
COPY --from=builder /app/greet_pb2.py /app/greet_pb2_grpc.py ./
COPY main.py .

USER appuser
EXPOSE 8000

ENTRYPOINT ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
