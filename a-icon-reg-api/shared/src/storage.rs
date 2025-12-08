use crate::error::{ApiError, ApiResult};
use aws_sdk_s3::{Client, Config, config::Region, primitives::ByteStream};
use aws_config::meta::region::RegionProviderChain;
use std::env;

pub struct StorageService {
    client: Client,
    bucket: String,
}

impl StorageService {
    pub async fn new() -> ApiResult<Self> {
        let endpoint = env::var("S3_ENDPOINT")
            .unwrap_or_else(|_| "https://nyc3.digitaloceanspaces.com".to_string());
        let region = env::var("S3_REGION")
            .unwrap_or_else(|_| "nyc3".to_string());
        let bucket = env::var("S3_BUCKET")
            .unwrap_or_else(|_| "a-icon".to_string());

        let region_provider = RegionProviderChain::first_try(Region::new(region));
        let config = aws_config::defaults(aws_config::BehaviorVersion::latest())
            .region(region_provider)
            .endpoint_url(endpoint)
            .load()
            .await;

        let s3_config = Config::from(&config);
        let client = Client::from_conf(s3_config);

        Ok(StorageService { client, bucket })
    }

    pub async fn upload_object(&self, key: &str, data: Vec<u8>, content_type: &str) -> ApiResult<()> {
        self.client
            .put_object()
            .bucket(&self.bucket)
            .key(key)
            .body(ByteStream::from(data))
            .content_type(content_type)
            .send()
            .await
            .map_err(|e| ApiError::StorageError(format!("Failed to upload object: {}", e)))?;

        Ok(())
    }

    pub async fn get_object(&self, key: &str) -> ApiResult<Vec<u8>> {
        let response = self.client
            .get_object()
            .bucket(&self.bucket)
            .key(key)
            .send()
            .await
            .map_err(|e| ApiError::StorageError(format!("Failed to get object: {}", e)))?;

        let data = response.body.collect().await
            .map_err(|e| ApiError::StorageError(format!("Failed to read object body: {}", e)))?;

        Ok(data.into_bytes().to_vec())
    }

    pub async fn delete_object(&self, key: &str) -> ApiResult<()> {
        self.client
            .delete_object()
            .bucket(&self.bucket)
            .key(key)
            .send()
            .await
            .map_err(|e| ApiError::StorageError(format!("Failed to delete object: {}", e)))?;

        Ok(())
    }

    pub fn detect_mime_type(buffer: &[u8]) -> String {
        if buffer.len() < 4 {
            return "application/octet-stream".to_string();
        }

        // PNG: 89 50 4E 47
        if buffer[0] == 0x89 && buffer[1] == 0x50 && buffer[2] == 0x4E && buffer[3] == 0x47 {
            return "image/png".to_string();
        }

        // JPEG: FF D8 FF
        if buffer[0] == 0xFF && buffer[1] == 0xD8 && buffer[2] == 0xFF {
            return "image/jpeg".to_string();
        }

        // GIF: 47 49 46
        if buffer[0] == 0x47 && buffer[1] == 0x49 && buffer[2] == 0x46 {
            return "image/gif".to_string();
        }

        // SVG: starts with < or whitespace then <
        if let Ok(str) = std::str::from_utf8(&buffer[..buffer.len().min(100)]) {
            let trimmed = str.trim();
            if trimmed.starts_with("<svg") || trimmed.starts_with("<?xml") {
                return "image/svg+xml".to_string();
            }
        }

        // ICO: 00 00 01 00
        if buffer.len() >= 4 && buffer[0] == 0x00 && buffer[1] == 0x00 
            && buffer[2] == 0x01 && buffer[3] == 0x00 {
            return "image/x-icon".to_string();
        }

        "application/octet-stream".to_string()
    }

    pub fn mime_type_from_extension(ext: &str) -> String {
        match ext.to_lowercase().as_str() {
            "png" => "image/png",
            "jpg" | "jpeg" => "image/jpeg",
            "gif" => "image/gif",
            "svg" => "image/svg+xml",
            "ico" => "image/x-icon",
            _ => "application/octet-stream",
        }.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_mime_type() {
        // PNG
        let png = vec![0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
        assert_eq!(StorageService::detect_mime_type(&png), "image/png");

        // JPEG
        let jpeg = vec![0xFF, 0xD8, 0xFF, 0xE0];
        assert_eq!(StorageService::detect_mime_type(&jpeg), "image/jpeg");

        // GIF
        let gif = vec![0x47, 0x49, 0x46, 0x38];
        assert_eq!(StorageService::detect_mime_type(&gif), "image/gif");

        // ICO
        let ico = vec![0x00, 0x00, 0x01, 0x00];
        assert_eq!(StorageService::detect_mime_type(&ico), "image/x-icon");
    }

    #[test]
    fn test_mime_type_from_extension() {
        assert_eq!(StorageService::mime_type_from_extension("png"), "image/png");
        assert_eq!(StorageService::mime_type_from_extension("PNG"), "image/png");
        assert_eq!(StorageService::mime_type_from_extension("jpg"), "image/jpeg");
        assert_eq!(StorageService::mime_type_from_extension("svg"), "image/svg+xml");
        assert_eq!(StorageService::mime_type_from_extension("ico"), "image/x-icon");
        assert_eq!(StorageService::mime_type_from_extension("unknown"), "application/octet-stream");
    }
}

