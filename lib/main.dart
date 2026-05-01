<<<<<<< HEAD
=======
import 'package:flttercrud/provider/product_provider.dart';
import 'package:flttercrud/screen/product_screen.dart';
import 'package:flttercrud/service/api_service.dart';
>>>>>>> 13da198feb574d29bfbe370757c57f9dd95a67e0
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

<<<<<<< HEAD
import 'providers/product_provider.dart';
import 'screens/product_list_screen.dart';
import 'services/api_service.dart';

=======
>>>>>>> 13da198feb574d29bfbe370757c57f9dd95a67e0
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
<<<<<<< HEAD
          create: (context) => ProductProvider(
            apiService: ApiService(client: context.read<http.Client>()),
          ),
=======
          create: (context) => ProductProvider(apiService: ApiService(client: context.read<http.Client>())),
>>>>>>> 13da198feb574d29bfbe370757c57f9dd95a67e0
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Product CRUD',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
<<<<<<< HEAD
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
          ),
=======
          appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
>>>>>>> 13da198feb574d29bfbe370757c57f9dd95a67e0
        ),
        home: const ProductListScreen(),
      ),
    );
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> 13da198feb574d29bfbe370757c57f9dd95a67e0
