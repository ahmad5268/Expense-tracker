import { TransformInterceptor } from './transform.interceptor';
import { of } from 'rxjs';
import { ExecutionContext, CallHandler } from '@nestjs/common';

const mockContext = {} as ExecutionContext;

describe('TransformInterceptor', () => {
  it('wraps response in { data }', (done) => {
    const interceptor = new TransformInterceptor();
    const handler: CallHandler = { handle: () => of({ id: '1' }) };
    interceptor.intercept(mockContext, handler).subscribe((result) => {
      expect(result).toEqual({ data: { id: '1' } });
      done();
    });
  });
});
