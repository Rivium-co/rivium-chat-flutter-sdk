/// Represents an e-commerce order
class Order {
  final String id;
  final String orderNumber;
  final String productName;
  final String productImage;
  final double price;
  final int quantity;
  final OrderStatus status;
  final String sellerId;
  final String sellerName;
  final String buyerId;
  final String buyerName;
  final DateTime createdAt;
  final String? chatRoomId;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.productName,
    required this.productImage,
    required this.price,
    required this.quantity,
    required this.status,
    required this.sellerId,
    required this.sellerName,
    required this.buyerId,
    required this.buyerName,
    required this.createdAt,
    this.chatRoomId,
  });

  double get total => price * quantity;

  String get statusText {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.shipped:
        return 'Shipped';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Order copyWith({
    String? id,
    String? orderNumber,
    String? productName,
    String? productImage,
    double? price,
    int? quantity,
    OrderStatus? status,
    String? sellerId,
    String? sellerName,
    String? buyerId,
    String? buyerName,
    DateTime? createdAt,
    String? chatRoomId,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      createdAt: createdAt ?? this.createdAt,
      chatRoomId: chatRoomId ?? this.chatRoomId,
    );
  }
}

enum OrderStatus {
  pending,
  confirmed,
  shipped,
  delivered,
  cancelled,
}

/// Mock data for demo purposes
class MockOrders {
  static List<Order> getOrdersForUser(String userId, String role) {
    final allOrders = [
      Order(
        id: '001',
        orderNumber: 'ORD-2024-001',
        productName: 'MacBook Pro 14"',
        productImage: 'https://picsum.photos/seed/macbook/200',
        price: 1999.00,
        quantity: 1,
        status: OrderStatus.shipped,
        sellerId: 'seller-001',
        sellerName: 'Sarah Seller',
        buyerId: 'buyer-001',
        buyerName: 'John Buyer',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Order(
        id: '002',
        orderNumber: 'ORD-2024-002',
        productName: 'Wireless Headphones',
        productImage: 'https://picsum.photos/seed/headphones/200',
        price: 299.00,
        quantity: 2,
        status: OrderStatus.confirmed,
        sellerId: 'seller-001',
        sellerName: 'Sarah Seller',
        buyerId: 'buyer-001',
        buyerName: 'John Buyer',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Order(
        id: '003',
        orderNumber: 'ORD-2024-003',
        productName: 'Smart Watch Series 9',
        productImage: 'https://picsum.photos/seed/watch/200',
        price: 399.00,
        quantity: 1,
        status: OrderStatus.pending,
        sellerId: 'seller-001',
        sellerName: 'Sarah Seller',
        buyerId: 'buyer-001',
        buyerName: 'John Buyer',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      Order(
        id: '004',
        orderNumber: 'ORD-2024-004',
        productName: 'Mechanical Keyboard',
        productImage: 'https://picsum.photos/seed/keyboard/200',
        price: 149.00,
        quantity: 1,
        status: OrderStatus.delivered,
        sellerId: 'seller-001',
        sellerName: 'Sarah Seller',
        buyerId: 'buyer-001',
        buyerName: 'John Buyer',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Order(
        id: '005',
        orderNumber: 'ORD-2024-005',
        productName: '4K Monitor 27"',
        productImage: 'https://picsum.photos/seed/monitor/200',
        price: 549.00,
        quantity: 1,
        status: OrderStatus.shipped,
        sellerId: 'seller-001',
        sellerName: 'Sarah Seller',
        buyerId: 'buyer-001',
        buyerName: 'John Buyer',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];

    if (role == 'buyer') {
      return allOrders.where((o) => o.buyerId == userId).toList();
    } else {
      return allOrders.where((o) => o.sellerId == userId).toList();
    }
  }
}
