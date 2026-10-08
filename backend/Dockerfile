FROM dart:stable

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN dart pub get --enforce-lockfile

COPY bin/ bin/
COPY lib/ lib/
COPY data/ data/
COPY images/ images/

RUN dart compile exe bin/server.dart -o /app/server

ENV PANORAMA_DATA_DIR=/app

EXPOSE 8080

CMD ["/app/server"]
