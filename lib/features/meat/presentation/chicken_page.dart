import 'package:flutter/material.dart';

import 'meat_catalog_page.dart';

const sampleChickenCategories = [
  MeatCategory(
    id: 'whole-chicken',
    name: 'Whole Chicken',
    type: MeatType.chicken,
    icon: Icons.set_meal_rounded,
  ),
  MeatCategory(
    id: 'chicken-curry-cuts',
    name: 'Chicken Curry Cuts',
    type: MeatType.chicken,
  ),
  MeatCategory(
    id: 'boneless-chicken',
    name: 'Boneless Chicken',
    type: MeatType.chicken,
  ),
  MeatCategory(
    id: 'chicken-breast',
    name: 'Chicken Breast',
    type: MeatType.chicken,
    icon: Icons.lunch_dining_rounded,
  ),
  MeatCategory(
    id: 'chicken-wings',
    name: 'Chicken Wings',
    type: MeatType.chicken,
    icon: Icons.set_meal_rounded,
  ),
  MeatCategory(
    id: 'chicken-legs',
    name: 'Chicken Legs / Drumsticks',
    type: MeatType.chicken,
  ),
  MeatCategory(
    id: 'chicken-liver',
    name: 'Chicken Liver',
    type: MeatType.chicken,
  ),
  MeatCategory(
    id: 'chicken-gizzard',
    name: 'Chicken Gizzard',
    type: MeatType.chicken,
  ),
  MeatCategory(
    id: 'chicken-mince',
    name: 'Chicken Mince',
    type: MeatType.chicken,
  ),
];

const sampleChickenProducts = [
  MeatProduct(
    id: 'whole-chicken-cleaned',
    partnerId: 'mandapeta-fresh-meats',
    categoryId: 'whole-chicken',
    name: 'Whole Chicken, Skinless',
    description: 'Cleaned and dressed, ready to cook.',
    weight: '1 kg',
    price: 249,
    available: true,
    type: MeatType.chicken,
  ),
  MeatProduct(
    id: 'whole-chicken-curry-cut',
    partnerId: 'godavari-meat-house',
    categoryId: 'whole-chicken',
    name: 'Whole Chicken, Curry Cut',
    description: 'Freshly cut into convenient cooking pieces.',
    weight: '1 kg',
    price: 269,
    available: true,
    type: MeatType.chicken,
  ),
  MeatProduct(
    id: 'chicken-curry-cut-medium',
    partnerId: 'mandapeta-fresh-meats',
    categoryId: 'chicken-curry-cuts',
    name: 'Chicken Curry Cut',
    description: 'Bone-in pieces cut for everyday curries.',
    weight: '500 g',
    price: 145,
    available: true,
    type: MeatType.chicken,
  ),
  MeatProduct(
    id: 'chicken-curry-cut-small',
    partnerId: 'godavari-meat-house',
    categoryId: 'chicken-curry-cuts',
    name: 'Small Curry Cut Chicken',
    description: 'Smaller pieces for a flavourful Andhra curry.',
    weight: '500 g',
    price: 155,
    available: true,
    type: MeatType.chicken,
  ),
  MeatProduct(
    id: 'chicken-boneless',
    partnerId: 'mandapeta-fresh-meats',
    categoryId: 'boneless-chicken',
    name: 'Boneless Chicken',
    description: 'Tender, boneless chicken pieces.',
    weight: '500 g',
    price: 229,
    available: true,
    type: MeatType.chicken,
  ),
  MeatProduct(
    id: 'chicken-breast',
    partnerId: 'godavari-meat-house',
    categoryId: 'chicken-breast',
    name: 'Chicken Breast Fillet',
    description: 'Lean, boneless cuts, trimmed and ready to cook.',
    weight: '500 g',
    price: 239,
    available: true,
    type: MeatType.chicken,
  ),
  MeatProduct(
    id: 'chicken-wings',
    partnerId: 'mandapeta-fresh-meats',
    categoryId: 'chicken-wings',
    name: 'Chicken Wings',
    description: 'Fresh wings, ideal for grilling or frying.',
    weight: '500 g',
    price: 159,
    available: true,
    type: MeatType.chicken,
  ),
  MeatProduct(
    id: 'chicken-drumsticks',
    partnerId: 'godavari-meat-house',
    categoryId: 'chicken-legs',
    name: 'Chicken Leg Pieces',
    description: 'Juicy, meaty legs with skin removed.',
    weight: '500 g',
    price: 179,
    available: true,
    type: MeatType.chicken,
  ),
  MeatProduct(
    id: 'chicken-liver',
    partnerId: 'mandapeta-fresh-meats',
    categoryId: 'chicken-liver',
    name: 'Chicken Liver',
    description: 'Fresh, cleaned liver pieces.',
    weight: '250 g',
    price: 69,
    available: true,
    type: MeatType.chicken,
  ),
  MeatProduct(
    id: 'chicken-gizzard',
    partnerId: 'godavari-meat-house',
    categoryId: 'chicken-gizzard',
    name: 'Chicken Gizzard',
    description: 'Cleaned and prepared for your favourite recipes.',
    weight: '250 g',
    price: 79,
    available: true,
    type: MeatType.chicken,
  ),
  MeatProduct(
    id: 'chicken-mince',
    partnerId: 'mandapeta-fresh-meats',
    categoryId: 'chicken-mince',
    name: 'Chicken Mince',
    description: 'Freshly minced boneless chicken.',
    weight: '500 g',
    price: 219,
    available: true,
    type: MeatType.chicken,
  ),
];

class ChickenPage extends StatelessWidget {
  const ChickenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MeatCatalogPage(
      title: 'Chicken',
      type: MeatType.chicken,
      categories: sampleChickenCategories,
      products: sampleChickenProducts,
    );
  }
}
