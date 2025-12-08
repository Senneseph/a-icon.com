use crate::error::ApiResult;

/// Parse multipart form data from request body
pub fn parse_multipart(body: &[u8], boundary: &str) -> ApiResult<MultipartData> {
    let boundary_bytes = format!("--{}", boundary).into_bytes();
    let mut parts = Vec::new();
    let mut current_pos = 0;

    while current_pos < body.len() {
        // Find next boundary
        if let Some(boundary_start) = find_subsequence(&body[current_pos..], &boundary_bytes) {
            let absolute_boundary_start = current_pos + boundary_start;
            
            // Skip the boundary line
            let content_start = absolute_boundary_start + boundary_bytes.len();
            if content_start >= body.len() {
                break;
            }

            // Check if this is the final boundary
            if content_start + 2 <= body.len() && &body[content_start..content_start + 2] == b"--" {
                break;
            }

            // Skip to next line (after \r\n or \n)
            let header_start = skip_newline(&body[content_start..]).map(|s| content_start + s).unwrap_or(content_start);

            // Find the next boundary to determine where this part ends
            let next_boundary_pos = find_subsequence(&body[header_start..], &boundary_bytes)
                .map(|p| header_start + p)
                .unwrap_or(body.len());

            // Parse headers and content
            if let Some(part) = parse_part(&body[header_start..next_boundary_pos])? {
                parts.push(part);
            }

            current_pos = next_boundary_pos;
        } else {
            break;
        }
    }

    Ok(MultipartData { parts })
}

fn find_subsequence(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    haystack.windows(needle.len()).position(|window| window == needle)
}

fn skip_newline(data: &[u8]) -> Option<usize> {
    if data.starts_with(b"\r\n") {
        Some(2)
    } else if data.starts_with(b"\n") {
        Some(1)
    } else {
        None
    }
}

fn parse_part(data: &[u8]) -> ApiResult<Option<MultipartPart>> {
    // Find the blank line that separates headers from content
    let separator = b"\r\n\r\n";
    let separator_pos = find_subsequence(data, separator)
        .or_else(|| find_subsequence(data, b"\n\n").map(|p| p));

    if separator_pos.is_none() {
        return Ok(None);
    }

    let sep_pos = separator_pos.unwrap();
    let headers_data = &data[..sep_pos];
    let content_start = sep_pos + if data[sep_pos..].starts_with(b"\r\n\r\n") { 4 } else { 2 };
    
    // Remove trailing \r\n from content
    let mut content_end = data.len();
    if content_end >= 2 && &data[content_end - 2..] == b"\r\n" {
        content_end -= 2;
    } else if content_end >= 1 && data[content_end - 1] == b'\n' {
        content_end -= 1;
    }
    
    let content = data[content_start..content_end].to_vec();

    // Parse headers
    let headers_str = String::from_utf8_lossy(headers_data);
    let mut name = None;
    let mut filename = None;
    let mut content_type = None;

    for line in headers_str.lines() {
        if line.to_lowercase().starts_with("content-disposition:") {
            // Parse name and filename from Content-Disposition header
            for part in line.split(';') {
                let part = part.trim();
                if part.starts_with("name=") {
                    name = Some(part[5..].trim_matches('"').to_string());
                } else if part.starts_with("filename=") {
                    filename = Some(part[9..].trim_matches('"').to_string());
                }
            }
        } else if line.to_lowercase().starts_with("content-type:") {
            content_type = Some(line.split(':').nth(1).unwrap_or("").trim().to_string());
        }
    }

    if let Some(name) = name {
        Ok(Some(MultipartPart {
            name,
            filename,
            content_type,
            content,
        }))
    } else {
        Ok(None)
    }
}

pub struct MultipartData {
    pub parts: Vec<MultipartPart>,
}

impl MultipartData {
    pub fn get_field(&self, name: &str) -> Option<String> {
        self.parts
            .iter()
            .find(|p| p.name == name)
            .and_then(|p| String::from_utf8(p.content.clone()).ok())
    }

    pub fn get_file(&self, name: &str) -> Option<&MultipartPart> {
        self.parts.iter().find(|p| p.name == name && p.filename.is_some())
    }
}

pub struct MultipartPart {
    pub name: String,
    pub filename: Option<String>,
    pub content_type: Option<String>,
    pub content: Vec<u8>,
}

/// Generate a short URL-safe ID (similar to nanoid)
pub fn generate_short_id(length: usize) -> String {
    use uuid::Uuid;
    let uuid = Uuid::new_v4();
    let uuid_str = uuid.to_string().replace("-", "");
    uuid_str[..length.min(uuid_str.len())].to_string()
}

