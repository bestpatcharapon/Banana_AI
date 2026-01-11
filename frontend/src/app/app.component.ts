import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import { ApiService, User, TaskResponse } from './services/api.service';

type TabType = 'active' | 'pullreq' | 'changes';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss']
})
export class AppComponent implements OnInit {
  user: User | null = null;
  taskResponse: TaskResponse | null = null;
  isLoading = false;
  error: string | null = null;
  activeTab: TabType = 'active';

  constructor(private api: ApiService) {}

  ngOnInit(): void {
    this.handleUrlParams();
    this.checkLogin();
  }

  // === Authentication ===

  login(): void {
    // Use relative URL - works on any domain
    window.location.href = '/auth/microsoft';
  }

  logout(): void {
    this.api.logout();
  }

  // === Task Fetching ===

  fetchTasks(): void {
    this.isLoading = true;
    this.error = null;

    this.api.getMyTasks().subscribe({
      next: (response) => {
        this.taskResponse = response;
        this.isLoading = false;
      },
      error: (err: HttpErrorResponse) => {
        this.handleFetchError(err);
        this.isLoading = false;
      }
    });
  }

  // === Tab Content ===

  getTabContent(): string {
    if (!this.taskResponse) return '';
    
    const sections = this.taskResponse.sections;
    if (sections) {
      const contentMap: Record<TabType, string> = {
        active: sections.active || '',
        pullreq: sections.pull_requested || 'ไม่มีงาน Pull Requested',
        changes: sections.state_changes || 'ไม่มี State Changes วันนี้'
      };
      return this.formatContent(contentMap[this.activeTab]);
    }
    
    // Fallback: split by delimiter
    const parts = (this.taskResponse.content || '').split('---');
    const fallbackMap: Record<TabType, string> = {
      active: parts[0] || '',
      pullreq: parts[1] || 'ไม่มีงาน Pull Requested',
      changes: parts[2] || 'ไม่มี State Changes วันนี้'
    };
    return this.formatContent(fallbackMap[this.activeTab].trim());
  }

  // === Private Methods ===

  private handleUrlParams(): void {
    const params = new URLSearchParams(window.location.search);
    
    if (params.has('token')) {
      this.api.setToken(params.get('token')!);
      this.user = {
        logged_in: true,
        name: decodeURIComponent(params.get('name') || ''),
        email: decodeURIComponent(params.get('email') || '')
      };
      this.cleanUrl();
    }
    
    if (params.has('error')) {
      this.error = params.get('error');
      this.cleanUrl();
    }
    
    if (params.has('logged_out')) {
      this.api.clearToken();
      this.user = { logged_in: false };
      this.cleanUrl();
    }
  }

  private checkLogin(): void {
    if (this.user?.logged_in) return;
    
    if (this.api.isLoggedIn()) {
      this.api.getCurrentUser().subscribe({
        next: (user) => this.user = user,
        error: () => {
          this.api.clearToken();
          this.user = { logged_in: false };
        }
      });
    } else {
      this.user = { logged_in: false };
    }
  }

  private handleFetchError(err: HttpErrorResponse): void {
    if (err.status === 401) {
      this.error = 'กรุณา Login ใหม่';
      this.api.clearToken();
      this.user = { logged_in: false };
    } else {
      const errorBody = err.error as { error?: string };
      this.error = errorBody?.error || err.message || 'เกิดข้อผิดพลาด';
    }
  }

  private cleanUrl(): void {
    window.history.replaceState({}, document.title, window.location.pathname);
  }

  private formatContent(content: string): string {
    if (!content) return '';
    return content
      .replace(/^### (.*)$/gm, '<h3>$1</h3>')
      .replace(/^## (.*)$/gm, '<h2>$1</h2>')
      .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
      .replace(/^---$/gm, '<hr>')
      .replace(/\n/g, '<br>')
      .replace(/<\/h2><br>/g, '</h2>')
      .replace(/<\/h3><br>/g, '</h3>')
      .replace(/<hr><br>/g, '<hr>');
  }
}
