class QuotationModel {
  final String id;
  final String customerName;
  final String customerPhone;
  final String projectAddress;
  final String notes;
  final DateTime createdAt;
  final double subtotal;
  final double grandTotal;

  QuotationModel({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.projectAddress,
    required this.notes,
    required this.createdAt,
    this.subtotal = 0.0,
    this.grandTotal = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'projectAddress': projectAddress,
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'subtotal': subtotal,
      'grandTotal': grandTotal,
    };
  }

  factory QuotationModel.fromMap(Map<String, dynamic> map) {
    return QuotationModel(
      id: map['id'],
      customerName: map['customerName'],
      customerPhone: map['customerPhone'],
      projectAddress: map['projectAddress'],
      notes: map['notes'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      subtotal: map['subtotal'] ?? 0.0,
      grandTotal: map['grandTotal'] ?? 0.0,
    );
  }
}

class QuotationItemModel {
  final String id;
  final String quotationId;
  final String designJson;
  final double itemTotal;

  QuotationItemModel({
    required this.id,
    required this.quotationId,
    required this.designJson,
    required this.itemTotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quotationId': quotationId,
      'designJson': designJson,
      'itemTotal': itemTotal,
    };
  }

  factory QuotationItemModel.fromMap(Map<String, dynamic> map) {
    return QuotationItemModel(
      id: map['id'],
      quotationId: map['quotationId'],
      designJson: map['designJson'],
      itemTotal: map['itemTotal'],
    );
  }
}
