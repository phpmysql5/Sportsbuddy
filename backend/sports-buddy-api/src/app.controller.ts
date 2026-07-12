import { Controller, Get } from '@nestjs/common';
import { SUPPORTED_CITIES } from './common/supported-cities';
import { SUPPORTED_SPORTS } from './common/supported-sports';

@Controller()
export class AppController {
  @Get('health')
  getHealth(): { status: string } {
    return { status: 'ok' };
  }

  @Get('meta/supported-cities')
  getSupportedCities(): { cities: string[] } {
    return { cities: [...SUPPORTED_CITIES] };
  }

  @Get('meta/supported-sports')
  getSupportedSports(): { sports: string[] } {
    return { sports: [...SUPPORTED_SPORTS] };
  }
}
