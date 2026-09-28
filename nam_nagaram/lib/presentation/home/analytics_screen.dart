import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user_model.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _selectedFilter = 'Week'; // 'Week', 'Month', 'Year'
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found.'));
          }
          return _buildDashboard(user);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading user: $e')),
      ),
    );
  }

  Widget _buildDashboard(UserModel user) {
    final isMaintenance = user.role == 'maintenance';
    
    // Determine date cutoff
    DateTime now = DateTime.now();
    DateTime cutoff;
    if (_selectedFilter == 'Week') {
      cutoff = now.subtract(const Duration(days: 7));
    } else if (_selectedFilter == 'Month') {
      cutoff = now.subtract(const Duration(days: 30));
    } else {
      cutoff = now.subtract(const Duration(days: 365));
    }

    Query query = _db.collection('complaints');
    if (isMaintenance && user.teamId != null) {
      query = query.where('assignedTeamId', isEqualTo: user.teamId);
    } else {
      query = query.where('userId', isEqualTo: user.id);
    }

    return Column(
      children: [
        _buildFilterToggle(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(), // We filter dates client-side for simplicity on indices
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error loading data: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              
              // Filter by date client-side to avoid complex composite index requirements
              final filteredDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final createdAt = data['createdAt'] as Timestamp?;
                if (createdAt == null) return false;
                return createdAt.toDate().isAfter(cutoff);
              }).toList();

              return _buildMetrics(filteredDocs, isMaintenance);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.indigo,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ['Week', 'Month', 'Year'].map((filter) {
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.indigo : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetrics(List<QueryDocumentSnapshot> docs, bool isMaintenance) {
    int total = docs.length;
    int resolved = 0;
    int inProgress = 0;
    int pending = 0;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? '';
      if (status == 'Resolved') {
        resolved++;
      } else if (status == 'In Progress' || status == 'Team Assigned') {
        inProgress++;
      } else {
        pending++;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMaintenance ? 'Team Performance Overview' : 'Your Impact Overview',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetricCard('Total\n${isMaintenance ? "Tasks" : "Reports"}', total.toString(), Colors.blue),
              const SizedBox(width: 16),
              _buildMetricCard('Resolved', resolved.toString(), Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetricCard('In Progress', inProgress.toString(), Colors.orange),
              const SizedBox(width: 16),
              _buildMetricCard('Pending', pending.toString(), Colors.redAccent),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Resolution Status',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildPieChart(resolved, inProgress, pending),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(int resolved, int inProgress, int pending) {
    if (resolved == 0 && inProgress == 0 && pending == 0) {
      return const Center(child: Text('No data for this period.', style: TextStyle(color: Colors.grey)));
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: PieChart(
        PieChartData(
          sectionsSpace: 4,
          centerSpaceRadius: 50,
          sections: [
            if (resolved > 0)
              PieChartSectionData(
                color: Colors.green,
                value: resolved.toDouble(),
                title: '$resolved',
                radius: 60,
                titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            if (inProgress > 0)
              PieChartSectionData(
                color: Colors.orange,
                value: inProgress.toDouble(),
                title: '$inProgress',
                radius: 60,
                titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            if (pending > 0)
              PieChartSectionData(
                color: Colors.redAccent,
                value: pending.toDouble(),
                title: '$pending',
                radius: 60,
                titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
