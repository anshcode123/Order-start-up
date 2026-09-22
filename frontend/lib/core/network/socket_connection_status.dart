/// Shared by both real-time providers (customer order tracking and the
/// Restaurant Admin dashboard) so the UI can show one consistent
/// "connecting/live/offline" indicator regardless of which side it's on.
enum SocketConnectionStatus { connecting, connected, disconnected, error }
