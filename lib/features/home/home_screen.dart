import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/providers.dart';
import '../../repositories/dashboard_repository.dart';
import '../auth/login_screen.dart';
import '../bons/bon_list_screen.dart';
import '../notas/nota_list_screen.dart';
import '../payments/payment_list_screen.dart';
import '../expenses/expense_list_screen.dart';
import '../saldo/saldo_list_screen.dart';
import '../margins/margin_list_screen.dart';
import 'widgets/app_drawer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    final statsValue = ref.watch(dashboardStatsProvider(_dateRange));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE), // Lighter, cooler background
      appBar: AppBar(
        //add hamburger icon
        leading: Builder(
          builder: (context) => IconButton(
            color: const Color(0xFF1B2559),
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard Transaksi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B2559),
              ),
            ),
            Text(
              'Palm Oil Management System',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          // IconButton(
          //   icon: const Icon(
          //     Icons.notifications_none_outlined,
          //     color: Color(0xFF1B2559),
          //   ),
          //   onPressed: () {},
          // ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF1B2559)),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(dashboardStatsProvider(_dateRange)),
        child: statsValue.when(
          data: (stats) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDateFilterPill(),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SaldoListScreen()),
                  ),
                  child: _buildHeroCard(stats),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Ringkasan Operasional',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B2559),
                  ),
                ),
                const SizedBox(height: 12),
                _buildOperationalRow(stats),

                const SizedBox(height: 24),
                const Text(
                  'Analisis Keuangan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B2559),
                  ),
                ),
                const SizedBox(height: 12),
                _buildFinancialAnalysis(stats),
                const SizedBox(height: 24),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildDateFilterPill() {
    return GestureDetector(
      onTap: _selectDateRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month, color: Colors.indigo.shade700, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Periode Laporan',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                ),
                Text(
                  '${DateFormat('dd MMM').format(_dateRange.start)} - ${DateFormat('dd MMM yyyy').format(_dateRange.end)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B2559),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.indigo, // Updated to match new theme
              onPrimary: Colors.white,
              onSurface: Color(0xFF1B2559),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  Widget _buildHeroCard(DashboardStats stats) {
    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4318FF), Color(0xFF6A82FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4318FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.account_balance_wallet,
              size: 150,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SaldoListScreen()),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.wallet,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'SALDO TERSEDIA SAAT INI',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currencyFmt.format(stats.currentBalance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SaldoListScreen(),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Laba Bersih (Periode)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              currencyFmt.format(stats.netProfit),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 30, color: Colors.white24),
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MarginListScreen(),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Margin / Profit',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              currencyFmt.format(stats.totalMargin),
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalRow(DashboardStats stats) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoTile(
            title: 'Total Bon',
            value: stats.ongoingBons.toString(),
            subValue: '${stats.finishedBons} Selesai',
            icon: Icons.receipt_long,
            accentColor: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BonListScreen()),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildInfoTile(
            title: 'Nota Penjualan',
            value: stats.unpaidNotas.toString(),
            subValue: '${stats.paidNotas} Lunas',
            icon: Icons.description,
            accentColor: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotaListScreen()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String value,
    required String subValue,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: accentColor.withOpacity(0.1),
                  child: Icon(icon, color: accentColor, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1B2559),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subValue,
              style: TextStyle(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialAnalysis(DashboardStats stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildFinancialItem(
            label: 'Total Transaksi (Offtaker)',
            amount: stats.totalTransactions,
            color: Colors.black87,
            icon: Icons.business,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MarginListScreen()),
            ),
          ),
          const Divider(height: 24),
          _buildFinancialItem(
            label: 'Total Transaksi Saya',
            amount: stats.totalMyTransactions,
            color: Colors.red.shade700,
            icon: Icons.person_outline,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaymentListScreen()),
            ),
          ),
          const Divider(height: 24),
          _buildFinancialItem(
            label: 'Pengeluaran & Sharing',
            amount: stats.totalExpenses,
            color: Colors.orange.shade800,
            icon: Icons.outbox,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExpenseListScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialItem({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.grey.shade700, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(amount),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
