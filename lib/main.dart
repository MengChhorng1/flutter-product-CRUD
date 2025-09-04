import 'package:flttercrud/provider/product_provider.dart';
import 'package:flttercrud/screen/product_screen.dart';
import 'package:flttercrud/service/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => http.Client()),
        ChangeNotifierProvider(
          create: (context) => ProductProvider(apiService: ApiService(client: context.read<http.Client>())),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Product CRUD',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
        ),
        home: const ProductListScreen(),
      ),
    );
  }
}
