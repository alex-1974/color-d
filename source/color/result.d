/++
 Shared public Result vocabulary for fallible color-boundary operations.

 Scalar color mathematics remains value-based. This module is for public
 parsing, storage, and other operations that can fail with a library-owned
 error domain.
+/
module color.result;

public import error_d : Result;

/// Result carrying a value or a color-d-specific error.
alias ColorResult(T, E) = Result!(T, E);

/// Result for a fallible operation with no value on success.
alias ColorVoidResult(E) = Result!(void, E);
