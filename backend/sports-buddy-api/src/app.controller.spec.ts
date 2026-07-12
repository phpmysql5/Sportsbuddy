import { Test, TestingModule } from '@nestjs/testing';
import { AppController } from './app.controller';

describe('AppController', () => {
  let appController: AppController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [],
    }).compile();

    appController = app.get<AppController>(AppController);
  });

  describe('health', () => {
    it('should return status ok', () => {
      expect(appController.getHealth()).toEqual({ status: 'ok' });
    });
  });

  describe('meta', () => {
    it('should return supported cities', () => {
      expect(appController.getSupportedCities()).toEqual({
        cities: [
          'Mangalore',
          'Bengaluru',
          'Mumbai',
          'Delhi',
          'Hyderabad',
          'Chennai',
        ],
      });
    });

    it('should return supported sports', () => {
      expect(appController.getSupportedSports()).toEqual({
        sports: [
          'Tennis',
          'Badminton',
          'Cricket',
          'Football',
          'Basketball',
          'Pickleball',
        ],
      });
    });
  });
});
