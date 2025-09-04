import 'package:flttercrud/models/product_model.dart';
import 'package:flttercrud/service/api_service.dart';
import 'package:flutter/foundation.dart';

class ProductProvider with ChangeNotifier {
  final ApiService apiService;
  List<Product> _products = [];
  bool _isLoading = false;
  String _error = '';

  ProductProvider({required this.apiService});

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String get error => _error;

  Future<void> fetchProducts() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      _products = await apiService.getProducts();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addProduct(Product product) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newProduct = await apiService.createProduct(product);
      _products.add(newProduct);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProduct(int id, Product product) async {
    _isLoading = true;
    notifyListeners();

    try {
      await apiService.updateProduct(id, product);
      final index = _products.indexWhere((p) => p.id == id);
      if (index != -1) {
        _products[index] = Product(id: id, name: product.name, price: product.price, stock: product.stock);
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(int id) async {
    _isLoading = true;
    notifyListeners();

    try {
      await apiService.deleteProduct(id);
      _products.removeWhere((p) => p.id == id);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
