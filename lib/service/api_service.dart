import 'dart:convert';
import 'package:flttercrud/models/product_model.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:3000/products';
  final http.Client client;

  ApiService({required this.client});

  Future<List<Product>> getProducts() async {
    final response = await client.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((p) => Product.fromJson(p)).toList();
    } else {
      throw Exception('Failed to load products: ${response.statusCode}');
    }
  }

  Future<Product> createProduct(Product product) async {
    final response = await client.post(Uri.parse(baseUrl), headers: {'Content-Type': 'application/json'}, body: json.encode(product.toJson()));
    if (response.statusCode == 201) {
      return Product.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create product: ${response.statusCode}');
    }
  }

  Future<void> updateProduct(int id, Product product) async {
    final response = await client.put(Uri.parse('$baseUrl/$id'), headers: {'Content-Type': 'application/json'}, body: json.encode(product.toJson()));
    if (response.statusCode != 200) {
      throw Exception('Failed to update product: ${response.statusCode}');
    }
  }

  Future<void> deleteProduct(int id) async {
    final response = await client.delete(Uri.parse('$baseUrl/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete product: ${response.statusCode}');
    }
  }
}
