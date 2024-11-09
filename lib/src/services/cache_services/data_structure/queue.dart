/// A priority queue implementation using a binary heap.
///
/// This class provides a data structure that maintains a collection of elements
/// in a priority order defined by a [Comparator]. It uses a binary heap to
/// efficiently manage the priority queue operations:
/// - [add]: Adds an element to the priority queue, maintaining the heap property.
/// - [removeFirst]: Removes and returns the highest priority element from the queue.
///   Throws an exception if the queue is empty.
/// - [isEmpty]: Checks if the priority queue is empty.
///
/// The PriorityQueue supports any type [T] and requires a [Comparator] to
/// determine the priority of elements.
///
/// Example usage:
/// ```dart
/// // Example comparator for integers (min-heap).
/// int minHeapComparator(int a, int b) => a - b;
///
/// // Create a PriorityQueue of integers (min-heap).
/// PriorityQueue<int> pq = PriorityQueue<int>(minHeapComparator);
/// pq.add(5);
/// pq.add(3);
/// pq.add(7);
///
/// print(pq.removeFirst()); // Output: 3
/// pq.add(1);
/// print(pq.removeFirst()); // Output: 1
/// print(pq.removeFirst()); // Output: 5
/// ```
class PriorityQueue<T> {
  /// Internal list to store elements of the queue.
  final List<T> _queue = [];

  /// Comparator function to determine priority.
  final Comparator<T> _comparator;

  /// Constructs a priority queue with the specified [comparator].
  ///
  /// The [comparator] function defines the priority order of elements in the
  /// priority queue. It should return a negative integer if [a] should come
  /// before [b], a positive integer if [a] should come after [b], and zero if
  /// [a] and [b] have equal priority.
  PriorityQueue(this._comparator);

  /// Adds an [element] to the priority queue.
  ///
  /// This method adds the [element] to the end of the internal list and then
  /// restores the heap property by moving the new element up in the heap.
  void add(T element) {
    _queue.add(element); // Add element to the end of the list.
    _heapifyUp(_queue.length -
        1); // Restore heap property by moving the new element up.
  }

  /// Removes and returns the highest priority element from the queue.
  ///
  /// This method removes the element at the root of the heap (highest priority)
  /// and restores the heap property by moving the new root element down.
  /// Throws an exception if the queue is empty.
  T removeFirst() {
    if (_queue.isEmpty) {
      throw Exception('Priority queue is empty');
    }
    final first = _queue.first; // Get the first element (highest priority).
    _queue.first = _queue.last; // Move the last element to the first position.
    _queue.removeLast(); // Remove the last element from the list.
    _heapifyDown(
        0); // Restore heap property by moving the new first element down.
    return first;
  }

  /// Checks if the priority queue is empty.
  ///
  /// Returns `true` if the priority queue contains no elements, `false` otherwise.
  bool get isEmpty => _queue.isEmpty;

  /// Restores the heap property from the specified [index] upwards.
  ///
  /// This method restores the heap property from the element at [index] upwards
  /// in the heap by recursively swapping elements with their parent until the
  /// heap property is satisfied.
  void _heapifyUp(int index) {
    if (index == 0) return; // Base case: reached the root of the heap.
    final parentIndex = (index - 1) ~/ 2; // Calculate parent index.
    if (_comparator(_queue[parentIndex], _queue[index]) <= 0) {
      return;
    }
    // Parent is smaller or equal, heap property is restored.
    _swap(parentIndex, index); // Swap parent and current element.
    _heapifyUp(parentIndex); // Recursively heapify upwards.
  }

  /// Restores the heap property from the specified [index] downwards.
  ///
  /// This method restores the heap property from the element at [index] downwards
  /// in the heap by recursively swapping elements with their smallest child
  /// until the heap property is satisfied.
  void _heapifyDown(int index) {
    final leftChildIndex = 2 * index + 1; // Calculate left child index.
    final rightChildIndex = 2 * index + 2; // Calculate right child index.
    var smallest = index; // Assume current element is the smallest.

    // Check if left child exists and is smaller than current smallest.
    if (leftChildIndex < _queue.length &&
        _comparator(_queue[leftChildIndex], _queue[smallest]) < 0) {
      smallest = leftChildIndex;
    }

    // Check if right child exists and is smaller than current smallest.
    if (rightChildIndex < _queue.length &&
        _comparator(_queue[rightChildIndex], _queue[smallest]) < 0) {
      smallest = rightChildIndex;
    }

    // If smallest element is not the current element, swap and recursively heapify downwards.
    if (smallest != index) {
      _swap(smallest, index);
      _heapifyDown(smallest);
    }
  }

  /// Swaps elements at indices [i] and [j] in the internal queue.
  ///
  /// This method swaps the elements at indices [i] and [j] in the internal list
  /// representing the priority queue.
  void _swap(int i, int j) {
    final temp = _queue[i];
    _queue[i] = _queue[j];
    _queue[j] = temp;
  }
}
