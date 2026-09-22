import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanserve/core/constants/app_routes.dart';
import 'package:scanserve/core/network/api_exception.dart';
import 'package:scanserve/core/theme/app_colors.dart';
import 'package:scanserve/core/theme/app_text_styles.dart';
import 'package:scanserve/core/utils/responsive.dart';
import 'package:scanserve/features/customer_menu/providers/cart_provider.dart';
import 'package:scanserve/features/customer_menu/providers/order_submission_provider.dart';
import 'package:scanserve/features/customer_menu/providers/table_number_provider.dart';
import 'package:scanserve/shared/models/cart_item.dart';
import 'package:scanserve/shared/widgets/app_button.dart';

/// /order/review - the spec describes this as two conceptual steps
/// (enter table number, then review the order), but the routing section
/// only allows /menu/:slug, /cart, and /order/review - so both steps
/// live in this one route, switched on whether tableNumberProvider is
/// set yet.
class OrderReviewScreen extends ConsumerWidget {
  const OrderReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tableNumber = ref.watch(tableNumberProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(tableNumber == null ? 'Table Number' : 'Review Order'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Responsive.pagePadding(context)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: tableNumber == null ? const _TableNumberForm() : const _OrderReviewView(),
          ),
        ),
      ),
    );
  }
}

class _TableNumberForm extends ConsumerStatefulWidget {
  const _TableNumberForm();

  @override
  ConsumerState<_TableNumberForm> createState() => _TableNumberFormState();
}

class _TableNumberFormState extends ConsumerState<_TableNumberForm> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(tableNumberProvider.notifier).state = _controller.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What table are you at?', style: AppTextStyles.headline),
          const SizedBox(height: 8),
          Text(
            'This is the only information we need from you - no name, '
            'phone, or account required.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          Text('Table Number *', style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          )),
          const SizedBox(height: 8),
          TextFormField(
            controller: _controller,
            autofocus: true,
            maxLength: kTableNumberMaxLength,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'e.g. 12 or A12'),
            onFieldSubmitted: (_) => _continue(),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return 'Table number is required';
              if (trimmed.length > kTableNumberMaxLength) {
                return 'Table number is too long';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(label: 'Continue', expand: true, onPressed: _continue),
        ],
      ),
    );
  }
}

class _OrderReviewView extends ConsumerStatefulWidget {
  const _OrderReviewView();

  @override
  ConsumerState<_OrderReviewView> createState() => _OrderReviewViewState();
}

class _OrderReviewViewState extends ConsumerState<_OrderReviewView> {
  Future<void> _placeOrder() async {
    await ref.read(orderSubmissionProvider.notifier).submit();
    if (!mounted) return;

    final result = ref.read(orderSubmissionProvider);
    if (result.status == OrderSubmissionStatus.success && result.order != null) {
      context.pushReplacement(AppRoutes.orderSuccess(result.order!.orderId));
    }
    // On failure, state.errorMessage is shown inline below - the cart
    // and table number are untouched so the customer can just retry
    // (Phase 6 spec #19).
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final tableNumber = ref.watch(tableNumberProvider)!;
    final submission = ref.watch(orderSubmissionProvider);
    final isSubmitting = submission.isSubmitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cart.restaurantName != null) Text(cart.restaurantName!, style: AppTextStyles.displayMedium),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.table_bar_outlined, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Text('Table $tableNumber', style: AppTextStyles.title.copyWith(fontSize: 15)),
              const Spacer(),
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => ref.read(tableNumberProvider.notifier).state = null,
                child: const Text('Change'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (final item in cart.items) _ReviewLine(item: item),
        const Divider(height: 32, color: AppColors.border),
        Row(
          children: [
            Text('Subtotal', style: AppTextStyles.title),
            const Spacer(),
            Text(cart.subtotalDisplay, style: AppTextStyles.title.copyWith(color: AppColors.primaryDark)),
          ],
        ),
        if (submission.status == OrderSubmissionStatus.failure) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withOpacity(0.3)),
            ),
            child: Text(
              submission.errorMessage ?? apiErrorMessage(Exception('Unknown error')),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
        const SizedBox(height: 28),
        AppPrimaryButton(
          // Disabled while submitting - the primary guard against an
          // accidental double-tap creating two orders (Phase 6 spec
          // #20); OrderSubmissionNotifier.submit() also no-ops if a
          // submission is already in flight, as a backstop.
          label: isSubmitting ? 'Placing Order...' : 'Place Order',
          expand: true,
          onPressed: isSubmitting ? null : _placeOrder,
        ),
      ],
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text('${item.name} × ${item.quantity}', style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
          ),
          Text(item.subtotalDisplay, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
