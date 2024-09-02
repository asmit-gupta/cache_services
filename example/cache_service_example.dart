import 'package:cache_service/cache_service.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // Ensures that Flutter is initialized
  final cacheService = CacheService();
  await cacheService.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Cache App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home Page'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'CacheService Initialized!',
            style: TextStyle(fontSize: 24),
          ),
          //cache image
          CachedImage(
            imageUrl:
                'https://sample.com/image.png', //image url which needs to be cached
            shimmer:
                true, //enabling shimmer to true; it enables shimmer effect while the image is loading
            shimmerBaseColor: Colors.black12, //shimmer effect base color
            shimmerHighlightColor:
                Colors.black38, //shimmer effect highlight color
            alignment: Alignment.center, //alignment of image
            fit: BoxFit.contain,
          ),
          SizedBox(
            height: 10,
          ),
          CachedPDF(
            pdfUrl: 'https://sample.com/sample.pdf',
            alignment: Alignment.center,
            fit: BoxFit.contain,
          ),
          SizedBox(
            height: 10,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  //clear cache
                  CacheService().clearCache();
                },
                child: Text('Clear cache'),
              ),
              ElevatedButton(
                onPressed: () {
                  //clear cache
                  CacheService().preloadImageResources(
                    ['url1', 'url2'],
                  );
                },
                child: Text('Preload cache'),
              ),
            ],
          ),
          //in - memory cache
          ElevatedButton(
            onPressed: () {
              CacheService().addItem({'id': 'item1', 'data': 'some data'});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Item added to cache')),
              );
            },
            child: Text('Add Item'),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              Map<String, dynamic>? item = CacheService().getItem('item1');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Item: ${item.toString()}')),
              );
            },
            child: Text('Get Item'),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              bool exists = CacheService().containsItem('item1');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Item exists: $exists')),
              );
            },
            child: Text('Check Item Exists'),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              CacheService()
                  .updateItem({'id': 'item1', 'data': 'updated data'});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Item updated in cache')),
              );
            },
            child: Text('Update Item'),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              bool removed = CacheService().removeItemFromMemory('item1');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Item removed: $removed')),
              );
            },
            child: Text('Remove Item'),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              CacheService().clearCacheFromMemory();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Cache cleared')),
              );
            },
            child: Text('Clear Cache From Memory'),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              List<Map<String, dynamic>> allItems = CacheService().memoryCache;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('All Cached Items: $allItems')),
              );
            },
            child: Text('Show All Cached Items'),
          ),
        ],
      ),
    );
  }
}
