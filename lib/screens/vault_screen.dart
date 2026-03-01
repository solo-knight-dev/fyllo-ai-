import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fyllo_ai/providers/data_provider.dart';
import 'package:fyllo_ai/providers/auth_provider.dart' as auth;
import 'package:intl/intl.dart';
import 'package:fyllo_ai/models/expense_model.dart';
import 'package:fyllo_ai/services/pdf_export_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyllo_ai/widgets/notifications/fyllo_snackbar.dart';
import 'package:fyllo_ai/screens/billing_screen.dart';
import 'package:fyllo_ai/utils/app_constants.dart';
import 'package:fyllo_ai/utils/currency_util.dart';
import 'package:fyllo_ai/utils/error_util.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _showExportDialog() async {
    final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
    final uid = authProvider.user?.uid;
    
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final plan = userDoc.data()?['plan'] ?? 'free';
    final dataProvider = Provider.of<DataProvider>(context, listen: false);

    if (dataProvider.expenses.isEmpty) {
      if (!mounted) return;
      FylloSnackBar.showError(
        context,
        'No receipt data to export.',
        icon: Icons.info_outline,
      );
      return;
    }

    if (plan == 'free') {
      if (!mounted) return;
      FylloSnackBar.showError(
        context,
        'Unlock PDF exports to share and secure your records. Upgrade to Pro!',
        icon: Icons.auto_awesome,
      );
      
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BillingScreen()),
        );
      });
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Text(
              'Export to PDF',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select date range (optional)',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            // Update both the parent state and the dialog state
                            setState(() => _startDate = date);
                            setDialogState(() {});
                          }
                        },
                        icon: const Icon(Icons.calendar_today, color: FylloColors.defaultCyan, size: 16),
                        label: Text(
                          _startDate != null ? DateFormat.MMMd().format(_startDate!) : 'Start Date',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: FylloColors.defaultCyan),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? DateTime.now(),
                            firstDate: _startDate ?? DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            // Update both the parent state and the dialog state
                            setState(() => _endDate = date);
                            setDialogState(() {});
                          }
                        },
                        icon: const Icon(Icons.calendar_today, color: FylloColors.defaultCyan, size: 16),
                        label: Text(
                          _endDate != null ? DateFormat.MMMd().format(_endDate!) : 'End Date',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: FylloColors.defaultCyan),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_startDate != null || _endDate != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                      setDialogState(() {});
                    },
                    child: Text(
                      'Clear dates',
                      style: GoogleFonts.plusJakartaSans(color: Colors.orangeAccent, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  if (!mounted) return;
                  final dataProvider = Provider.of<DataProvider>(context, listen: false);
                  await PdfExportService.exportExpensesToPdf(
                    expenses: dataProvider.expenses,
                    userPlan: plan,
                    startDate: _startDate,
                    endDate: _endDate,
                  );
                  if (!mounted) return;
                  FylloSnackBar.showSuccess(
                    context,
                    'PDF generated successfully!',
                    icon: Icons.download_done_rounded,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FylloColors.defaultCyan,
                  foregroundColor: Colors.black,
                ),
                child: Text('Export', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(authProvider.user?.uid).snapshots(),
      builder: (context, snapshot) {
        String jurisdiction = 'USA';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          jurisdiction = data?['jurisdiction'] ?? 'USA';
        }
        final currencyFormat = CurrencyUtil.getCurrencyFormat(jurisdiction);

        return dataProvider.isLoading
            ? const Center(child: CircularProgressIndicator(color: FylloColors.defaultCyan))
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Custom Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Document Vault",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.file_download, color: FylloColors.defaultCyan),
                          onPressed: _showExportDialog,
                          tooltip: 'Export to PDF',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    Expanded(
                      child: dataProvider.expenses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shield_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
                                  const SizedBox(height: 16),
                                  Text("Secure Finance Vault", 
                                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                  Text("Scanned data & AI insights appear here.", 
                                    style: GoogleFonts.plusJakartaSans(color: Colors.white38)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 100), // Extra space for FAB
                              itemCount: dataProvider.expenses.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final expense = dataProvider.expenses[index];
                                return _buildExpenseTile(context, expense, currencyFormat, jurisdiction);
                              },
                            ),
                    ),
                  ],
                ),
              );
      },
    );
  }

  Widget _buildExpenseTile(BuildContext context, Expense expense, NumberFormat currencyFormat, String jurisdiction) {
    return GestureDetector(
      onTap: expense.id != null && expense.id!.isNotEmpty
          ? () => _showFinanceDetails(context, expense, jurisdiction)
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FylloColors.darkGray,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconForType(expense.deductionType),
                color: FylloColors.defaultCyan,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.merchantName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(DateFormat.MMMd().format(expense.date),
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getColorForImpact(expense.taxImpact).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(expense.taxImpact,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _getColorForImpact(expense.taxImpact), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  if (expense.aiAnalysis.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        expense.aiAnalysis,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
            Text(currencyFormat.format(expense.amount),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  void _showFinanceDetails(BuildContext context, Expense expense, String jurisdiction) {
    
    showModalBottomSheet(
      context: context,
      backgroundColor: FylloColors.obsidian,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (modalContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              Text("AI FINANCE REPORT", 
                style: GoogleFonts.plusJakartaSans(color: FylloColors.defaultCyan, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
              const SizedBox(height: 16),
              Text(expense.merchantName, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              Text(DateFormat.yMMMd().format(expense.date), style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 32),
              
              _buildDetailRow("Amount", CurrencyUtil.getCurrencyFormat(jurisdiction).format(expense.amount), color: FylloColors.defaultCyan),
              _buildDetailRow("Category", expense.category),
              _buildDetailRow("Deduction Type", expense.deductionType),
              _buildDetailRow("Analysis Result", expense.taxImpact, color: _getColorForImpact(expense.taxImpact)),
              
              const SizedBox(height: 24),
              const Divider(color: Colors.white10),
              const SizedBox(height: 24),
              
              Text("AI Analysis", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FylloColors.darkGray,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: FylloColors.defaultCyan.withOpacity(0.1)),
                ),
                child: Text(
                  expense.aiAnalysis,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70, height: 1.6, fontSize: 14),
                ),
              ),
              const SizedBox(height: 32),
              
              // ✅ FIXED DELETE BUTTON WITH PROPER STATE MANAGEMENT
              StatefulBuilder(
                builder: (context, setModalState) {
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: expense.id == null || expense.id!.isEmpty
                          ? () {
                              FylloSnackBar.showError(
                                context,
                                "Invalid expense data - cannot delete",
                                icon: Icons.error_outline,
                              );
                            }
                          : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF1A1A1A),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: Text("Confirm Deletion", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
                                  content: Text("Are you sure you want to permanently delete this receipt? This action cannot be undone.", 
                                    style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: Colors.white54)),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                      child: Text("Delete", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true && expense.id != null && expense.id!.isNotEmpty) {
                                setModalState(() {}); // Trigger rebuild for loading state
                                try {
                                  await Provider.of<DataProvider>(context, listen: false).deleteExpense(expense.id!);
                                  if (context.mounted) {
                                    Navigator.pop(modalContext); // Close bottom sheet
                                    if (mounted) {
                                      FylloSnackBar.showSuccess(context, "Receipt deleted successfully");
                                    }
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    FylloSnackBar.showError(
                                      context, 
                                      ErrorUtil.getFriendlyMessage(e),
                                      icon: Icons.error_outline,
                                    );
                                  }
                                }
                              }
                            },
                      icon: const Icon(Icons.delete_outline, color: Colors.white),
                      label: const Text(
                        "DELETE RECEIPT", 
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.plusJakartaSans(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    type = type.toLowerCase();
    if (type.contains('meal')) return Icons.restaurant;
    if (type.contains('office')) return Icons.chair;
    if (type.contains('travel') || type.contains('flight')) return Icons.flight;
    if (type.contains('advert')) return Icons.campaign;
    if (type.contains('soft')) return Icons.computer;
    return Icons.receipt_long;
  }

  Color _getColorForImpact(String impact) {
    if (impact.contains('100%') || impact.toLowerCase().contains('deductible')) return Colors.greenAccent;
    if (impact.contains('50%') || impact.toLowerCase().contains('partial')) return Colors.orangeAccent;
    if (impact.toLowerCase().contains('personal') || impact.toLowerCase().contains('non')) return Colors.redAccent;
    return Colors.white54;
  }
}
