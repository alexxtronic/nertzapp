import 'dart:io';
import 'package:supabase/supabase.dart';

void main(List<String> args) async {
  print('Starting Shop Sync...');
  
  final url = Platform.environment['SUPABASE_URL'];
  final key = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  
  if (url == null || key == null || url.isEmpty || key.isEmpty) {
    print('Error: Please set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY variables.');
    exit(1);
  }

  final supabase = SupabaseClient(url, key);
  final assetDir = Directory('assets/card_backs');
  
  if (!assetDir.existsSync()) {
    print('Assets directory not found: ${assetDir.path}');
    exit(1);
  }

  final files = assetDir.listSync().whereType<File>().where((f) => f.path.endsWith('.png') || f.path.endsWith('.jpg'));
  print('Found ${files.length} assets to sync.');

  for (final file in files) {
    var filename = file.uri.pathSegments.last;
    var id = 'card_back_${filename.replaceAll(RegExp(r'\.[^.]+$'), '')}';
    var name = filename.replaceAll(RegExp(r'\.[^.]+$'), '').split('_').map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '').join(' ');
    
    print('Processing $filename...');
    var fileBytes = await file.readAsBytes();
    var storagePath = 'card-backs/$filename';
    
    try {
      await supabase.storage.from('shop-assets').uploadBinary(storagePath, fileBytes, fileOptions: const FileOptions(upsert: true));
    } catch (e) {
      print('Upload warning (might exist): $e');
    }

    var publicUrl = supabase.storage.from('shop-assets').getPublicUrl(storagePath);
    
    int price = 50; int gems = 0;
    if (filename.contains('rare')) { price = 150; gems = 3; }
    else if (filename.contains('ultra') || filename.contains('swamp')) { price = 750; gems = 10; }
    else if (filename.contains('uncommon') || filename.contains('gold')) { price = 100; gems = 2; }
    else if (filename.contains('doodle')) { price = 150; gems = 3; }

    var product = {
      'id': id, 'name': name, 'category': 'card_back',
      'price_coins': price, 'price_gems': gems,
      'asset_path': publicUrl, 'is_available': true, 'sort_order': 100,
      'description': 'A cool $name card back'
    };

    try { await supabase.from('shop_products').upsert(product); print('Upserted: $id'); } 
    catch (e) { print('DB Error: $e'); }
  }
  print('Sync Complete!');
}
