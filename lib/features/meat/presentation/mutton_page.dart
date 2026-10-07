import 'package:flutter/material.dart';

import 'meat_catalog_page.dart';

const sampleMuttonCategories = [
  MeatCategory(
    id: 'mutton-curry-cuts',
    name: 'Mutton Curry Cuts',
    type: MeatType.mutton,
  ),
  MeatCategory(
    id: 'mutton-boneless',
    name: 'Mutton Boneless',
    type: MeatType.mutton,
  ),
  MeatCategory(id: 'mutton-keema', name: 'Mutton Keema', type: MeatType.mutton),
  MeatCategory(id: 'mutton-ribs', name: 'Mutton Ribs', type: MeatType.mutton),
  MeatCategory(id: 'mutton-chops', name: 'Mutton Chops', type: MeatType.mutton),
  MeatCategory(id: 'mutton-leg', name: 'Mutton Leg', type: MeatType.mutton),
  MeatCategory(id: 'mutton-liver', name: 'Mutton Liver', type: MeatType.mutton),
  MeatCategory(
    id: 'mutton-specialty-cuts',
    name: 'Mutton Head / Specialty Cuts',
    type: MeatType.mutton,
  ),
];

const sampleMuttonProducts = [
  MeatProduct(
    id: 'mutton-curry-cut',
    partnerId: 'mandapeta-fresh-meats',
    categoryId: 'mutton-curry-cuts',
    name: 'Mutton Curry Cut',
    description: 'Bone-in pieces, cut fresh for a slow-cooked curry.',
    weight: '500 g',
    price: 399,
    available: true,
    type: MeatType.mutton,
  ),
  MeatProduct(
    id: 'mutton-curry-cut-medium',
    partnerId: 'godavari-meat-house',
    categoryId: 'mutton-curry-cuts',
    name: 'Mutton Curry Cut',
    description: 'Medium-sized cuts with a good meat-to-bone ratio.',
    weight: '1 kg',
    price: 779,
    available: true,
    type: MeatType.mutton,
  ),
  MeatProduct(
    id: 'mutton-boneless',
    partnerId: 'mandapeta-fresh-meats',
    categoryId: 'mutton-boneless',
    name: 'Boneless Mutton',
    description: 'Tender boneless pieces, trimmed and ready to cook.',
    weight: '500 g',
    price: 499,
    available: true,
    type: MeatType.mutton,
  ),
  MeatProduct(
    id: 'mutton-keema',
    partnerId: 'godavari-meat-house',
    categoryId: 'mutton-keema',
    name: 'Mutton Keema',
    description: 'Freshly minced mutton, prepared to order.',
    weight: '500 g',
    price: 459,
    available: true,
    type: MeatType.mutton,
  ),
  MeatProduct(
    id: 'mutton-ribs',
    partnerId: 'mandapeta-fresh-meats',
    categoryId: 'mutton-ribs',
    name: 'Mutton Ribs',
    description: 'Meaty rib cuts suited to slow cooking.',
    weight: '500 g',
    price: 379,
    available: true,
    type: MeatType.mutton,
  ),
  MeatProduct(
    id: 'mutton-chops',
    partnerId: 'godavari-meat-house',
    categoryId: 'mutton-chops',
    name: 'Mutton Chops',
    description: 'Fresh rib chops, trimmed and cleaned.',
    weight: '500 g',
    price: 429,
    available: true,
    type: MeatType.mutton,
  ),
  MeatProduct(
    id: 'mutton-leg',
    partnerId: 'mandapeta-fresh-meats',
    categoryId: 'mutton-leg',
    name: 'Mutton Leg Pieces',
    description: 'Hearty leg cuts ideal for a rich, slow-cooked dish.',
    weight: '500 g',
    price: 419,
    available: true,
    type: MeatType.mutton,
  ),
  MeatProduct(
    id: 'mutton-liver',
    partnerId: 'godavari-meat-house',
    categoryId: 'mutton-liver',
    name: 'Mutton Liver',
    description: 'Freshly cleaned liver, packed for convenience.',
    weight: '250 g',
    price: 149,
    available: true,
    type: MeatType.mutton,
  ),
  MeatProduct(
    id: 'mutton-specialty-cuts',
    partnerId: 'mandapeta-fresh-meats',
    categoryId: 'mutton-specialty-cuts',
    name: 'Mutton Specialty Cuts',
    description: 'A selection of cleaned specialty cuts.',
    weight: '500 g',
    price: 249,
    available: false,
    type: MeatType.mutton,
  ),
];

class MuttonPage extends StatelessWidget {
  const MuttonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MeatCatalogPage(
      title: 'Mutton',
      type: MeatType.mutton,
      categories: sampleMuttonCategories,
      products: sampleMuttonProducts,
    );
  }
}
