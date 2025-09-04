import 'dart:async';
import 'dart:io';
import 'package:flttercrud/models/product_model.dart';
import 'package:flttercrud/provider/product_provider.dart';
import 'package:flttercrud/screen/edit_product.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:lottie/lottie.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final String? icon = null;
  final RefreshController _refreshController = RefreshController();
  final ScrollController _scrollController = ScrollController();
  bool isExpanded = false;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  String _sortOption = 'None';

  // int _page = 1; // Removed unused field

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts(reset: true);
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
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
        // _page = 1; // Removed unused field
        provider.products.clear();
      }
      await provider.fetchProducts();
      _refreshController.refreshCompleted();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${error.toString()}')));
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
    var filtered = products.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();

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
    grid.style = PdfGridStyle(font: PdfStandardFont(PdfFontFamily.helvetica, 12), cellPadding: PdfPaddings(left: 5, right: 5, top: 5, bottom: 5));

    grid.columns.add(count: 4);
    grid.headers.add(1);
    final PdfGridRow header = grid.headers[0];
    header.style = PdfGridRowStyle(
      backgroundBrush: PdfBrushes.darkBlue,
      textBrush: PdfBrushes.white,
      font: PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
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

    grid.draw(page: page, bounds: Rect.fromLTWH(0, 50, pageSize.width, pageSize.height - 50));

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
            gradient: LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
        title: const Text(
          'Products',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.sort), color: Colors.white, onPressed: _showSortDialog),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            color: Colors.white,
            onPressed: () {
              final provider = Provider.of<ProductProvider>(context, listen: false);
              _exportToPdf(_applyFilters(provider.products));
            },
          ),
          IconButton(
            icon: icon == null ? Icon(Icons.add_circle_outline) : Icon(Icons.safety_check),
            color: Colors.white,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AddEditProductScreen()));
            },
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
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
                          Text(provider.error, style: const TextStyle(fontSize: 18)),
                          ElevatedButton(
                            onPressed: () => _loadProducts(reset: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                            style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  }

                  return SmartRefresher(
                    controller: _refreshController,
                    onRefresh: () => _loadProducts(reset: true),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          for (int i = 0; i < filtered.length; i += 2)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  // First card
                                  Expanded(child: _buildProductCard(context, filtered[i])),
                                  const SizedBox(width: 16),
                                  // Second card, if exists
                                  if (i + 1 < filtered.length)
                                    Expanded(child: _buildProductCard(context, filtered[i + 1]))
                                  else
                                    const Expanded(child: SizedBox()), // empty space for last odd item
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Products', style: TextStyle(fontWeight: FontWeight.bold)),
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
      trailing: _sortOption == value ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: () {
        setState(() => _sortOption = value);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    return Container(
      width: 180,
      height: 275,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.25), spreadRadius: 2, blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  ),
                  child: const Center(child: Icon(Icons.shopping_bag, size: 70, color: Colors.blue)),
                ),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        iconSize: 24,
                        color: Colors.blueAccent,
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditProductScreen(product: product))),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        iconSize: 24,
                        color: Colors.redAccent,
                        onPressed: () => _showDeleteDialog(context, product.id!),
                        icon: const Icon(Icons.delete),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isExpanded = !isExpanded;
                      });
                    },
                    child: Tooltip(
                      message: product.name,
                      child: Text(
                        product.name,
                        textAlign: TextAlign.center,
                        maxLines: isExpanded ? null : 1,
                        overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  Text(
                    "\$${product.price.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: product.stock < 10 ? Colors.red[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Stock: ${product.stock}",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: product.stock < 10 ? Colors.red : Colors.green[800]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, int productId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await Provider.of<ProductProvider>(context, listen: false).deleteProduct(productId);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted successfully')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
