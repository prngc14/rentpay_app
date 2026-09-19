import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ContractPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> contractData;

  const ContractPreviewScreen({
    super.key,
    required this.contractData,
  });

  List<Offset> _getSignaturePoints() {
    final rawSignature = contractData['tenantSignature'];

    if (rawSignature is! List) {
      return [];
    }

    return rawSignature.map<Offset>((point) {
      final x = (point['x'] as num?)?.toDouble() ?? 0;
      final y = (point['y'] as num?)?.toDouble() ?? 0;
      return Offset(x, y);
    }).toList();
  }

  pw.Widget _buildSignatureWidget(List<Offset> signaturePoints) {
    if (signaturePoints.isEmpty) {
      return pw.Text(
        'Tenant signature has not been captured yet.',
        style: const pw.TextStyle(fontSize: 10),
      );
    }

    const boxWidth = 260.0;
    const boxHeight = 90.0;

    double minX = signaturePoints.first.dx;
    double maxX = signaturePoints.first.dx;
    double minY = signaturePoints.first.dy;
    double maxY = signaturePoints.first.dy;

    for (final point in signaturePoints) {
      if (point.dx < minX) minX = point.dx;
      if (point.dx > maxX) maxX = point.dx;
      if (point.dy < minY) minY = point.dy;
      if (point.dy > maxY) maxY = point.dy;
    }

    final rawWidth = (maxX - minX) == 0 ? 1.0 : (maxX - minX);
    final rawHeight = (maxY - minY) == 0 ? 1.0 : (maxY - minY);

    const padding = 10.0;
    final scaleX = (boxWidth - padding * 2) / rawWidth;
    final scaleY = (boxHeight - padding * 2) / rawHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    return pw.Container(
      width: boxWidth,
      height: boxHeight,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.CustomPaint(
        size: const PdfPoint(boxWidth, boxHeight),
        painter: (PdfGraphics canvas, PdfPoint size) {
          canvas
            ..setColor(PdfColors.black)
            ..setLineWidth(1.2);

          bool started = false;

          for (final point in signaturePoints) {
            final x = padding + (point.dx - minX) * scale;
            final y = size.y - (padding + (point.dy - minY) * scale);

            if (!started) {
              canvas.moveTo(x, y);
              started = true;
            } else {
              canvas.lineTo(x, y);
            }
          }

          canvas.strokePath();
        },
      ),
    );
  }

  Future<void> _generatePdf(BuildContext context) async {
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
    );

    final tenantName = contractData['tenantName'] ?? 'Tenant';
    final ownerId = contractData['ownerId'] ?? 'Owner';
    final roomNumber = contractData['roomNumber'] ?? 'Room';

    final status = contractData['status'] ?? 'Pending Signature';

    final monthlyRent = contractData['monthlyRent'] ?? 0;
    final securityDeposit = contractData['securityDeposit'] ?? 0;
    final advancePayment = contractData['advancePayment'] ?? 0;

    final electricRate = contractData['electricRate'] ?? 0;
    final waterRate = contractData['waterRate'] ?? 0;

    final terms =
        contractData['termsAndConditions'] ?? 'No terms provided';

    Timestamp? startDate = contractData['startDate'];
    Timestamp? endDate = contractData['endDate'];

    final start = startDate != null
        ? DateFormat('MMMM dd, yyyy').format(startDate.toDate())
        : '--';

    final end = endDate != null
        ? DateFormat('MMMM dd, yyyy').format(endDate.toDate())
        : '--';

    final signaturePoints = _getSignaturePoints();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(
              margin: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.blueGrey700,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        header: (context) => pw.Column(
          children: [
            pw.SizedBox(height: 8),
            pw.Text(
              'RENTAL AGREEMENT',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'RentPay Property Management System',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Divider(
              color: PdfColors.blueGrey700,
              thickness: 1.2,
            ),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey400),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated by RentPay',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ],
        ),
        build: (context) => [
          pw.SizedBox(height: 10),

          pw.Text(
            'PARTIES',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),

          pw.SizedBox(height: 6),

          pw.Text(
            'This Rental Agreement is entered into between the property owner '
            'identified by Owner ID $ownerId and the tenant identified below.',
            style: const pw.TextStyle(
              fontSize: 10,
              lineSpacing: 3,
            ),
          ),

          pw.SizedBox(height: 14),

          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(
                color: PdfColors.grey400,
              ),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PROPERTY AND PAYMENT DETAILS',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1),
                    1: pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Text(
                          'Tenant Name\n$tenantName',
                        ),
                        pw.Text(
                          'Room Number\n$roomNumber',
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 8),
                          child: pw.Text(
                            'Contract Status\n$status',
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 8),
                          child: pw.Text(
                            'Contract Term\n$start to $end',
                          ),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 8),
                          child: pw.Text(
                            'Monthly Rent\n₱$monthlyRent',
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 8),
                          child: pw.Text(
                            'Security Deposit\n₱$securityDeposit',
                          ),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 8),
                          child: pw.Text(
                            'Advance Payment\n₱$advancePayment',
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 8),
                          child: pw.Text(
                            'Utility Rates\n'
                            'Electric: ₱$electricRate/kWh\n'
                            'Water: ₱$waterRate/m³',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 18),

          pw.Text(
            'CONSIDERATION',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),

          pw.SizedBox(height: 6),

          pw.Text(
            'The Tenant agrees to pay the amounts stated in this Agreement '
            'in exchange for the use of the assigned rental premises.',
            style: const pw.TextStyle(
              fontSize: 10,
              lineSpacing: 3,
            ),
          ),

          pw.SizedBox(height: 14),

          pw.Text(
            'TERMS AND CONDITIONS',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),

          pw.SizedBox(height: 6),

          pw.Text(
            terms.trim().isEmpty
                ? 'No additional terms provided.'
                : terms,
            style: const pw.TextStyle(
              fontSize: 10,
              lineSpacing: 3,
            ),
          ),

          pw.SizedBox(height: 22),

          pw.Text(
            'ACKNOWLEDGMENT AND SIGNATURE',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),

          pw.SizedBox(height: 6),

          pw.Text(
            'By signing below, the Tenant acknowledges that the information '
            'and terms in this Rental Agreement have been reviewed and accepted.',
            style: const pw.TextStyle(
              fontSize: 10,
              lineSpacing: 3,
            ),
          ),

          pw.SizedBox(height: 16),

          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.fromLTRB(
              12,
              10,
              12,
              8,
            ),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColors.grey400,
              ),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'TENANT E-SIGNATURE',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                _buildSignatureWidget(signaturePoints),
                pw.SizedBox(height: 6),
                pw.Divider(
                  color: PdfColors.grey700,
                ),
                pw.Text(
                  'Tenant: $tenantName',
                  style: const pw.TextStyle(
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // =====================================================
  // SMALL DETAIL ROW
  // =====================================================

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 10),
          Text(
            "$label: ",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xff1D1D1F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenantName = contractData['tenantName'] ?? 'Tenant';
    final roomNumber = contractData['roomNumber'] ?? 'Room';
    final status = contractData['status'] ?? 'Pending Signature';
    final terms =
        contractData['termsAndConditions'] ?? 'No terms provided';
    final monthlyRent = contractData['monthlyRent'] ?? 0;
    final securityDeposit =
        contractData['securityDeposit'] ?? 0;
    final advancePayment =
        contractData['advancePayment'] ?? 0;
    final electricRate =
        contractData['electricRate'] ?? 0;
    final waterRate =
        contractData['waterRate'] ?? 0;

    final signaturePoints = _getSignaturePoints();
    final hasTenantSignature = signaturePoints.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),

      appBar: AppBar(
        title: const Text(
          'Contract Preview',
          style: TextStyle(
            color: Color(0xFF123E5A),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF123E5A),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: () => _generatePdf(context),
            icon: const Icon(Icons.print),
            tooltip: 'Print PDF',
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // =================================================
                // CONTRACT TITLE
                // =================================================

                const Text(
                  'RENTAL AGREEMENT CONTRACT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff1D1D1F),
                    letterSpacing: 0.2,
                  ),
                ),

                const SizedBox(height: 18),

                // =================================================
                // PARTIES
                // =================================================

                _detailRow(
                  icon: Icons.person_outline,
                  label: 'Tenant',
                  value: tenantName,
                ),

                _detailRow(
                  icon: Icons.meeting_room_outlined,
                  label: 'Room',
                  value: roomNumber.toString(),
                ),

                _detailRow(
                  icon: Icons.flag_outlined,
                  label: 'Status',
                  value: status,
                ),

                const SizedBox(height: 10),

                Divider(
                  color: Colors.grey.shade200,
                ),

                const SizedBox(height: 10),

                // =================================================
                // FINANCIALS
                // =================================================

                _detailRow(
                  icon: Icons.payments_outlined,
                  label: 'Monthly Rent',
                  value: '₱$monthlyRent',
                ),

                _detailRow(
                  icon: Icons.shield_outlined,
                  label: 'Security Deposit',
                  value: '₱$securityDeposit',
                ),

                _detailRow(
                  icon: Icons.request_quote_outlined,
                  label: 'Advance Payment',
                  value: '₱$advancePayment',
                ),

                const SizedBox(height: 10),

                Divider(
                  color: Colors.grey.shade200,
                ),

                const SizedBox(height: 10),

                // =================================================
                // UTILITIES
                // =================================================

                _detailRow(
                  icon: Icons.flash_on_outlined,
                  label: 'Electric Rate',
                  value: '₱$electricRate per kWh',
                ),

                _detailRow(
                  icon: Icons.water_drop_outlined,
                  label: 'Water Rate',
                  value: '₱$waterRate per m³',
                ),

                const SizedBox(height: 18),

                // =================================================
                // SUMMARY
                // =================================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xffF7F7FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.notes_outlined,
                            size: 15,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Contract Summary',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Text(
                        terms,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                Divider(
                  color: Colors.grey.shade200,
                ),

                const SizedBox(height: 12),

                // =================================================
                // SIGNATURE
                // =================================================

                Row(
                  children: [
                    Text(
                      'Tenant Signature Preview',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                if (hasTenantSignature)
                  SizedBox(
                    width: double.infinity,
                    height: 140,
                    child: ClipRect(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: SignaturePreviewPainter(
                          signaturePoints,
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    child: Text(
                      'Tenant signature has not been captured yet.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),

                const SizedBox(height: 18),

                Divider(
                  color: Colors.grey.shade200,
                ),

                const SizedBox(height: 10),

                // =================================================
                // PDF NOTE
                // =================================================

                Row(
                  children: [
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Printable PDF-ready document',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// SIGNATURE PREVIEW PAINTER
// =====================================================

class SignaturePreviewPainter extends CustomPainter {
  final List<ui.Offset> points;

  SignaturePreviewPainter(this.points);

  @override
  void paint(
    ui.Canvas canvas,
    ui.Size size,
  ) {
    if (points.length < 2) {
      return;
    }

    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;

    for (final point in points) {
      if (point.dx < minX) minX = point.dx;
      if (point.dx > maxX) maxX = point.dx;
      if (point.dy < minY) minY = point.dy;
      if (point.dy > maxY) maxY = point.dy;
    }

    final rawWidth =
        (maxX - minX) == 0 ? 1.0 : (maxX - minX);

    final rawHeight =
        (maxY - minY) == 0 ? 1.0 : (maxY - minY);

    const padding = 12.0;

    final scaleX =
        (size.width - padding * 2) / rawWidth;

    final scaleY =
        (size.height - padding * 2) / rawHeight;

    final scale =
        scaleX < scaleY ? scaleX : scaleY;

    // =====================================================
    // CENTER SIGNATURE
    // =====================================================

    final scaledWidth = rawWidth * scale;
    final scaledHeight = rawHeight * scale;

    final offsetX =
        (size.width - scaledWidth) / 2;

    final offsetY =
        (size.height - scaledHeight) / 2;

    final paint = ui.Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..strokeCap = ui.StrokeCap.round;

    ui.Offset transform(ui.Offset point) {
      return ui.Offset(
        offsetX + (point.dx - minX) * scale,
        offsetY + (point.dy - minY) * scale,
      );
    }

    for (int i = 1; i < points.length; i++) {
      final previousPoint =
          transform(points[i - 1]);

      final currentPoint =
          transform(points[i]);

      canvas.drawLine(
        previousPoint,
        currentPoint,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant SignaturePreviewPainter oldDelegate,
  ) {
    return oldDelegate.points != points;
  }
}