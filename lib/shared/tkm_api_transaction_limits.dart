/// HTTP body limits for Takamaka wallet transaction API (multipart `/transaction`).
library;

/// Maximum request body size accepted by the API (bytes).
const int kTkmMaxTransactionApiBodyBytes = 6 * 1024 * 1024;

/// Reserved for multipart boundaries, disposition headers, and final CRLF.
const int kTkmMultipartEncodingOverheadBytes = 16 * 1024;

/// Maximum UTF-8 length allowed for the serialized `tx` field (safe vs [kTkmMaxTransactionApiBodyBytes]).
const int kTkmMaxTransactionTxUtf8Bytes =
    kTkmMaxTransactionApiBodyBytes - kTkmMultipartEncodingOverheadBytes;
