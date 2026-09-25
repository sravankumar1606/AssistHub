import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ServiceCategory {
  final String id;
  final String name;
  final String icon;
  final String description;
  final int employeeCount;

  ServiceCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.employeeCount = 0,
  });

  factory ServiceCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceCategory(
      id: doc.id,
      name: data['name'] ?? '',
      icon: data['icon'] ?? '',
      description: data['description'] ?? '',
      employeeCount: data['employeeCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'icon': icon,
      'description': description,
      'employeeCount': employeeCount,
    };
  }

  IconData get iconData {
    switch (icon) {
      case 'cleaning':
        return Icons.cleaning_services;
      case 'plumbing':
        return Icons.plumbing;
      case 'electrical':
        return Icons.electrical_services;
      case 'painting':
        return Icons.format_paint;
      case 'carpentry':
        return Icons.carpenter;
      case 'gardening':
        return Icons.grass;
      case 'moving':
        return Icons.local_shipping;
      case 'appliance':
        return Icons.kitchen;
      case 'pest_control':
        return Icons.pest_control;
      case 'hvac':
        return Icons.ac_unit;
      default:
        return Icons.home_repair_service;
    }
  }
}

// Predefined service categories
class ServiceCategories {
  static List<ServiceCategory> get all => [
        ServiceCategory(
          id: 'cleaning',
          name: 'Cleaning',
          icon: 'cleaning',
          description: 'Home & office cleaning services',
        ),
        ServiceCategory(
          id: 'plumbing',
          name: 'Plumbing',
          icon: 'plumbing',
          description: 'Plumbing repair & installation',
        ),
        ServiceCategory(
          id: 'electrical',
          name: 'Electrical',
          icon: 'electrical',
          description: 'Electrical repair & wiring',
        ),
        ServiceCategory(
          id: 'painting',
          name: 'Painting',
          icon: 'painting',
          description: 'Interior & exterior painting',
        ),
        ServiceCategory(
          id: 'carpentry',
          name: 'Carpentry',
          icon: 'carpentry',
          description: 'Furniture repair & custom work',
        ),
        ServiceCategory(
          id: 'gardening',
          name: 'Gardening',
          icon: 'gardening',
          description: 'Lawn care & landscaping',
        ),
        ServiceCategory(
          id: 'moving',
          name: 'Moving',
          icon: 'moving',
          description: 'Packing & moving services',
        ),
        ServiceCategory(
          id: 'appliance',
          name: 'Appliance Repair',
          icon: 'appliance',
          description: 'Home appliance repair',
        ),
        ServiceCategory(
          id: 'pest_control',
          name: 'Pest Control',
          icon: 'pest_control',
          description: 'Pest removal & prevention',
        ),
        ServiceCategory(
          id: 'hvac',
          name: 'HVAC',
          icon: 'hvac',
          description: 'AC & heating services',
        ),
      ];
}
