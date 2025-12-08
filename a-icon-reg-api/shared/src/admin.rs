use crate::error::{ApiError, ApiResult};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::fs;
use std::env;
use chrono::{DateTime, Utc, Duration};
use uuid::Uuid;

#[derive(Clone)]
pub struct AdminService {
    password: String,
    sessions: Arc<Mutex<HashMap<String, DateTime<Utc>>>>,
}

impl AdminService {
    pub fn new() -> ApiResult<Self> {
        let password_file = env::var("ADMIN_PASSWORD_FILE")
            .unwrap_or_else(|_| ".admin-password".to_string());

        let password = fs::read_to_string(&password_file)
            .map_err(|e| ApiError::InternalError(format!("Failed to read admin password: {}", e)))?
            .trim()
            .to_string();

        Ok(AdminService {
            password,
            sessions: Arc::new(Mutex::new(HashMap::new())),
        })
    }

    pub fn verify_password(&self, password: &str) -> ApiResult<(String, DateTime<Utc>)> {
        if password != self.password {
            return Err(ApiError::Unauthorized("Invalid password".to_string()));
        }

        let token = Uuid::new_v4().to_string();
        let expires_at = Utc::now() + Duration::hours(1);

        let mut sessions = self.sessions.lock().unwrap();
        sessions.insert(token.clone(), expires_at);

        // Clean up expired sessions
        let now = Utc::now();
        sessions.retain(|_, exp| *exp > now);

        Ok((token, expires_at))
    }

    pub fn verify_token(&self, token: &str) -> bool {
        let mut sessions = self.sessions.lock().unwrap();
        
        // Clean up expired sessions
        let now = Utc::now();
        sessions.retain(|_, exp| *exp > now);

        sessions.get(token).map(|exp| *exp > now).unwrap_or(false)
    }

    pub fn logout(&self, token: &str) {
        let mut sessions = self.sessions.lock().unwrap();
        sessions.remove(token);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use tempfile::NamedTempFile;

    #[test]
    fn test_verify_password() {
        let mut temp_file = NamedTempFile::new().unwrap();
        writeln!(temp_file, "test-password").unwrap();
        
        env::set_var("ADMIN_PASSWORD_FILE", temp_file.path());
        
        let service = AdminService::new().unwrap();
        
        // Valid password
        let result = service.verify_password("test-password");
        assert!(result.is_ok());
        
        // Invalid password
        let result = service.verify_password("wrong-password");
        assert!(result.is_err());
    }

    #[test]
    fn test_token_lifecycle() {
        let mut temp_file = NamedTempFile::new().unwrap();
        writeln!(temp_file, "test-password").unwrap();
        
        env::set_var("ADMIN_PASSWORD_FILE", temp_file.path());
        
        let service = AdminService::new().unwrap();
        
        // Login
        let (token, _) = service.verify_password("test-password").unwrap();
        
        // Verify token is valid
        assert!(service.verify_token(&token));
        
        // Logout
        service.logout(&token);
        
        // Verify token is invalid
        assert!(!service.verify_token(&token));
    }

    #[test]
    fn test_invalid_token() {
        let mut temp_file = NamedTempFile::new().unwrap();
        writeln!(temp_file, "test-password").unwrap();
        
        env::set_var("ADMIN_PASSWORD_FILE", temp_file.path());
        
        let service = AdminService::new().unwrap();
        
        // Random token should be invalid
        assert!(!service.verify_token("invalid-token"));
    }
}

