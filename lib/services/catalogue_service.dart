import 'package:supabase_flutter/supabase_flutter.dart';

class CatalogueService {
  CatalogueService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  // ============================================================
  // MARCHAND CONNECTÉ
  // ============================================================

  String _getUserId() {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    return user.id;
  }

  Future<String> getCurrentMerchantId() async {
    final userId = _getUserId();

    final rows = await _supabase
        .from('merchants')
        .select('id')
        .eq('user_id', userId)
        .limit(1);

    if (rows.isEmpty) {
      throw Exception(
        'Aucun marchand associé à cet utilisateur.',
      );
    }

    return rows.first['id'].toString();
  }

  // ============================================================
  // CATÉGORIES
  // ============================================================

  Future<List<Map<String, dynamic>>> getCategories() async {
    final rows = await _supabase
        .from('categories')
        .select('*');

    return List<Map<String, dynamic>>.from(rows);
  }

  // ============================================================
  // SOUS-CATÉGORIES
  // ============================================================

  Future<List<Map<String, dynamic>>> getSubcategories(
    int categoryId,
  ) async {
    final rows = await _supabase
        .from('subcategories')
        .select('*')
        .eq('category_id', categoryId);

    return List<Map<String, dynamic>>.from(rows);
  }

  // ============================================================
  // PRODUITS DU CATALOGUE
  // ============================================================

  Future<List<Map<String, dynamic>>> getProducts({
    required int categoryId,
    int? subcategoryId,
  }) async {
    var query = _supabase
        .from('products')
        .select(
          'id, name_fr, name_ar, unit, '
          'category_id, subcategory_id, active',
        )
        .eq('category_id', categoryId)
        .eq('active', true);

    if (subcategoryId != null) {
      query = query.eq(
        'subcategory_id',
        subcategoryId,
      );
    }

    final rows = await query;

    return List<Map<String, dynamic>>.from(rows);
  }

  // ============================================================
  // RECHERCHE DE PRODUITS
  // ============================================================

  Future<List<Map<String, dynamic>>> searchProducts({
    required String text,
    int? categoryId,
    int? subcategoryId,
  }) async {
    var query = _supabase
        .from('products')
        .select(
          'id, name_fr, name_ar, unit, '
          'category_id, subcategory_id, active',
        )
        .eq('active', true);

    if (categoryId != null) {
      query = query.eq(
        'category_id',
        categoryId,
      );
    }

    if (subcategoryId != null) {
      query = query.eq(
        'subcategory_id',
        subcategoryId,
      );
    }

    final rows = await query;

    final search = text.trim().toLowerCase();

    if (search.isEmpty) {
      return List<Map<String, dynamic>>.from(rows);
    }

    return List<Map<String, dynamic>>.from(rows)
        .where((product) {
      final nameFr =
          (product['name_fr'] ?? '')
              .toString()
              .toLowerCase();

      final nameAr =
          (product['name_ar'] ?? '')
              .toString()
              .toLowerCase();

      return nameFr.contains(search) ||
          nameAr.contains(search);
    }).toList();
  }

  // ============================================================
  // OPTIONS DE CATÉGORIE
  // ============================================================

  Future<List<Map<String, dynamic>>> getCategoryOptions({
    required int categoryId,
    int? subcategoryId,
  }) async {
    final rows = await _supabase
        .from('category_options')
       .select(
  'id, category_id, subcategory_id, '
  'name_fr, name_ar, option_type, options, required, '
  'sort_order, active',
)
        .eq('category_id', categoryId)
        .eq('active', true);

    final result =
        List<Map<String, dynamic>>.from(rows)
            .where((option) {
      final optionSubcategory =
          option['subcategory_id'];

      return optionSubcategory == null ||
          subcategoryId == null ||
          optionSubcategory == subcategoryId;
    }).toList();

    result.sort((a, b) {
      final orderA =
          (a['sort_order'] ?? 0) as num;

      final orderB =
          (b['sort_order'] ?? 0) as num;

      return orderA.compareTo(orderB);
    });

    return result;
  }

  // ============================================================
  // PRODUITS DU MARCHAND
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getMerchantProducts() async {
    final merchantId =
        await getCurrentMerchantId();

    final rows = await _supabase
        .from('merchant_products')
        .select(
          'id, merchant_id, product_id, '
          'options, active, created_at, updated_at, '
          'products(id, name_fr, name_ar, unit, '
          'category_id, subcategory_id)',
        )
        .eq('merchant_id', merchantId)
        .eq('active', true);

    return List<Map<String, dynamic>>.from(rows);
  }

  // ============================================================
  // AJOUT / MODIFICATION D'UN PRODUIT MARCHAND
  // ============================================================

  Future<Map<String, dynamic>> saveMerchantProduct({
    required int productId,
    required Map<String, dynamic> options,
  }) async {
    final merchantId =
        await getCurrentMerchantId();

    final row = await _supabase
        .from('merchant_products')
        .upsert(
      {
        'merchant_id': merchantId,
        'product_id': productId,
        'options': options,
        'active': true,
        'updated_at':
            DateTime.now().toIso8601String(),
      },
      onConflict: 'merchant_id,product_id',
    )
        .select()
        .single();

    return Map<String, dynamic>.from(row);
  }

  // ============================================================
  // DÉSACTIVATION
  // ============================================================

  Future<void> deactivateMerchantProduct(
    int merchantProductId,
  ) async {
    final merchantId =
        await getCurrentMerchantId();

    await _supabase
        .from('merchant_products')
        .update({
      'active': false,
      'updated_at':
          DateTime.now().toIso8601String(),
    })
        .eq('id', merchantProductId)
        .eq('merchant_id', merchantId);
  }
}