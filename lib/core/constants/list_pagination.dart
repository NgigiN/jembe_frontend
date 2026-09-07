/// Page size for the ONLINE cursor-based infinite-scroll list path (audit
/// P3-02a), pinned to the backend's default & maximum `?limit` of 500.
///
/// Because it equals the server default, an account whose whole list fits in
/// one page (≤500 rows) is fetched in a single request and immediately
/// reports `hasReachedMax` — behaving exactly as the pre-pagination one-shot
/// fetch did. Only accounts with more than 500 rows page a second time.
///
/// The blocs derive `hasReachedMax = returned.length < kOnlineListPageSize`,
/// so this constant is the single source of truth for the "was this a full
/// page?" decision across activity, input, revenue and harvest.
const int kOnlineListPageSize = 500;
