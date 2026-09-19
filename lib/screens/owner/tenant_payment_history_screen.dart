import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../services/firestore_service.dart';
import '../../widgets/app_warning_banner.dart';

class TenantPaymentHistoryScreen extends StatelessWidget {
  final String ownerId;
  final String tenantId;
  final String tenantName;

  const TenantPaymentHistoryScreen({
    super.key,
    required this.ownerId,
    required this.tenantId,
    required this.tenantName,
  });

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestore = FirestoreService();

    final screenContext = context;

    return Scaffold(
      backgroundColor: const Color(0xffF5F8FA),
      appBar: AppBar(
        title: const Text(
          "Rentpay",
          style: TextStyle(
            fontFamily: 'RentpayScript',
            fontSize: 32,
            fontWeight: FontWeight.w400,
            color: Color(0xFF123E5A),
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF123E5A),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore.getTenantPaymentsForOwner(
          ownerId,
          tenantId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading payments:\n${snapshot.error}",
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No payments history"),
            );
          }

          final payments = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final p = payments[index];
              final data = p.data() as Map<String, dynamic>;

              final String room = data["room"] ?? "No room";

              final double amount =
                  (data["amount"] ?? 0).toDouble();

              final String screenshot =
                  data["screenshot"] ?? "";

              final String status =
                  data["status"] ?? "pending";

              final bool isPartial =
                  data["isPartial"] ?? false;

              final Timestamp? date =
                  data["date"];

              Color statusColor;

              if (status == "verified") {
                statusColor = Colors.green;
              } else if (status == "rejected") {
                statusColor = Colors.red;
              } else {
                statusColor = Colors.orange;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Room: $room",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xff1D1D1F),
                              ),
                            ),
                          ),
                          if (isPartial)
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "PARTIAL",
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      Text(
                        "Amount: ₱${amount.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),

                      const SizedBox(height: 9),

                      if (date != null)
                        Text(
                          "Submitted: ${DateFormat("yyyy-MM-dd HH:mm:ss").format(date.toDate())}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),

                      const SizedBox(height: 12),

                      if (screenshot.isNotEmpty)
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Payment Screenshot",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xff1D1D1F),
                              ),
                            ),

                            const SizedBox(height: 7),

                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    backgroundColor:
                                        Colors.transparent,
                                    insetPadding:
                                        const EdgeInsets.all(20),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      child: Container(
                                        color: Colors.white,
                                        child:
                                            InteractiveViewer(
                                          minScale: 0.5,
                                          maxScale: 4.0,
                                          child:
                                              Image.network(
                                            screenshot,
                                            fit: BoxFit.contain,
                                            errorBuilder: (
                                              context,
                                              error,
                                              stackTrace,
                                            ) {
                                              return const Padding(
                                                padding:
                                                    EdgeInsets.all(
                                                  20,
                                                ),
                                                child: Text(
                                                  "Failed to load image",
                                                  textAlign:
                                                      TextAlign
                                                          .center,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(10),
                                child: Image.network(
                                  screenshot,
                                  height: 125,
                                  width: 180,
                                  fit: BoxFit.cover,
                                  errorBuilder: (
                                    context,
                                    error,
                                    stackTrace,
                                  ) {
                                    return Container(
                                      height: 125,
                                      width: 180,
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.grey.shade200,
                                        borderRadius:
                                            BorderRadius.circular(
                                          10,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "Image not available",
                                          textAlign:
                                              TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Container(
                          width: 180,
                          padding:
                              const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text(
                              "No screenshot uploaded",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          const Text(
                            "Status: ",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),

                      if (status == "pending") ...[
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child:
                                  ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    await firestore
                                        .approvePayment(
                                      p.id,
                                      tenantId,
                                    );

                                    if (!screenContext
                                        .mounted) {
                                      return;
                                    }

                                    showAppSuccessBanner(
                                      screenContext,
                                      "Payment approved",
                                    );
                                  } catch (error) {
                                    debugPrint(
                                      "APPROVE BUTTON ERROR: $error",
                                    );

                                    if (!screenContext
                                        .mounted) {
                                      return;
                                    }

                                    final String message =
                                        error
                                                .toString()
                                                .contains(
                                                  "permission-denied",
                                                )
                                            ? "Permission denied. Check Firestore rules."
                                            : "Unable to approve payment";

                                    showAppWarningBanner(
                                      screenContext,
                                      message,
                                    );
                                  }
                                },
                                style:
                                    ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.green,
                                  foregroundColor:
                                      Colors.white,
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    vertical: 12,
                                  ),
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                      10,
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.check,
                                  size: 18,
                                ),
                                label: const Text(
                                  "Approve",
                                  style: TextStyle(
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child:
                                  ElevatedButton.icon(
                                onPressed: () async {
                                  await firestore
                                      .rejectPayment(
                                    p.id,
                                  );

                                  if (!screenContext
                                      .mounted) {
                                    return;
                                  }

                                  showAppWarningBanner(
                                    screenContext,
                                    "Payment rejected",
                                  );
                                },
                                style:
                                    ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.red,
                                  foregroundColor:
                                      Colors.white,
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    vertical: 12,
                                  ),
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                      10,
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.close,
                                  size: 18,
                                ),
                                label: const Text(
                                  "Reject",
                                  style: TextStyle(
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 8),

                      Align(
                        alignment:
                            Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () async {
                            final confirm =
                                await showDialog<bool>(
                              context: context,
                              barrierColor:
                                  Colors.black
                                      .withOpacity(0.25),
                              builder: (context) {
                                return Dialog(
                                  backgroundColor:
                                      Colors.transparent,
                                  elevation: 0,
                                  insetPadding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal: 80,
                                  ),
                                  child: Container(
                                    padding:
                                        const EdgeInsets
                                            .fromLTRB(
                                      14,
                                      13,
                                      14,
                                      11,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius
                                              .circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(
                                            0.10,
                                          ),
                                          blurRadius: 12,
                                          offset:
                                              const Offset(
                                            0,
                                            4,
                                          ),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize:
                                          MainAxisSize.min,
                                      children: [
                                        const Text(
                                          "Delete this payment?",
                                          textAlign:
                                              TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.w600,
                                            color: Color(
                                              0xff1D1D1F,
                                            ),
                                          ),
                                        ),

                                        const SizedBox(
                                          height: 11,
                                        ),

                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment
                                                  .center,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                Navigator.pop(
                                                  context,
                                                  false,
                                                );
                                              },
                                              child: Text(
                                                "Cancel",
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight
                                                          .w500,
                                                  color: Colors
                                                      .grey
                                                      .shade700,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(
                                              width: 20,
                                            ),

                                            GestureDetector(
                                              onTap: () {
                                                Navigator.pop(
                                                  context,
                                                  true,
                                                );
                                              },
                                              child:
                                                  const Text(
                                                "Delete",
                                                style:
                                                    TextStyle(
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight
                                                          .w600,
                                                  color: Color(
                                                    0xFFD93636,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );

                            if (confirm == true) {
                              await FirebaseFirestore
                                  .instance
                                  .collection("payments")
                                  .doc(p.id)
                                  .delete();

                              if (!screenContext.mounted) {
                                return;
                              }

                              showAppSuccessBanner(
                                screenContext,
                                "Payment deleted successfully",
                              );
                            }
                          },
                          child: const Text(
                            "Delete Payment",
                            style: TextStyle(
                              color: Color(0xFFD93636),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}