//! The one integration binary. Add submodules here; never add sibling files under
//! `tests/`, because cargo relinks the library once per file there and runs test binaries
//! sequentially. Measured on cargo itself: 3x faster compile, 5x smaller artifacts.

// Tests are the one place bare unwrap is fine — a panic IS the failure report.
#![allow(clippy::unwrap_used)]

mod smoke;
