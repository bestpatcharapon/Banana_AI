import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface User {
  logged_in: boolean;
  email?: string;
  name?: string;
}

export interface TaskResponse {
  user: { email?: string; name?: string };
  content: string;
  sections?: {
    active: string;
    pull_requested: string;
    state_changes: string;
  };
  timestamp: string;
  error?: string;
}

@Injectable({
  providedIn: 'root'
})
export class ApiService {
  private apiUrl = environment.apiUrl;
  private TOKEN_KEY = 'banana_auth_token';

  constructor(private http: HttpClient) {}

  // Store token in localStorage
  setToken(token: string): void {
    localStorage.setItem(this.TOKEN_KEY, token);
  }

  // Get token from localStorage
  getToken(): string | null {
    return localStorage.getItem(this.TOKEN_KEY);
  }

  // Remove token
  clearToken(): void {
    localStorage.removeItem(this.TOKEN_KEY);
  }

  // Check if user is logged in (has token)
  isLoggedIn(): boolean {
    return !!this.getToken();
  }

  // Get headers with Authorization token
  private getAuthHeaders(): HttpHeaders {
    const token = this.getToken();
    if (token) {
      return new HttpHeaders({
        'Authorization': `Bearer ${token}`
      });
    }
    return new HttpHeaders();
  }

  getCurrentUser(): Observable<User> {
    return this.http.get<User>(`${this.apiUrl}/auth/user`, { 
      headers: this.getAuthHeaders()
    });
  }

  getMyTasks(): Observable<TaskResponse> {
    return this.http.get<TaskResponse>(`${this.apiUrl}/api/my_tasks`, { 
      headers: this.getAuthHeaders()
    });
  }

  getDemoTasks(userName: string): Observable<TaskResponse> {
    return this.http.post<TaskResponse>(
      `${this.apiUrl}/api/my_tasks/demo`,
      { user_name: userName },
      { headers: this.getAuthHeaders() }
    );
  }

  getLoginUrl(): string {
    return `${this.apiUrl}/auth/microsoft`;
  }

  logout(): void {
    const token = this.getToken();
    this.clearToken();
    // Use relative URL - works on any domain
    window.location.href = `/auth/logout${token ? '?token=' + token : ''}`;
  }
}
