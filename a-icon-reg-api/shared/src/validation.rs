use crate::error::{ApiError, ApiResult};
use regex::Regex;

/// Validate domain name format
/// - Max 256 characters
/// - Must contain a "." with content before and after it (TLD syntax)
pub fn validate_domain(domain: &str) -> ApiResult<()> {
    // Check length
    if domain.len() > 256 {
        return Err(ApiError::ValidationError(
            "Domain name must not exceed 256 characters".to_string(),
        ));
    }

    // Check for dot presence
    if !domain.contains('.') {
        return Err(ApiError::ValidationError(
            "Domain name must contain at least one dot (.)".to_string(),
        ));
    }

    // Check that there's content before and after the dot
    let parts: Vec<&str> = domain.split('.').collect();
    if parts.len() < 2 {
        return Err(ApiError::ValidationError(
            "Domain name must have content before and after the dot".to_string(),
        ));
    }

    // Check that no part is empty
    if parts.iter().any(|part| part.is_empty()) {
        return Err(ApiError::ValidationError(
            "Domain name cannot have empty parts (e.g., \"example..com\")".to_string(),
        ));
    }

    // Validate domain format with regex
    let domain_regex = Regex::new(
        r"^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$"
    ).unwrap();

    if !domain_regex.is_match(domain) {
        return Err(ApiError::ValidationError(
            "Invalid domain name format. Domain must contain only letters, numbers, hyphens, and dots, and follow TLD syntax".to_string(),
        ));
    }

    Ok(())
}

/// Validate metadata length (max 256 characters for JPEG compatibility)
pub fn validate_metadata(metadata: &str) -> ApiResult<()> {
    if metadata.len() > 256 {
        return Err(ApiError::ValidationError(
            "Metadata must not exceed 256 characters".to_string(),
        ));
    }
    Ok(())
}

/// Validate file size (max 0.5 MB)
pub fn validate_file_size(size: usize) -> ApiResult<()> {
    const MAX_SIZE: usize = 512 * 1024; // 0.5 MB
    if size > MAX_SIZE {
        let size_mb = size as f64 / (1024.0 * 1024.0);
        return Err(ApiError::ValidationError(format!(
            "File size ({:.2}MB) exceeds the maximum allowed size of 0.5 MB",
            size_mb
        )));
    }
    Ok(())
}

/// Validate that the buffer is an image
pub fn validate_image_type(buffer: &[u8]) -> ApiResult<String> {
    if buffer.len() < 4 {
        return Err(ApiError::ValidationError(
            "File is too small to be a valid image".to_string(),
        ));
    }

    // Check magic bytes
    // PNG: 89 50 4E 47
    if buffer[0] == 0x89 && buffer[1] == 0x50 && buffer[2] == 0x4E && buffer[3] == 0x47 {
        return Ok("image/png".to_string());
    }

    // JPEG: FF D8 FF
    if buffer[0] == 0xFF && buffer[1] == 0xD8 && buffer[2] == 0xFF {
        return Ok("image/jpeg".to_string());
    }

    // GIF: 47 49 46
    if buffer[0] == 0x47 && buffer[1] == 0x49 && buffer[2] == 0x46 {
        return Ok("image/gif".to_string());
    }

    // SVG: starts with < or whitespace then <
    if let Ok(str) = std::str::from_utf8(&buffer[..buffer.len().min(100)]) {
        let trimmed = str.trim();
        if trimmed.starts_with("<svg") || trimmed.starts_with("<?xml") {
            return Ok("image/svg+xml".to_string());
        }
    }

    Err(ApiError::ValidationError(
        "Only image files are allowed (PNG, JPEG, GIF, SVG)".to_string(),
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_domain() {
        assert!(validate_domain("example.com").is_ok());
        assert!(validate_domain("sub.example.com").is_ok());
        assert!(validate_domain("a-b.example.com").is_ok());
        
        assert!(validate_domain("example").is_err());
        assert!(validate_domain("example.").is_err());
        assert!(validate_domain(".example.com").is_err());
        assert!(validate_domain("example..com").is_err());
    }

    #[test]
    fn test_validate_metadata() {
        assert!(validate_metadata("short").is_ok());
        assert!(validate_metadata(&"a".repeat(256)).is_ok());
        assert!(validate_metadata(&"a".repeat(257)).is_err());
    }

    #[test]
    fn test_validate_file_size() {
        assert!(validate_file_size(1024).is_ok());
        assert!(validate_file_size(512 * 1024).is_ok());
        assert!(validate_file_size(512 * 1024 + 1).is_err());
    }
}

