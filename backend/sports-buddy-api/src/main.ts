import { randomUUID } from 'crypto';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NextFunction, Request, Response } from 'express';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    bufferLogs: true,
  });

  app.use((req: Request, res: Response, next: NextFunction) => {
    const requestId = randomUUID();
    const startedAt = Date.now();
    const { method, originalUrl } = req;

    req.headers['x-request-id'] = requestId;
    res.setHeader('x-request-id', requestId);

    res.on('finish', () => {
      const durationMs = Date.now() - startedAt;
      const statusCode = res.statusCode;
      const level =
        statusCode >= 500 ? 'error' : statusCode >= 400 ? 'warn' : 'log';

      const payload = {
        requestId,
        method,
        path: originalUrl,
        statusCode,
        durationMs,
      };

      const line = JSON.stringify(payload);
      if (level === 'error') {
        console.error(line);
      } else if (level === 'warn') {
        console.warn(line);
      } else {
        console.log(line);
      }
    });

    next();
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
  console.log(
    JSON.stringify({
      event: 'app_started',
      port,
      env: process.env.NODE_ENV ?? 'development',
    }),
  );
}
void bootstrap();
