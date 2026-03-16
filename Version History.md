# Version History

## 1.0.1 (2026-03-16)
- **Radar Filter**: Expanded the Radar view to include due and overdue items.
- **UI Improvements**:
    - Increased Quick List selection bar height by 50% for better mobile ergonomics.
    - Widened the origin color indicators in the "Due Tasks" view for better visibility on curved screens.
    - Simplified the "Due Tasks" view by hiding the redundant filter and tag bars.
    - Updated DatePicker to use English ISO-8601 (en_GB) format, starting weeks on Monday.
- **Data Persistence**: Implemented global list order persistence across app restarts.
- **Stability and Fixes**:
    - Rebuilt recurrence logic using "Floating UTC" to fix timezone-related monthly roll-over drift.
    - Added automatic "Start Date" offsetting for recurring tasks.
    - Hardened `DataManager` against ghost list creation in the RAM layer.
    - Fixed several string interpolation bugs in the Settings and Sync Log pages.
    - Removed redundant drag handles in the "Manage Lists" page.
- **DevOps**:
    - Performed Flutter framework upgrade and dependency audit.
    - Added `package_info_plus` for in-app version display.

## 1.0.0 (Initial Release)
- Initial commit of Simple ToDo frontend and MVP.
- Features: Local and CalDAV list synchronization, basic todo management, priority support, and tagging.
