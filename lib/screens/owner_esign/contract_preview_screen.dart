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

    final terms = contractData['termsAndConditions'] ?? 'No terms provided';

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
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => pw.Container(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'RENTAL AGREEMENT CONTRACT',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'Generated from RentPay',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 24),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Contract Summary',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text('Tenant Name: $tenantName'),
                    pw.Text('Room Number: $roomNumber'),
                    pw.Text('Owner ID: $ownerId'),
                    pw.Text('Status: $status'),
                    pw.Text('Monthly Rent: ₱$monthlyRent'),
                    pw.Text('Security Deposit: ₱$securityDeposit'),
                    pw.Text('Advance Payment: ₱$advancePayment'),
                    pw.Text('Electric Rate: ₱$electricRate per kWh'),
                    pw.Text('Water Rate: ₱$waterRate per m³'),
                    pw.Text('Start Date: $start'),
                    pw.Text('End Date: $end'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Terms and Conditions',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(terms, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 24),
              pw.Text(
                'Tenant Signature',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildSignatureWidget(signaturePoints),
            ],
          ),
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // ==========================================================
  // SMALL DETAIL ROW (icon + label + value)
  // ==========================================================
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
          Icon(icon, size: 18, color: Colors.grey.shade600),
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
    final terms = contractData['termsAndConditions'] ?? 'No terms provided';
    final monthlyRent = contractData['monthlyRent'] ?? 0;
    final securityDeposit = contractData['securityDeposit'] ?? 0;
    final advancePayment = contractData['advancePayment'] ?? 0;
    final electricRate = contractData['electricRate'] ?? 0;
    final waterRate = contractData['waterRate'] ?? 0;
    final signaturePoints = _getSignaturePoints();
    final hasTenantSignature = signaturePoints.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(
        title: const Text('Contract Preview'),
        backgroundColor: Colors.deepOrange,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: Colors.deepOrange,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'RENTAL AGREEMENT CONTRACT',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ================= PARTIES =================
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
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 10),

                // ================= FINANCIALS =================
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
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 10),

                // ================= UTILITIES =================
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

                // ================= SUMMARY =================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xffF7F7FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 12),

                // ================= SIGNATURE =================
                Row(
                  children: [
                    Icon(
                      Icons.draw_outlined,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 6),
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
                const SizedBox(height: 10),
                if (hasTenantSignature)
                  Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white,
                    ),
                    // ✅ FIXED: ClipRRect + fixed painter (may scaling/
                    // fitting na ngayon, kaya hindi na umaapaw ang
                    // signature palabas ng box).
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: SignaturePreviewPainter(signaturePoints),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Tenant signature has not been captured yet.',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 18),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 10),

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

// ✅ FIXED: normalize/scale ang signature points papasok sa laman ng
// box (parehong logic gaya ng ginagamit ng PDF generator sa itaas)
// -- dati, raw coordinates lang ang direktang idinra-draw, kaya
// umaapaw ang signature palabas ng preview box kapag mas malaki ang
// orihinal na drawing kaysa sa laki ng box na ito.
class SignaturePreviewPainter extends CustomPainter {
  final List<ui.Offset> points;

  SignaturePreviewPainter(this.points);

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
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

    final rawWidth = (maxX - minX) == 0 ? 1.0 : (maxX - minX);
    final rawHeight = (maxY - minY) == 0 ? 1.0 : (maxY - minY);

    const padding = 12.0;
    final scaleX = (size.width - padding * 2) / rawWidth;
    final scaleY = (size.height - padding * 2) / rawHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    // I-center ang drawing sa loob ng box
    final scaledWidth = rawWidth * scale;
    final scaledHeight = rawHeight * scale;
    final offsetX = (size.width - scaledWidth) / 2;
    final offsetY = (size.height - scaledHeight) / 2;

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
      final previousPoint = transform(points[i - 1]);
      final currentPoint = transform(points[i]);
      canvas.drawLine(previousPoint, currentPoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePreviewPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}