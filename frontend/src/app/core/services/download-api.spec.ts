import { TestBed } from '@angular/core/testing';

import { DownloadApi } from './download-api';

describe('DownloadApi', () => {
  let service: DownloadApi;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(DownloadApi);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
