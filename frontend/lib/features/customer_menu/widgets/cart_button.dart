import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/features/customer_menu/providers/cart_provider.dart';

class CartButton extends ConsumerWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalQuantity = ref.watch(cartProvider.select((cart) => cart.totalQuantity));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => context.push(AppRoutes.cart),
          icon: const Icon(Icons.shopping_cart_outlined),
          tooltip: 'Cart',
        ),
        if (totalQuantity > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                '$totalQuantity',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
