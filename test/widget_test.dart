import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaskita/models/pos_models.dart';
import 'package:kaskita/widgets/pos/pos_cart_pane.dart';
import 'package:kaskita/widgets/pos/pos_top_bar.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('PosCartPane updates change and enables submit on cash chip tap', (WidgetTester tester) async {
    final cashCtrl = TextEditingController();
    final cart = [
      {'name': 'soto nasi', 'price': 24000.0, 'qty': 1},
      {'name': 'kerupuk kecil', 'price': 7000.0, 'qty': 1},
    ];
    bool submitted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PosCartPane(
              cart: cart,
              onClearCart: () {},
              onUpdateQty: (idx, delta) {},
              onRemoveItem: (idx) {},
              paymentMethod: 'cash',
              onPaymentMethodChanged: (_) {},
              cashInputCtrl: cashCtrl,
              cartTotal: 31000.0,
              cartItemCount: 2,
              isSubmitting: false,
              onSubmitOrder: () {
                submitted = true;
              },
            ),
          ),
        ),
      ),
    );

    // Initial state: input empty -> submit button should be disabled
    expect(find.text('Rp31.000'), findsOneWidget);
    final submitButtonFinder = find.widgetWithText(ElevatedButton, 'Selesaikan Tunai (Rp31.000)');
    expect(submitButtonFinder, findsOneWidget);
    ElevatedButton btn = tester.widget(submitButtonFinder);
    expect(btn.onPressed, isNull);

    // Tap quick cash chip "35rb"
    final chip35rb = find.widgetWithText(ActionChip, '35rb');
    expect(chip35rb, findsOneWidget);
    await tester.tap(chip35rb);
    await tester.pumpAndSettle();

    // Verify cash input is updated to 35000
    expect(cashCtrl.text, '35000');

    // Verify change box shows KEMBALIAN: Rp4.000
    expect(find.text('KEMBALIAN:'), findsOneWidget);
    expect(find.text('Rp4.000'), findsOneWidget);

    // Verify submit button is now enabled
    btn = tester.widget(submitButtonFinder);
    expect(btn.onPressed, isNotNull);

    // Tap submit button
    await tester.tap(submitButtonFinder);
    await tester.pump();
    expect(submitted, isTrue);
  });

  test('ShiftStats excludes voided orders from omzet and active count', () {
    final rawOrders = [
      {'total_amount': 25000, 'status': 'completed'},
      {'total_amount': 50000, 'status': 'voided'},
      {'total_amount': 15000, 'status': 'completed'},
    ];
    final rawExpenses = [
      {'amount': 10000},
    ];

    final stats = ShiftStats.fromData(
      orderCount: rawOrders.length,
      orders: rawOrders,
      expenses: rawExpenses,
    );

    expect(stats.orderCount, 2); // only 2 active orders
    expect(stats.omzet, 40000.0); // 25000 + 15000, excludes 50000
    expect(stats.expenses, 10000.0);
    expect(stats.bersih, 30000.0);
  });

  test('Order model handles voided status and voidReason', () {
    final json = {
      'id': 'order-1',
      'queue_number': 1,
      'customer_name': 'Budi',
      'total_amount': 30000.0,
      'payment_method': 'cash',
      'user_id': 'user-1',
      'status': 'voided',
      'void_reason': 'Salah input menu',
      'created_at': DateTime.now().toIso8601String(),
    };

    final order = Order.fromJson(json);
    expect(order.isVoided, isTrue);
    expect(order.status, 'voided');
    expect(order.voidReason, 'Salah input menu');
  });

  testWidgets('PosTopBar triggers onOpenOrderHistory when receipt history button is clicked', (WidgetTester tester) async {
    bool historyOpened = false;
    final shift = Shift(
      id: 'shift-1',
      openedAt: DateTime.now(),
      status: 'open',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: PosTopBar(
            shift: shift,
            currentTime: DateTime.now(),
            onOpenOrderHistory: () {
              historyOpened = true;
            },
            onViewReport: () {},
            onCloseShift: () {},
          ),
        ),
      ),
    );

    final historyBtn = find.byTooltip('Riwayat Transaksi');
    expect(historyBtn, findsOneWidget);
    await tester.tap(historyBtn);
    await tester.pump();
    expect(historyOpened, isTrue);
  });
}
