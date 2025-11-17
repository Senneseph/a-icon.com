import { Injectable } from '@nestjs/common';
import { createHash, randomBytes } from 'crypto';

interface AdminSession {
  token: string;
  expiresAt: number;
}

@Injectable()
export class AdminService {
  private sessions: Map<string, AdminSession> = new Map();
  private readonly SESSION_DURATION = 24 * 60 * 60 * 1000; // 24 hours

  /**
   * Verify admin password and create session token
   */
  verifyPassword(password: string): { token: string } | null {
    const adminPassword = process.env.ADMIN_PASSWORD || 'changeme';

    if (password !== adminPassword) {
      return null;
    }

    // Generate secure random token
    const token = randomBytes(32).toString('hex');
    const expiresAt = Date.now() + this.SESSION_DURATION;

    this.sessions.set(token, { token, expiresAt });

    // Clean up expired sessions
    this.cleanupExpiredSessions();

    return { token };
  }

  /**
   * Verify if a token is valid
   */
  verifyToken(token: string): boolean {
    const session = this.sessions.get(token);

    if (!session) {
      return false;
    }

    if (Date.now() > session.expiresAt) {
      this.sessions.delete(token);
      return false;
    }

    return true;
  }

  /**
   * Invalidate a session token
   */
  logout(token: string): void {
    this.sessions.delete(token);
  }

  /**
   * Clean up expired sessions
   */
  private cleanupExpiredSessions(): void {
    const now = Date.now();
    for (const [token, session] of this.sessions.entries()) {
      if (now > session.expiresAt) {
        this.sessions.delete(token);
      }
    }
  }
}

