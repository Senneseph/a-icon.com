use thiserror::Error;

#[derive(Error, Debug)]
pub enum ApiError {
    #[error("Bad request: {0}")]
    BadRequest(String),

    #[error("Not found: {0}")]
    NotFound(String),

    #[error("Unauthorized: {0}")]
    Unauthorized(String),

    #[error("Internal server error: {0}")]
    InternalError(String),

    #[error("Database error: {0}")]
    DatabaseError(#[from] rusqlite::Error),

    #[error("Storage error: {0}")]
    StorageError(String),

    #[error("Validation error: {0}")]
    ValidationError(String),
}

impl ApiError {
    pub fn status_code(&self) -> u16 {
        match self {
            ApiError::BadRequest(_) => 400,
            ApiError::NotFound(_) => 404,
            ApiError::Unauthorized(_) => 401,
            ApiError::InternalError(_) => 500,
            ApiError::DatabaseError(_) => 500,
            ApiError::StorageError(_) => 500,
            ApiError::ValidationError(_) => 400,
        }
    }

    pub fn to_json(&self) -> serde_json::Value {
        serde_json::json!({
            "statusCode": self.status_code(),
            "message": self.to_string(),
            "error": match self {
                ApiError::BadRequest(_) => "Bad Request",
                ApiError::NotFound(_) => "Not Found",
                ApiError::Unauthorized(_) => "Unauthorized",
                _ => "Internal Server Error",
            }
        })
    }
}

pub type ApiResult<T> = Result<T, ApiError>;

