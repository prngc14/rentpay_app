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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RENTAL AGREEMENT CONTRACT',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Tenant: $tenantName'),
                    Text('Room: $roomNumber'),
                    Text('Status: $status'),
                    const SizedBox(height: 8),
                    Text('Monthly Rent: ₱$monthlyRent'),
                    Text('Security Deposit: ₱$securityDeposit'),
                    Text('Advance Payment: ₱$advancePayment'),
                    const SizedBox(height: 8),
                    Text('Electric Rate: ₱$electricRate per kWh'),
                    Text('Water Rate: ₱$waterRate per m³'),
                    const SizedBox(height: 16),
                    const Text(
                      'Contract Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(terms),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Tenant Signature Preview',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (hasTenantSignature)
                      Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: CustomPaint(
                          painter: SignaturePreviewPainter(signaturePoints),
                          child: Container(),
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
                        child: const Text(
                          'Tenant signature has not been captured yet.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 10),
                    const Text(
                      'Printable PDF-ready document',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignaturePreviewPainter extends CustomPainter {
  final List<ui.Offset> points;

  SignaturePreviewPainter(this.points);

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    if (points.length < 2) {
      return;
    }

    final paint = ui.Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..strokeCap = ui.StrokeCap.round;

    for (int i = 1; i < points.length; i++) {
      final previousPoint = points[i - 1];
      final currentPoint = points[i];
      canvas.drawLine(previousPoint, currentPoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePreviewPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}