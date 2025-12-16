use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Favicon {
    pub id: String,
    pub slug: String,
    pub title: Option<String>,
    pub target_domain: Option<String>,
    pub published_url: String,
    pub canonical_svg_key: Option<String>,
    pub source_type: SourceType,
    pub source_original_mime: Option<String>,
    pub source_hash: Option<String>,
    pub source_size: Option<i64>,
    pub is_published: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub generated_at: Option<DateTime<Utc>>,
    pub generation_status: GenerationStatus,
    pub generation_error: Option<String>,
    pub metadata: Option<String>,
    pub has_steganography: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "UPPERCASE")]
pub enum SourceType {
    Upload,
    Canvas,
}

impl SourceType {
    pub fn as_str(&self) -> &str {
        match self {
            SourceType::Upload => "UPLOAD",
            SourceType::Canvas => "CANVAS",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "UPLOAD" => Some(SourceType::Upload),
            "CANVAS" => Some(SourceType::Canvas),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "UPPERCASE")]
pub enum GenerationStatus {
    Pending,
    Success,
    Failed,
}

impl GenerationStatus {
    pub fn as_str(&self) -> &str {
        match self {
            GenerationStatus::Pending => "PENDING",
            GenerationStatus::Success => "SUCCESS",
            GenerationStatus::Failed => "FAILED",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "PENDING" => Some(GenerationStatus::Pending),
            "SUCCESS" => Some(GenerationStatus::Success),
            "FAILED" => Some(GenerationStatus::Failed),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FaviconAsset {
    pub id: String,
    pub favicon_id: String,
    pub r#type: AssetType,
    pub size: Option<String>,
    pub format: String,
    pub storage_key: String,
    pub mime_type: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "UPPERCASE")]
pub enum AssetType {
    Ico,
    Png,
    Svg,
}

impl AssetType {
    pub fn as_str(&self) -> &str {
        match self {
            AssetType::Ico => "ICO",
            AssetType::Png => "PNG",
            AssetType::Svg => "SVG",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "ICO" => Some(AssetType::Ico),
            "PNG" => Some(AssetType::Png),
            "SVG" => Some(AssetType::Svg),
            _ => None,
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FaviconDetailResponse {
    pub id: String,
    pub slug: String,
    pub title: Option<String>,
    pub target_domain: Option<String>,
    pub published_url: String,
    pub source_url: String,
    pub source_type: String,
    pub is_published: bool,
    pub created_at: String,
    pub generated_at: Option<String>,
    pub generation_status: String,
    pub generation_error: Option<String>,
    pub metadata: Option<String>,
    pub has_steganography: bool,
    pub assets: Vec<AssetResponse>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AssetResponse {
    pub id: String,
    pub r#type: String,
    pub size: Option<String>,
    pub format: String,
    pub mime_type: String,
    pub url: String,
}

impl AssetResponse {
    pub fn from_asset(asset: FaviconAsset) -> Self {
        AssetResponse {
            id: asset.id,
            r#type: asset.r#type.as_str().to_string(),
            size: asset.size,
            format: asset.format,
            mime_type: asset.mime_type,
            url: format!("/api/storage/{}", asset.storage_key),
        }
    }
}

impl FaviconDetailResponse {
    pub fn from_favicon_and_assets(favicon: Favicon, assets: Vec<FaviconAsset>) -> Self {
        FaviconDetailResponse {
            id: favicon.id.clone(),
            slug: favicon.slug,
            title: favicon.title,
            target_domain: favicon.target_domain,
            published_url: favicon.published_url,
            source_url: format!("/api/storage/sources/{}/original", favicon.id),
            source_type: favicon.source_type.as_str().to_string(),
            is_published: favicon.is_published,
            created_at: favicon.created_at.to_rfc3339(),
            generated_at: favicon.generated_at.map(|dt| dt.to_rfc3339()),
            generation_status: favicon.generation_status.as_str().to_string(),
            generation_error: favicon.generation_error,
            metadata: favicon.metadata,
            has_steganography: favicon.has_steganography,
            assets: assets.into_iter().map(AssetResponse::from_asset).collect(),
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DirectoryItem {
    pub id: String,
    pub slug: String,
    pub title: Option<String>,
    pub target_domain: Option<String>,
    pub published_url: String,
    pub created_at: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DirectoryResponse {
    pub items: Vec<DirectoryItem>,
    pub total: i64,
    pub page: i64,
    pub page_size: i64,
    pub total_pages: i64,
}

