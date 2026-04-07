class Ingredient {
  final String name;
  final String quantity;
  final String unit;

  Ingredient({required this.name, required this.quantity, required this.unit});

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        name: j['name'] ?? '',
        quantity: j['quantity']?.toString() ?? '',
        unit: j['unit'] ?? '',
      );
}

class Recipe {
  final String id;
  final String name;
  final String cuisine;
  final String? imageUrl;
  final int prepTime;
  final int cookTime;
  final int servings;
  final String instructions;
  final List<Ingredient> ingredients;

  Recipe({
    required this.id,
    required this.name,
    required this.cuisine,
    this.imageUrl,
    required this.prepTime,
    required this.cookTime,
    required this.servings,
    required this.instructions,
    required this.ingredients,
  });

  int get totalTime => prepTime + cookTime;

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['_id'] ?? j['id'] ?? '',
        name: j['recipe_name'] ?? '',
        cuisine: j['cuisine'] ?? '',
        imageUrl: (j['image_url'] as String?)?.isNotEmpty == true ? j['image_url'] : null,
        prepTime: (j['prep_time'] as num?)?.toInt() ?? 0,
        cookTime: (j['cook_time'] as num?)?.toInt() ?? 0,
        servings: (j['servings'] as num?)?.toInt() ?? 0,
        instructions: j['instructions'] ?? '',
        ingredients: (j['ingredients'] as List? ?? [])
            .map((i) => Ingredient.fromJson(i as Map<String, dynamic>))
            .toList(),
      );
}
