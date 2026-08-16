///|
pub extend Thunk with Source::{id, incoming_edges}

///|
pub extend Cell with Source::{id, incoming_edges}

///|
pub extend Thunk with Eq::{not_equal, equal}

///|
pub extend Cell with Eq::{not_equal, equal}

///|
pub extend Thunk with Hash::{hash, hash_combine}

///|
pub extend Cell with Hash::{hash, hash_combine}

///|
extend Thunk with Target::{update}
