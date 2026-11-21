import '../catalog_item.dart';

// data dummy buat testing halaman pencarian (screenshot & video trello)
// cara pakai: ganti `const CatalogScreen()` jadi
// `const CatalogScreen(items: dummyCatalogItems)`
const dummyCatalogItems = <CatalogItem>[
  CatalogItem(
    id: 'dummy-1',
    name: 'Calculator Casio FX-991EX',
    price: 120000,
    category: 'Elektronik',
    condition: 'Bekas Kondisi Baik',
    location: 'Padang Bulan, Medan',
    description: 'Kalkulator scientific, masih normal semua tombolnya.',
    sellerName: 'Rina',
    sellerPhone: '081234567890',
  ),
  CatalogItem(
    id: 'dummy-2',
    name: 'Kalkulator Casio MX-12B',
    price: 45000,
    category: 'Elektronik',
    condition: 'Bekas Ada Minus',
    location: 'Dr. Mansyur, Medan',
    description: 'Kalkulator biasa, layar agak baret dikit.',
    sellerName: 'Budi',
    sellerPhone: '081298765432',
  ),
  CatalogItem(
    id: 'dummy-3',
    name: 'Buku Kalkulus Purcell Jilid 1',
    price: 60000,
    category: 'Buku',
    condition: 'Bekas Kondisi Baik',
    location: 'Setia Budi, Medan',
    description: 'Buku kalkulus edisi 9, ada sedikit coretan stabilo.',
    sellerName: 'Sari',
    sellerPhone: '081377788899',
  ),
  CatalogItem(
    id: 'dummy-4',
    name: 'Headset Sony MDR-ZX110',
    price: 85000,
    category: 'Elektronik',
    condition: 'Baru',
    location: 'Pintu 4 USU, Medan',
    description: 'Headset baru, masih segel.',
    sellerName: 'Andi',
    sellerPhone: '081211122233',
  ),
  CatalogItem(
    id: 'dummy-5',
    name: 'Jaket Hoodie Hitam',
    price: 75000,
    category: 'Fashion',
    condition: 'Bekas Kondisi Baik',
    location: 'Jamin Ginting, Medan',
    description: 'Hoodie ukuran L, baru dipakai 2 kali.',
    sellerName: 'Dewi',
    sellerPhone: '081255566677',
  ),
];