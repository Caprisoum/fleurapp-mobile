import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const FleurApp());
}

class FleurApp extends StatelessWidget {
  const FleurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FleurApp Caisse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Vert plus profond/premium
          surface: const Color(0xFFF8FAF8), // Background subtil
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFFD4AF37), // Or (Premium)
        ),
        useMaterial3: true,
        fontFamily: 'Inter', // Utiliser une police moderne (déjà configurée)
        cardTheme: CardTheme(
          elevation: 4,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: const POSScreen(),
    );
  }
}

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  List<dynamic> products = [];
  List<Map<String, dynamic>> cart = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  // --- API CALL: Récupérer les produits depuis Node.js ---
  Future<void> _fetchProducts() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:3000/api/produits'));
      if (response.statusCode == 200) {
        setState(() {
          products = json.decode(response.body);
          // Add custom price product
          products.insert(0, {
            "id": "custom",
            "name": "Prix Libre (Sur-mesure)",
            "price_ttc": "0.00",
            "vat_rate": "20.00",
            "color_code": "#FFF9C4"
          });
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load products');
      }
    } catch (e) {
      print('Erreur réseau (GET /api/produits): $e');
      setState(() => isLoading = false);
      // Fallback data in case the backend is not running yet
      setState(() {
        products = [
          {"id": "custom", "name": "Prix Libre (Sur-mesure)", "price_ttc": "0.00", "vat_rate": "20.00", "color_code": "#FFF9C4"},
          {"id": "1", "name": "Bouquet de Roses", "price_ttc": "35.00", "vat_rate": "20.00", "category_name": "Bouquets", "color_code": "#ffcdd2"},
          {"id": "2", "name": "Ficus", "price_ttc": "40.00", "vat_rate": "10.00", "category_name": "Plantes", "color_code": "#c8e6c9"},
        ];
      });
    }
  }

  void addToCart(dynamic product) {
    if (product['id'] == 'custom') {
      _showCustomPriceDialog();
      return;
    }
    
    setState(() {
      final index = cart.indexWhere((item) => item['id'] == product['id']);
      if (index >= 0) {
        cart[index]['quantity']++;
      } else {
        cart.add({
          'id': product['id'],
          'name': product['name'],
          'price_ttc': product['price_ttc'],
          'vat_rate': product['vat_rate'],
          'quantity': 1,
        });
      }
    });
  }

  void _showCustomPriceDialog() {
    final TextEditingController priceController = TextEditingController();
    final TextEditingController nameController = TextEditingController(text: "Bouquet Sur-mesure");
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saisir un Prix Libre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Description (Optionnel)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Prix TTC (€)', suffixIcon: Icon(Icons.euro)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(priceController.text.replaceAll(',', '.'));
              if (price != null && price > 0) {
                setState(() {
                  cart.add({
                    'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    'name': nameController.text.isEmpty ? 'Prix Libre' : nameController.text,
                    'price_ttc': price.toStringAsFixed(2),
                    'vat_rate': '20.00',
                    'quantity': 1,
                  });
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  double get cartTotal {
    return cart.fold(0, (sum, item) => sum + (double.parse(item['price_ttc'].toString()) * item['quantity']));
  }

  // --- API CALL: Valider l'encaissement et générer le ticket NF525 ---
  Future<void> _processCheckout(String paymentMethod) async {
    if (cart.isEmpty) return;
    
    // Close payment dialog
    Navigator.pop(context);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/commandes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'cartItems': cart,
          'mode_paiement': paymentMethod
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Encaissement Validé ✅', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Commande N°: ${data['orderId']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Montant total payé : ${data['totalTTC']} €', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 16),
                const Text('Signature Cryptographique (Norme NF525) :'),
                SelectableText(
                  data['hash'],
                  style: const TextStyle(fontFamily: 'monospace', color: Colors.blueGrey, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() => cart.clear());
                  Navigator.pop(context);
                },
                child: const Text('Nouvelle Vente'),
              )
            ],
          ),
        );
      } else {
        throw Exception('Erreur lors de la validation du panier');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'encaissement: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showPaymentDialog() {
    if (cart.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir le moyen de paiement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.credit_card),
              label: const Text('Carte Bancaire'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              onPressed: () => _processCheckout('Carte Bancaire'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.money),
              label: const Text('Espèces'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              onPressed: () => _processCheckout('Espèces'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text('Chèque'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              onPressed: () => _processCheckout('Chèque'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FleurApp', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, color: Color(0xFF2E7D32)),
            tooltip: 'Administration',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminScreen()));
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 16, left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.storefront, color: Color(0xFF2E7D32), size: 20),
                SizedBox(width: 8),
                Text('Boutique Principale', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
      body: Row(
        children: [
          // Grille des produits
          Expanded(
            flex: 3,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final p = products[index];
                      
                      Color cardColor = Colors.green.shade100; // Default
                      if (p['color_code'] != null) {
                         String hex = p['color_code'].toString().replaceAll('#', '0xFF');
                         try { cardColor = Color(int.parse(hex)); } catch(e) {}
                      }
                      
                      return InkWell(
                        onTap: () => addToCart(p),
                        child: Card(
                          color: cardColor,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    p['id'] == 'custom' ? Icons.edit : Icons.local_florist, 
                                    size: 40, 
                                    color: Colors.black87
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  p['name'] ?? '',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.2),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white, 
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                                    ]
                                  ),
                                  child: Text(
                                    p['id'] == 'custom' ? 'Saisir' : '${p['price_ttc']} €', 
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          if (isDesktop) const VerticalDivider(width: 1),

          // Panier latéral
          if (isDesktop)
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(-5, 0))],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shopping_bag_outlined, color: Color(0xFF2E7D32)),
                        SizedBox(width: 8),
                        Text('Commande en cours', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: cart.isEmpty
                        ? const Center(child: Text('Panier vide', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                        itemCount: cart.length,
                        itemBuilder: (context, index) {
                          final item = cart[index];
                          final total = double.parse(item['price_ttc'].toString()) * item['quantity'];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item['name'], maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${item['quantity']} x ${item['price_ttc']} €'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${total.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      if (item['quantity'] > 1) {
                                        item['quantity']--;
                                      } else {
                                        cart.removeAt(index);
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total TTC :', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('${cartTotal.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: cart.isEmpty ? null : _showPaymentDialog,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.point_of_sale, size: 24),
                          SizedBox(width: 12),
                          Text('ENCAISSER', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}

// --- ECRAN D'ADMINISTRATION ---
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<dynamic> categories = [];
  List<dynamic> products = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final catRes = await http.get(Uri.parse('http://localhost:3000/api/categories'));
      final prodRes = await http.get(Uri.parse('http://localhost:3000/api/produits'));
      
      if (catRes.statusCode == 200 && prodRes.statusCode == 200) {
        setState(() {
          categories = json.decode(catRes.body);
          products = json.decode(prodRes.body);
          isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur fetch Admin: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _addCategory(String name) async {
    try {
      await http.post(
        Uri.parse('http://localhost:3000/api/categories'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'nom': name}),
      );
      _fetchData();
    } catch (e) {
      print('Erreur ajout catégorie: $e');
    }
  }

  Future<void> _deleteProduct(String id) async {
    try {
      await http.delete(Uri.parse('http://localhost:3000/api/produits/$id'));
      _fetchData();
    } catch (e) {
      print('Erreur suppression produit: $e');
    }
  }

  Future<void> _saveProduct(Map<String, dynamic> productData, {String? id}) async {
    try {
      final url = id == null 
          ? 'http://localhost:3000/api/produits' 
          : 'http://localhost:3000/api/produits/$id';
      final method = id == null ? http.post : http.put;
      
      await method(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(productData),
      );
      _fetchData();
    } catch (e) {
      print('Erreur sauvegarde produit: $e');
    }
  }

  void _showCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvelle Catégorie'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nom de la catégorie'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _addCategory(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _showProductDialog({Map<String, dynamic>? product}) {
    final nomCtrl = TextEditingController(text: product?['name'] ?? '');
    final prixCtrl = TextEditingController(text: product?['price_ttc']?.toString() ?? '');
    final stockCtrl = TextEditingController(text: product?['stock_actuel']?.toString() ?? '0');
    
    int? selectedCategory = product?['categorie_id'];
    if (selectedCategory == null && categories.isNotEmpty) {
      selectedCategory = categories.first['id'];
    } else if (product != null && product['category_name'] != null) {
      // Find category id based on name if we only have the name in the grid
      final match = categories.firstWhere((c) => c['nom'] == product['category_name'], orElse: () => null);
      if (match != null) selectedCategory = match['id'];
    }

    String selectedTva = product?['vat_rate']?.toString() ?? '20.00';
    // Fix padding or format issues with TVA string from DB
    if (!['20.00', '10.00', '5.50'].contains(selectedTva)) selectedTva = '20.00';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(product == null ? 'Nouveau Produit' : 'Modifier Produit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: 'Nom')),
                TextField(controller: prixCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix TTC')),
                DropdownButtonFormField<int>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: categories.map<DropdownMenuItem<int>>((cat) => DropdownMenuItem(value: cat['id'], child: Text(cat['nom']))).toList(),
                  onChanged: (val) => setDialogState(() => selectedCategory = val),
                ),
                DropdownButtonFormField<String>(
                  value: selectedTva,
                  decoration: const InputDecoration(labelText: 'TVA (%)'),
                  items: const [
                    DropdownMenuItem(value: '20.00', child: Text('20.0%')),
                    DropdownMenuItem(value: '10.00', child: Text('10.0%')),
                    DropdownMenuItem(value: '5.50', child: Text('5.5%')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedTva = val!),
                ),
                TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock Initial')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (nomCtrl.text.isNotEmpty && prixCtrl.text.isNotEmpty) {
                  _saveProduct({
                    'nom': nomCtrl.text,
                    'prix_ttc': double.tryParse(prixCtrl.text.replaceAll(',', '.')) ?? 0.0,
                    'categorie_id': selectedCategory,
                    'taux_tva': double.tryParse(selectedTva) ?? 20.0,
                    'stock_actuel': int.tryParse(stockCtrl.text) ?? 0,
                  }, id: product?['id']?.toString());
                  Navigator.pop(context);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administration'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.inventory), text: 'Produits'),
              Tab(icon: Icon(Icons.category), text: 'Catégories'),
            ],
          ),
        ),
        body: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              children: [
                // ONGLET PRODUITS
                Scaffold(
                  floatingActionButton: FloatingActionButton.extended(
                    onPressed: () => _showProductDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Nouveau Produit'),
                  ),
                  body: ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final p = products[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text(p['id'].toString())),
                        title: Text(p['name'] ?? ''),
                        subtitle: Text('${p['category_name'] ?? 'Sans catégorie'} - Stock: ${p['stock_actuel'] ?? 0}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${p['price_ttc']} €', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showProductDialog(product: p)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteProduct(p['id'].toString())),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // ONGLET CATEGORIES
                Scaffold(
                  floatingActionButton: FloatingActionButton.extended(
                    onPressed: _showCategoryDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Nouvelle Catégorie'),
                  ),
                  body: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final c = categories[index];
                      return ListTile(
                        leading: const Icon(Icons.category),
                        title: Text(c['nom']),
                        subtitle: Text('ID: ${c['id']}'),
                      );
                    },
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
