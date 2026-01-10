import { Component, OnInit } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { environment } from '../../../environments/environment';
import { Auth } from '../../core/auth/auth';

interface UploadResponse {
  upload_url: string;
  key: string;
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
    <div class="container">
      <h1>Video Upload & Processing</h1>

      <!-- Debug Info -->
      <section class="debug-section">
        <h3>🔍 Debug Info</h3>
        <p><strong>API Base URL:</strong> {{ environment.api.baseUrl }}</p>
        <p><strong>Has Token:</strong> {{ hasToken ? '✅ Yes' : '❌ No' }}</p>
        <button (click)="toggleDebug()" class="btn btn-debug">
          {{ showDebug ? '🔓 Hide Debug' : '🔒 Show Debug' }}
        </button>
        <pre *ngIf="showDebug" class="debug-info">{{ debugInfo | json }}</pre>
      </section>

      <!-- Step 1: Upload Video -->
      <section *ngIf="!jobId" class="upload-section">
        <h2>Step 1: Upload Video</h2>
        
        <div class="file-input-wrapper">
          <input 
            type="file" 
            #fileInput
            accept="video/*"
            (change)="onFileSelected($event)"
            [disabled]="isUploading"
          />
          <p *ngIf="selectedFile">📁 {{ selectedFile.name }} ({{ (selectedFile.size / 1024 / 1024).toFixed(2) }} MB)</p>
        </div>

        <button 
          (click)="uploadVideo()" 
          [disabled]="!selectedFile || isUploading"
          class="btn btn-primary"
        >
          {{ isUploading ? '⏳ Uploading...' : '📤 Upload Video' }}
        </button>

        <p *ngIf="uploadError" class="error">❌ {{ uploadError }}</p>
        <p *ngIf="uploadProgress > 0 && uploadProgress < 100" class="progress">
          ⏸️ Upload progress: {{ uploadProgress }}%
        </p>
      </section>

      <!-- Step 2: Submit Job -->
      <section *ngIf="selectedFile && !jobId" class="job-section">
        <h2>Step 2: Submit Processing Job</h2>
        
        <div class="form-group">
          <label>Processing Operation:</label>
          <select [(ngModel)]="operation">
            <option value="1">Resize to 720p</option>
            <option value="2">Resize to 480p</option>
            <option value="3">Extract thumbnail</option>
          </select>
        </div>

        <button 
          (click)="submitJob()" 
          [disabled]="!uploadedKey || isSubmitting"
          class="btn btn-primary"
        >
          {{ isSubmitting ? '⏳ Submitting...' : '🚀 Submit Job' }}
        </button>

        <p *ngIf="jobError" class="error">❌ {{ jobError }}</p>
      </section>

      <!-- Step 3: Monitor Job -->
      <section *ngIf="jobId" class="status-section">
        <h2>Step 3: Processing Status</h2>
        
        <p><strong>Job ID:</strong> {{ jobId }}</p>
        <p *ngIf="!isProcessed"><strong>Status:</strong> {{ jobStatus }}</p>

        <button 
          (click)="checkStatus()" 
          [disabled]="isProcessed || isChecking"
          class="btn btn-secondary"
        >
          {{ isChecking ? '🔄 Checking...' : '🔍 Check Status' }}
        </button>

        <p *ngIf="jobError" class="error">❌ {{ jobError }}</p>

        <div *ngIf="isProcessed" class="success">
          <p>✅ Video processed successfully!</p>
          <a [href]="downloadUrl" target="_blank" class="btn btn-download">
            📥 Download Processed Video
          </a>
        </div>

        <div *ngIf="jobStatus === 'failed'" class="error">
          <p>❌ Processing failed. Please try again.</p>
          <button (click)="reset()" class="btn btn-secondary">Start Over</button>
        </div>
      </section>

      <!-- Logout -->
      <footer>
        <button (click)="logout()" class="btn btn-logout">🚪 Logout</button>
      </footer>
    </div>
  `,
  styles: [`
    .container {
      max-width: 800px;
      margin: 0 auto;
      padding: 20px;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }

    h1 {
      color: #333;
      text-align: center;
    }

    section {
      margin: 30px 0;
      padding: 20px;
      border: 1px solid #ddd;
      border-radius: 8px;
      background: #f9f9f9;
    }

    h2 {
      color: #555;
      font-size: 18px;
      margin-top: 0;
    }

    h3 {
      color: #555;
      font-size: 16px;
    }

    .file-input-wrapper {
      margin: 15px 0;
    }

    input[type="file"] {
      padding: 10px;
      border: 1px solid #ccc;
      border-radius: 4px;
      cursor: pointer;
      width: 100%;
    }

    input[type="file"]:disabled {
      background: #eee;
      cursor: not-allowed;
    }

    .form-group {
      margin: 15px 0;
    }

    label {
      display: block;
      margin-bottom: 5px;
      font-weight: bold;
    }

    select {
      width: 100%;
      padding: 10px;
      border: 1px solid #ccc;
      border-radius: 4px;
    }

    .btn {
      padding: 10px 20px;
      margin: 10px 5px 10px 0;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      font-size: 14px;
      font-weight: 500;
    }

    .btn:disabled {
      opacity: 0.6;
      cursor: not-allowed;
    }

    .btn-primary {
      background: #007bff;
      color: white;
    }

    .btn-primary:hover:not(:disabled) {
      background: #0056b3;
    }

    .btn-secondary {
      background: #6c757d;
      color: white;
    }

    .btn-secondary:hover:not(:disabled) {
      background: #545b62;
    }

    .btn-download {
      background: #28a745;
      color: white;
    }

    .btn-download:hover {
      background: #218838;
    }

    .btn-logout {
      background: #dc3545;
      color: white;
    }

    .btn-logout:hover {
      background: #c82333;
    }

    .btn-debug {
      background: #666;
      color: white;
      font-size: 12px;
    }

    .error {
      color: #dc3545;
      padding: 10px;
      background: #f8d7da;
      border: 1px solid #f5c6cb;
      border-radius: 4px;
      margin: 10px 0;
    }

    .success {
      color: #155724;
      padding: 10px;
      background: #d4edda;
      border: 1px solid #c3e6cb;
      border-radius: 4px;
      margin: 10px 0;
    }

    .progress {
      color: #004085;
      padding: 10px;
      background: #cce5ff;
      border: 1px solid #b8daff;
      border-radius: 4px;
      margin: 10px 0;
    }

    .debug-info {
      background: #000;
      color: #0f0;
      padding: 10px;
      border-radius: 4px;
      overflow-x: auto;
      font-size: 12px;
      max-height: 300px;
      overflow-y: auto;
    }

    .debug-section {
      margin-top: 30px;
      background: #f0f0f0;
    }

    footer {
      margin-top: 40px;
      text-align: center;
      border-top: 1px solid #ddd;
      padding-top: 20px;
    }
  `]
})
export class Upload implements OnInit {
  // File upload
  selectedFile: File | null = null;
  isUploading = false;
  uploadProgress = 0;
  uploadError = '';
  uploadedKey = '';

  // Job submission
  operation = '1';
  isSubmitting = false;
  jobError = '';

  // Job status
  jobId = '';
  jobStatus = 'processing';
  isProcessed = false;
  downloadUrl = '';
  isChecking = false;

  // Debug
  showDebug = false;
  debugInfo: any = {};
  hasToken = false;
  environment = environment;

  constructor(
    private http: HttpClient,
    private auth: Auth
  ) { }

  ngOnInit(): void {
    this.hasToken = this.auth.isAuthenticated();
    this.updateDebugInfo();
  }

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const files = input.files;

    if (files && files.length > 0) {
      this.selectedFile = files[0];
      this.uploadError = '';
      this.updateDebugInfo();
    }
  }

  uploadVideo(): void {
    if (!this.selectedFile) {
      this.uploadError = 'Please select a file';
      return;
    }

    this.isUploading = true;
    this.uploadError = '';
    this.uploadProgress = 0;

    console.log('📤 Requesting presigned upload URL from:', `${environment.api.baseUrl}/upload`);

    // Step 1: Get presigned upload URL from API
    this.http.post<UploadResponse>(`${environment.api.baseUrl}/upload`, {
      filename: this.selectedFile.name,
    }).subscribe({
      next: (response) => {
        console.log('✅ Got presigned upload URL:', response.upload_url);
        this.uploadedKey = response.key;
        this.uploadToS3(response.upload_url);
      },
      error: (err) => {
        console.error('❌ Failed to get upload URL:', err);
        const errorMsg = err.error?.message || err.message || 'Unknown error';
        this.uploadError = `Failed to get upload URL: ${errorMsg}`;
        this.isUploading = false;
        this.updateDebugInfo();
      }
    });
  }

  private uploadToS3(presignedUrl: string): void {
    // Step 2: Upload file directly to S3 using presigned URL
    const xhr = new XMLHttpRequest();

    xhr.upload.addEventListener('progress', (event) => {
      if (event.lengthComputable) {
        this.uploadProgress = Math.round((event.loaded / event.total) * 100);
      }
    });

    xhr.addEventListener('load', () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        console.log('✅ File uploaded to S3 successfully');
        this.isUploading = false;
        this.uploadProgress = 100;
        this.updateDebugInfo();
      } else {
        console.error('❌ S3 upload failed:', xhr.status, xhr.statusText);
        this.uploadError = `Upload failed: ${xhr.statusText} (${xhr.status})`;
        this.isUploading = false;
        this.updateDebugInfo();
      }
    });

    xhr.addEventListener('error', () => {
      console.error('❌ Upload error');
      this.uploadError = 'Upload error. Check console for details.';
      this.isUploading = false;
      this.updateDebugInfo();
    });

    xhr.open('PUT', presignedUrl);
    xhr.setRequestHeader('Content-Type', this.selectedFile!.type);
    xhr.send(this.selectedFile);
  }

  submitJob(): void {
    if (!this.uploadedKey) {
      this.jobError = 'Please upload a video first';
      return;
    }

    this.isSubmitting = true;
    this.jobError = '';

    console.log('🚀 Submitting job:', { input_key: this.uploadedKey, operation: this.operation });

    this.http.post<JobResponse>(`${environment.api.baseUrl}/job`, {
      input_key: this.uploadedKey,
      operation: parseInt(this.operation),
    }).subscribe({
      next: (response) => {
        console.log('✅ Job submitted:', response.job_id);
        this.jobId = response.job_id;
        this.jobStatus = 'processing';
        this.isSubmitting = false;
        this.updateDebugInfo();
        // Auto-check status after a delay
        setTimeout(() => this.checkStatus(), 2000);
      },
      error: (err) => {
        console.error('❌ Failed to submit job:', err);
        const errorMsg = err.error?.message || err.message || 'Unknown error';
        this.jobError = `Failed to submit job: ${errorMsg}`;
        this.isSubmitting = false;
        this.updateDebugInfo();
      }
    });
  }

  checkStatus(): void {
    if (!this.jobId) return;

    this.isChecking = true;
    this.jobError = '';

    console.log('🔍 Checking job status:', this.jobId);

    this.http.get<StatusResponse>(`${environment.api.baseUrl}/status`, {
      params: { job_id: this.jobId }
    }).subscribe({
      next: (response) => {
        console.log('✅ Status check:', response.status);
        this.jobStatus = response.status;

        if (response.status === 'completed' && response.download_url) {
          this.isProcessed = true;
          this.downloadUrl = response.download_url;
        } else if (response.status === 'failed') {
          this.jobError = response.error || 'Processing failed';
        } else if (response.status === 'processing') {
          // Keep polling
          setTimeout(() => this.checkStatus(), 3000);
        }

        this.isChecking = false;
        this.updateDebugInfo();
      },
      error: (err) => {
        console.error('❌ Status check failed:', err);
        const errorMsg = err.error?.message || err.message || 'Unknown error';
        this.jobError = `Failed to check status: ${errorMsg}`;
        this.isChecking = false;
        this.updateDebugInfo();
      }
    });
  }

  logout(): void {
    this.auth.logout();
  }

  reset(): void {
    this.selectedFile = null;
    this.uploadedKey = '';
    this.jobId = '';
    this.jobStatus = 'processing';
    this.isProcessed = false;
    this.downloadUrl = '';
    this.uploadProgress = 0;
    this.uploadError = '';
    this.jobError = '';
    this.updateDebugInfo();
  }

  toggleDebug(): void {
    this.showDebug = !this.showDebug;
  }

  private updateDebugInfo(): void {
    const token = this.auth.getToken();
    this.debugInfo = {
      apiBaseUrl: environment.api.baseUrl,
      selectedFile: this.selectedFile ? {
        name: this.selectedFile.name,
        size: this.selectedFile.size,
        type: this.selectedFile.type
      } : null,
      uploadedKey: this.uploadedKey,
      jobId: this.jobId,
      jobStatus: this.jobStatus,
      hasToken: !!token,
      tokenLength: token?.length || 0,
    };
  }
}