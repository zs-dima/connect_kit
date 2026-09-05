/// Whether a URI is served over TLS.
extension UriX on Uri {
  /// True for `https` and `wss`, the two schemes the transport pins a trust set for.
  bool get ssl => ['https', 'wss'].contains(scheme);
}
