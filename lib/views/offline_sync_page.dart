import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:room_to_read/controllers/offline_sync_controller.dart';
import 'package:room_to_read/widgets/custom_app_bar.dart';

class OfflineSyncPage extends StatelessWidget {
  const OfflineSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OfflineSyncController());

    return Scaffold(
      appBar: const CustomAppBar(title: 'ऑफलाइन सिंक'),
      body: Obx(
        () => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection Status Card
              _buildConnectionStatusCard(controller),
              const SizedBox(height: 16),

              // Offline Data Statistics
              _buildOfflineStatsCard(controller),
              const SizedBox(height: 16),

              // API Key Input
              _buildApiKeySection(controller),
              const SizedBox(height: 16),

              // Sync Actions
              _buildSyncActionsCard(controller),
              const SizedBox(height: 16),

              // Sync Progress
              if (controller.isSyncing.value)
                _buildSyncProgressCard(controller),

              // Pending Transactions
              _buildPendingTransactionsCard(controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard(OfflineSyncController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  controller.isOnline.value ? Icons.wifi : Icons.wifi_off,
                  color: controller.isOnline.value ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'कनेक्शन स्थिति',
                  style: Get.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              controller.isOnline.value
                  ? 'ऑनलाइन (${controller.connectionType.value})'
                  : 'ऑफलाइन',
              style: TextStyle(
                color: controller.isOnline.value ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineStatsCard(OfflineSyncController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ऑफलाइन डेटा',
              style: Get.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'छात्र',
                    controller.offlineStudents.value.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'किताबें',
                    controller.offlineBooks.value.toString(),
                    Icons.book,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'कक्षाएं',
                    controller.offlineClasses.value.toString(),
                    Icons.class_,
                    Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'जारी किताबें',
                    controller.checkedOutBooks.value.toString(),
                    Icons.library_books,
                    Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'पेंडिंग ट्रांजैक्शन',
                    controller.pendingTransactions.value.toString(),
                    Icons.pending_actions,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'सिंक आइटम्स',
                    controller.pendingSyncItems.value.toString(),
                    Icons.sync,
                    Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // New row for offline transaction stats
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'ऑफलाइन चेकआउट',
                    controller.offlineTransactions
                        .where((t) => t['transaction_type'] == 'checkout')
                        .length
                        .toString(),
                    Icons.logout,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'ऑफलाइन चेकइन',
                    controller.offlineTransactions
                        .where((t) => t['transaction_type'] == 'checkin')
                        .length
                        .toString(),
                    Icons.login,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeySection(OfflineSyncController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'API Key',
              style: Get.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.apiKeyController,
              decoration: const InputDecoration(
                hintText: 'सिंक के लिए API Key डालें',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
              obscureText: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncActionsCard(OfflineSyncController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'सिंक एक्शन्स',
              style: Get.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: controller.isSyncing.value
                        ? null
                        : controller.downloadFreshData,
                    icon: const Icon(Icons.download),
                    label: const Text('डेटा डाउनलोड'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: controller.isSyncing.value
                        ? null
                        : controller.syncOfflineData,
                    icon: const Icon(Icons.sync),
                    label: const Text('सिंक करें'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // NEW: Bulk Sync Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: controller.isSyncing.value
                    ? null
                    : controller.bulkSyncOfflineTransactions,
                icon: const Icon(Icons.sync_alt),
                label: const Text('बल्क सिंक (केवल ट्रांजैक्शन)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Manual data download button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: controller.isSyncing.value
                    ? null
                    : controller.manualDataDownload,
                icon: const Icon(Icons.cloud_download),
                label: const Text('मैन्युअल डेटा डाउनलोड'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: controller.clearOfflineData,
                icon: const Icon(Icons.delete_forever),
                label: const Text('ऑफलाइन डेटा साफ करें'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncProgressCard(OfflineSyncController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'सिंक प्रगति',
              style: Get.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: controller.syncProgress.value / 100),
            const SizedBox(height: 8),
            Text(
              '${controller.syncProgress.value}% पूरा',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              controller.syncStatus.value,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTransactionsCard(OfflineSyncController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'पेंडिंग ट्रांजैक्शन्स',
                  style: Get.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (controller.offlineTransactions.isNotEmpty)
                  Chip(
                    label: Text('${controller.offlineTransactions.length}'),
                    backgroundColor: Colors.orange.withOpacity(0.2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (controller.offlineTransactions.isEmpty)
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 48),
                    SizedBox(height: 8),
                    Text('कोई पेंडिंग ट्रांजैक्शन नहीं'),
                  ],
                ),
              )
            else
              Column(
                children: [
                  // Summary row
                  Row(
                    children: [
                      Expanded(
                        child: _buildTransactionSummary(
                          'चेकआउट',
                          controller.offlineTransactions
                              .where((t) => t['transaction_type'] == 'checkout')
                              .length,
                          Icons.logout,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTransactionSummary(
                          'चेकइन',
                          controller.offlineTransactions
                              .where((t) => t['transaction_type'] == 'checkin')
                              .length,
                          Icons.login,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Transaction list
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: controller.offlineTransactions.length > 5
                        ? 5
                        : controller.offlineTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = controller.offlineTransactions[index];
                      final isCheckout =
                          transaction['transaction_type'] == 'checkout';

                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isCheckout ? Icons.logout : Icons.login,
                          color: isCheckout ? Colors.red : Colors.green,
                          size: 20,
                        ),
                        title: Text(
                          '${transaction['student_name'] ?? 'Unknown Student'}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${transaction['book_name'] ?? 'Unknown Book'} • ${transaction['class_name'] ?? ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isCheckout ? 'चेकआउट' : 'चेकइन',
                              style: TextStyle(
                                fontSize: 12,
                                color: isCheckout ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (transaction['retry_count'] != null &&
                                transaction['retry_count'] > 0)
                              Text(
                                'रिट्राई: ${transaction['retry_count']}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (controller.offlineTransactions.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'और ${controller.offlineTransactions.length - 5} ट्रांजैक्शन्स...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionSummary(
    String label,
    int count,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
