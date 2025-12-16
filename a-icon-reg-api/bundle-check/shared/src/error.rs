// Re-export HandlerError from the SDK
pub use rust_edge_gateway_sdk::HandlerError;

// Macro to convert database errors
#[macro_export]
macro_rules! db_err {
    ($e:expr) => {
        $e.map_err(|e| $crate::error::HandlerError::DatabaseError(e.to_string()))
    };
}

