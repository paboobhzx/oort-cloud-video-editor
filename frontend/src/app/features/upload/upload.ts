import { Component, OnInit, ChangeDetectorRef, output } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { environment } from '../../../environments/environment';
import { Auth } from '../../core/auth/auth';

interface UploadResponse {
  upload_url: string;
  key: string;
  preview_url: string;
}



interface JobResponse {
  job_id: string;
  output_key: string;
}

interface StatusResponse {
  status: 'processing' | 'completed' | 'failed';
  download_url?: string;
  error?: string;
}

@Component({
  selector: 'app-upload',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
  <h1>Video Upload & Processing</h1>

    <div class="container">
      <h1>Video Upload & Processing</h1>

      <!-- Step 1: Upload Video -->
      <section *ngIf="!uploadedKey">
        <h2>Step 1: Upload Video</h2>

        <input type="file" accept="video/*" (change)="onFileSelected($event)" [disabled]="isUploading" />
        <p *ngIf="selectedFile">
          📁 {{ selectedFile.name }} ({{ (selectedFile.size / 1024 / 1024).toFixed(2) }} MB)
        </p>

        <button class="btn btn-primary" (click)="uploadVideo()" [disabled]="!selectedFile || isUploading">
          {{ isUploading ? '⏳ Uploading...' : '📤 Upload Video' }}
        </button>

        <p *ngIf="uploadProgress > 0 && uploadProgress < 100" class="progress">
          Upload progress: {{ uploadProgress }}%
        </p>

        <p *ngIf="uploadError" class="error">{{ uploadError }}</p>
      </section>

      <!-- Step 2: Submit Job -->
      <!-- Persistent Preview -->
<div *ngIf="previewUrl" class="preview">
  <h3>Uploaded Video Preview</h3>

  <video
    [src]="previewUrl"
    controls
    preload="metadata"
    width="100%"
    (loadedmetadata)="onVideoMetaData($event)">
  </video>

  <p class="muted" *ngIf="videoDuration">
    Duration: {{ videoDuration | number:'1.0-1' }}s |
    📐 Resolution: {{ videoWidth }}×{{ videoHeight }}
  </p>
</div>

<!-- Step 2: Submit Job -->
<section *ngIf="uploadedKey && !jobId">
  <h2>Step 2: Submit Processing Job</h2>

  <label>Operation:</label>
  <select [(ngModel)]="operation">
    <option value="1">Resize to 720p</option>
    <option value="2">Resize to 480p</option>
    <option value="3">Extract thumbnail</option>
  </select>

  <button class="btn btn-primary"
          (click)="submitJob()"
          [disabled]="isSubmitting">
    {{ isSubmitting ? '⏳ Submitting...' : '🚀 Submit Job' }}
  </button>

  <p *ngIf="jobError" class="error">{{ jobError }}</p>
</section>

      <!-- Step 3: Processing -->
      <section *ngIf="jobId">
        <h2>Step 3: Processing Status</h2>

        <p><strong>Job ID:</strong> {{ jobId }}</p>

        <!-- 🔄 Processing UX -->
        <div *ngIf="jobStatus === 'processing'" class="processing">
          <div class="spinner"></div>
          <p>⚙️ Processing your video…</p>
          <p class="muted">
            This may take a few minutes depending on the video.
          </p>
          <p class="muted">
            ⏱️ Time elapsed: {{ processingSeconds }}s
          </p>

          <button class="btn btn-secondary" disabled>
            🔄 Processing…
          </button>
        </div>

        <!-- ✅ Completed -->
        <div *ngIf="isProcessed" class="success">
          <p>✅ Video processed successfully!</p>
          <button
  class="btn btn-download"
  (click)="downloadProcessedVideo()"
>
  📥 Download Video
</button>

        </div>

        <!-- ❌ Failed -->
        <div *ngIf="jobStatus === 'failed'" class="error">
          <p>❌ Processing failed.</p>
          <button class="btn btn-secondary" (click)="reset()">Start Over</button>
        </div>
      </section>

      <footer>
        <button class="btn btn-logout" (click)="logout()">🚪 Logout</button>
      </footer>
    </div>
  `,
  styles: [`
    .container { max-width: 800px; margin: auto; padding: 20px; }
    section { border: 1px solid #ddd; padding: 20px; margin-top: 20px; border-radius: 8px; background: #f9f9f9; }
    .btn { padding: 10px 16px; margin-top: 10px; }
    .btn-primary { background: #007bff; color: #fff; }
    .btn-secondary { background: #6c757d; color: #fff; }
    .btn-download { background: #28a745; color: #fff; }
    .btn-logout { background: #dc3545; color: #fff; }
    .error { background: #f8d7da; padding: 10px; border-radius: 4px; margin-top: 10px; }
    .success { background: #d4edda; padding: 10px; border-radius: 4px; margin-top: 10px; }
    .progress { background: #cce5ff; padding: 10px; border-radius: 4px; }

    .processing {
      text-align: center;
      margin-top: 20px;
    }

    .spinner {
      margin: 20px auto;
      width: 40px;
      height: 40px;
      border: 4px solid #ddd;
      border-top: 4px solid #007bff;
      border-radius: 50%;
      animation: spin 1s linear infinite;
    }

    .muted {
      color: #666;
      font-size: 14px;
    }

    @keyframes spin {
      to { transform: rotate(360deg); }
    }
  `]
})
export class Upload implements OnInit {

  pendingPreviewUrl = '';
  processedKey = '';


  processingStartedAt: number | null = null;
  processingSeconds = 0;
  processingTimer?: any;
  isChecking = false;

  selectedFile: File | null = null;
  uploadedKey = '';
  uploadProgress = 0;
  uploadError = '';
  isUploading = false;

  operation = '1';
  isSubmitting = false;
  jobError = '';

  jobId = '';
  jobStatus: 'processing' | 'completed' | 'failed' = 'processing';
  isProcessed = false;
  downloadUrl = '';

  //Preview state
  previewUrl = '';
  videoDuration = 0;
  videoWidth = 0;
  videoHeight = 0;



  constructor(
    private http: HttpClient,
    private auth: Auth,
    private cdr: ChangeDetectorRef
  ) { }

  ngOnInit(): void { }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    this.selectedFile = input.files?.[0] || null;
  }
  onVideoMetaData(event: Event): void {
    const video = event.target as HTMLVideoElement;

    this.videoDuration = video.duration;
    this.videoWidth = video.videoWidth;
    this.videoHeight = video.videoHeight;

    this.cdr.detectChanges();
  }

  uploadVideo(): void {
    if (!this.selectedFile) return;

    this.isUploading = true;
    this.uploadProgress = 0;

    this.http.post<UploadResponse>(`${environment.api.baseUrl}/upload`, {
      filename: this.selectedFile.name
    }).subscribe({
      next: res => {
        this.uploadedKey = res.key;
        this.pendingPreviewUrl = res.preview_url;
        this.uploadToS3(res.upload_url);
      },
      error: err => {
        this.uploadError = err.message || 'Upload failed';
        this.isUploading = false;
      }
    });
  }

  private uploadToS3(url: string): void {
    const xhr = new XMLHttpRequest();

    xhr.upload.onprogress = e => {
      if (e.lengthComputable) {
        this.uploadProgress = Math.round((e.loaded / e.total) * 100);
        this.cdr.detectChanges();
      }
    };

    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        this.isUploading = false;
        this.previewUrl = this.pendingPreviewUrl;
        this.pendingPreviewUrl = '';
        this.cdr.detectChanges();
      } else {
        this.uploadError = 'S3 upload failed';
        this.isUploading = false;
      }

    };

    xhr.onerror = () => {
      this.uploadError = 'Upload error';
      this.isUploading = false;
      this.cdr.detectChanges();
    };

    xhr.open('PUT', url);
    xhr.setRequestHeader('Content-Type', this.selectedFile!.type);
    xhr.send(this.selectedFile);
  }

  submitJob(): void {
    this.isSubmitting = true;
    this.processingStartedAt = Date.now();
    this.processingSeconds = 0;

    this.processingTimer = setInterval(() => {
      this.processingSeconds = Math.floor(
        (Date.now() - (this.processingStartedAt as number)) / 1000
      );
      this.cdr.detectChanges();
    }, 1000);


    this.http.post<JobResponse>(`${environment.api.baseUrl}/job`, {
      input_key: this.uploadedKey,
      operation: parseInt(this.operation)
    }).subscribe({
      next: res => {
        this.jobId = res.job_id;
        this.downloadUrl = res.output_key;
        this.processedKey = res.output_key;
        this.jobStatus = 'processing';
        this.isSubmitting = false;
        this.processedKey = res.output_key;

        this.processingStartedAt = Date.now();
        this.processingTimer = setInterval(() => {
          this.processingSeconds = Math.floor((Date.now() - (this.processingStartedAt as number)) / 1000);
          this.cdr.detectChanges();
        }, 1000);

        setTimeout(() => this.checkStatus(), 2000);
      },
      error: err => {
        this.jobError = err.message || 'Job submission failed';
        this.isSubmitting = false;
      }
    });
  }

  checkStatus(): void {
    if (this.isChecking || !this.jobId) return;

    this.isChecking = true;


    this.http.get<StatusResponse>(`${environment.api.baseUrl}/status`, {
      params: { job_id: this.jobId, output_key: this.downloadUrl }
    }).subscribe({
      next: res => {
        this.jobStatus = res.status;
        if (res.status === 'completed') {
          this.jobStatus = 'completed'
          this.isProcessed = true;
          clearInterval(this.processingTimer);
        }

        if (res.status === 'failed') {
          clearInterval(this.processingTimer);
          this.jobError = res.error || 'Processing failed';
        }


        if (res.status === 'completed') {
          this.isProcessed = true;
          clearInterval(this.processingTimer);
        }

        if (res.status === 'failed') {
          clearInterval(this.processingTimer);
          this.jobError = res.error || 'Processing failed';
        }

        if (res.status === 'processing') {
          setTimeout(() => this.checkStatus(), 3000);
        }

        this.isChecking = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.isChecking = false;
      }
    });
  }

  reset(): void {
    clearInterval(this.processingTimer);
    this.selectedFile = null;
    this.uploadedKey = '';
    this.jobId = '';
    this.jobStatus = 'processing';
    this.isProcessed = false;
    this.processingSeconds = 0;
  }


  logout(): void {
    clearInterval(this.processingTimer);
    this.auth.logout();
  }
  downloadProcessedVideo(): void {
    console.log('Downloading key:', this.processedKey);
    if (!this.processedKey) return;

    this.http.get<{ download_url: string }>(
      `${environment.api.baseUrl}/download`,
      {
        params: {
          output_key: this.processedKey
        }
      }
    ).subscribe({
      next: res => {
        window.location.href = res.download_url;
      },
      error: err => {
        console.error('Download failed ', err)
        alert('Failed to download the video')
      }
    })
  }
}
