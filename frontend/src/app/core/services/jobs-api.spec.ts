import { TestBed } from '@angular/core/testing';

import { JobsApi } from './jobs-api';

describe('JobsApi', () => {
  let service: JobsApi;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(JobsApi);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
