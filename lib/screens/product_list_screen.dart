import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:lottie/lottie.dart';

import '../models/product.dart';
import '../providers/product_provider.dart';
import 'add_edit_product_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final RefreshController _refreshController = RefreshController();
  final ScrollController _scrollController = ScrollController();

  TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  String _sortOption = 'None';

  int _page = 1;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts(reset: true);
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadProducts();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts({bool reset = false}) async {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    try {
      if (reset) {
        _page = 1;
        provider.products.clear();
      }
      await provider.fetchProducts();
      _refreshController.refreshCompleted();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query.toLowerCase();
      });
    });
  }

  List<Product> _applyFilters(List<Product> products) {
    var filtered =
        products
            .where((p) => p.name.toLowerCase().contains(_searchQuery))
            .toList();

    if (_sortOption == 'Price') {
      filtered.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortOption == 'Stock') {
      filtered.sort((a, b) => a.stock.compareTo(b.stock));
    }

    return filtered;
  }

  Future<void> _exportToPdf(List<Product> products) async {
    final PdfDocument document = PdfDocument();
    final PdfPage page = document.pages.add();
    final Size pageSize = page.getClientSize();

    page.graphics.drawString(
      'Product List',
      PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold),
      bounds: Rect.fromLTWH(0, 0, pageSize.width, 40),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    final PdfGrid grid = PdfGrid();
    grid.style = PdfGridStyle(
      font: PdfStandardFont(PdfFontFamily.helvetica, 12),
      cellPadding: PdfPaddings(left: 5, right: 5, top: 5, bottom: 5),
    );

    grid.columns.add(count: 4);
    grid.headers.add(1);
    final PdfGridRow header = grid.headers[0];
    header.style = PdfGridRowStyle(
      backgroundBrush: PdfBrushes.darkBlue,
      textBrush: PdfBrushes.white,
      font: PdfStandardFont(
        PdfFontFamily.helvetica,
        14,
        style: PdfFontStyle.bold,
      ),
    );

    header.cells[0].value = 'ID';
    header.cells[1].value = 'Name';
    header.cells[2].value = 'Price';
    header.cells[3].value = 'Stock';

    for (var product in products) {
      final row = grid.rows.add();
      row.cells[0].value = product.id.toString();
      row.cells[1].value = product.name;
      row.cells[2].value = '\$${product.price.toStringAsFixed(2)}';
      row.cells[3].value = product.stock.toString();
    }

    grid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 50, pageSize.width, pageSize.height - 50),
    );

    final List<int> bytes = await document.save();
    document.dispose();

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/products.pdf');
    await file.writeAsBytes(bytes, flush: true);

    await OpenFilex.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 4,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Products',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            color: Colors.white,
            onPressed: _showSortDialog,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            color: Colors.white,
            onPressed: () {
              final provider = Provider.of<ProductProvider>(
                context,
                listen: false,
              );
              _exportToPdf(_applyFilters(provider.products));
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_rounded),
            color: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddEditProductScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search products...',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.products.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 60, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          provider.error,
                          style: const TextStyle(fontSize: 18),
                        ),
                        ElevatedButton(
                          onPressed: () => _loadProducts(reset: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final filtered = _applyFilters(provider.products);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.network(
                          'https://lottie.host/8cb18c92-de90-45a1-a544-0c330d4b5ef7/6ha4W6Vayc.json',
                          width: 300,
                          height: 300,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Oops! No products found.",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SmartRefresher(
                  controller: _refreshController,
                  onRefresh: () => _loadProducts(reset: true),
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      return _buildProductCard(context, product);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              'Sort Products',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSortOption(Icons.cancel, 'No Sort', 'None'),
                _buildSortOption(Icons.attach_money, 'Sort by Price', 'Price'),
                _buildSortOption(Icons.inventory, 'Sort by Stock', 'Stock'),
              ],
            ),
          ),
    );
  }

  Widget _buildSortOption(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      trailing:
          _sortOption == value
              ? const Icon(Icons.check, color: Colors.green)
              : null,
      onTap: () {
        setState(() => _sortOption = value);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    return Card(
      elevation: 6,
      shadowColor: Colors.purpleAccent.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blueAccent.withOpacity(0.2),
          radius: 28,
          child: const Icon(Icons.shopping_bag, color: Colors.blue, size: 30),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '\$${product.price.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.black87),
              ),
              Text(
                'Stock: ${product.stock}',
                style: TextStyle(
                  color: product.stock < 10 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.deepPurple),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => AddEditProductScreen(product: product),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => _showDeleteDialog(context, product.id!),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, int productId) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Confirm Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Are you sure you want to delete this product?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await Provider.of<ProductProvider>(
                      context,
                      listen: false,
                    ).deleteProduct(productId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Product deleted successfully'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}
