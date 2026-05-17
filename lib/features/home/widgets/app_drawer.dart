import 'package:flutter/material.dart';
import 'package:pembukuan/features/notas/nota_list_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/login_screen.dart';
import '../../bons/bon_list_screen.dart';
import '../../margins/margin_list_screen.dart';
import '../../payments/payment_list_screen.dart';
import '../../expenses/expense_list_screen.dart';
import '../../saldo/saldo_list_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: Column(
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  title: 'Dashboard',
                  onTap: () => Navigator.pop(context),
                  isSelected: true,
                ),
                const SizedBox(height: 8),
                _buildSectionTitle('OPERASIONAL'),
                _buildDrawerItem(
                  context,
                  icon: Icons.receipt_long_outlined,
                  title: 'Slip Timbangan',
                  onTap: () => _navigateTo(context, const BonListScreen()),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.description_outlined,
                  title: 'Nota Transaksi',
                  onTap: () => _navigateTo(context, const NotaListScreen()),
                ),
                const SizedBox(height: 8),
                _buildSectionTitle('KEUANGAN'),
                _buildDrawerItem(
                  context,
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Saldo',
                  onTap: () => _navigateTo(context, const SaldoListScreen()),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.payment_outlined,
                  title: 'Pembayaran',
                  onTap: () => _navigateTo(context, const PaymentListScreen()),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.trending_up,
                  title: 'Margin / Offtaker',
                  onTap: () => _navigateTo(context, const MarginListScreen()),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.outbox_outlined,
                  title: 'Pengeluaran',
                  onTap: () => _navigateTo(context, const ExpenseListScreen()),
                ),
              ],
            ),
          ),
          _buildLogoutButton(context),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF4F7FE), width: 2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4318FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.spa, color: Color(0xFF4318FF), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Palm Oil',
                  style: TextStyle(
                    color: Color(0xFF1B2559),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Management',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    final color = isSelected ? const Color(0xFF4318FF) : Colors.grey.shade600;
    final bgColor = isSelected
        ? const Color(0xFF4318FF).withOpacity(0.05)
        : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: color, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFF1B2559) : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        tileColor: bgColor,
        hoverColor: const Color(0xFF4318FF).withOpacity(0.05),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: InkWell(
        onTap: () async {
          await Supabase.instance.client.auth.signOut();
          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.red.shade700, size: 20),
              const SizedBox(width: 12),
              Text(
                'Keluar Aplikasi',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.pop(context); // Close drawer
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}
