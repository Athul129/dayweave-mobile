class TaskMutationQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> add<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }
}
