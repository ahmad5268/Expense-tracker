import { GlobalExceptionFilter } from './http-exception.filter';
import { HttpException, HttpStatus, ArgumentsHost } from '@nestjs/common';

function mockHost(json: jest.Mock, url = '/test'): ArgumentsHost {
  return {
    switchToHttp: () => ({
      getResponse: () => ({ status: () => ({ json }) }),
      getRequest: () => ({ url }),
    }),
  } as unknown as ArgumentsHost;
}

describe('GlobalExceptionFilter', () => {
  let filter: GlobalExceptionFilter;

  beforeEach(() => {
    filter = new GlobalExceptionFilter();
  });

  it('maps HttpException to correct shape', () => {
    const json = jest.fn();
    filter.catch(new HttpException('Not found', HttpStatus.NOT_FOUND), mockHost(json));
    expect(json).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 404, error: expect.any(String), message: 'Not found', path: '/test' }),
    );
  });

  it('maps unknown errors to 500', () => {
    const json = jest.fn();
    filter.catch(new Error('boom'), mockHost(json));
    expect(json).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 500 }));
  });
});
