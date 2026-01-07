import { TestBed } from '@angular/core/testing';

import { UploadApi } from './upload-api';

describe('UploadApi', () => {
  let service: UploadApi;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(UploadApi);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
