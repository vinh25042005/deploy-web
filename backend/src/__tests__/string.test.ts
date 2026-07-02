import { describe, it, expect } from '@jest/globals';

describe('String utils', () => {
  it('should concat strings', () => {
    expect('hello ' + 'world').toBe('hello world');
  });

  it('should get string length', () => {
    expect('techshop'.length).toBe(8);
  });
});
