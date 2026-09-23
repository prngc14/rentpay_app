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

  // =====================================================
  // SIGNATURE DATA
  // =====================================================

  List<Offset> _getSignaturePoints(String fieldName) {
    final rawSignature = contractData[fieldName];

    if (rawSignature is! List) {
      return [];
    }

    final points = <Offset>[];

    for (final point in rawSignature) {
      if (point is! Map) continue;

      final x = (point['x'] as num?)?.toDouble() ?? 0.0;
      final y = (point['y'] as num?)?.toDouble() ?? 0.0;

      points.add(Offset(x, y));
    }

    return points;
  }

  // =====================================================
  // PDF SIGNATURE WIDGET
  // =====================================================

  pw.Widget _buildSignatureWidget(
    List<Offset> signaturePoints, {
    required String emptyMessage,
  }) {
    if (signaturePoints.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(
            color: PdfColors.grey400,
          ),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(
          emptyMessage,
          style: const pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey700,
          ),
        ),
      );
    }

    const boxWidth = 260.0;
    const boxHeight = 90.0;
    const padding = 10.0;

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

    final rawWidth = (maxX - minX) == 0 ? 1.0 : maxX - minX;

    final rawHeight = (maxY - minY) == 0 ? 1.0 : maxY - minY;

    final scaleX = (boxWidth - padding * 2) / rawWidth;

    final scaleY = (boxHeight - padding * 2) / rawHeight;

    final scale = scaleX < scaleY ? scaleX : scaleY;

    return pw.Container(
      width: boxWidth,
      height: boxHeight,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: PdfColors.grey400,
        ),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.CustomPaint(
        size: const PdfPoint(
          boxWidth,
          boxHeight,
        ),
        painter: (
          PdfGraphics canvas,
          PdfPoint size,
        ) {
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

  // =====================================================
  // PDF SIGNATURE SECTION
  // =====================================================

  pw.Widget _buildPdfSignatureSection({
    required String title,
    required String name,
    required List<Offset> points,
    required String emptyMessage,
  }) {
    return pw.Container(
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
            title,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          _buildSignatureWidget(
            points,
            emptyMessage: emptyMessage,
          ),
          pw.SizedBox(height: 6),
          pw.Divider(
            color: PdfColors.grey700,
          ),
          pw.Text(
            name,
            style: const pw.TextStyle(
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // GENERATE PDF
  // =====================================================

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

    final ownerName = contractData['ownerName'] ?? 'Owner';

    final roomNumber = contractData['roomNumber'] ?? 'Room';

    final status = contractData['status'] ?? 'Pending Signature';

    final monthlyRent = contractData['monthlyRent'] ?? 0;

    final securityDeposit = contractData['securityDeposit'] ?? 0;

    final advancePayment = contractData['advancePayment'] ?? 0;

    final electricRate = contractData['electricRate'] ?? 0;

    final waterRate = contractData['waterRate'] ?? 0;

    final terms = contractData['termsAndConditions'] ?? 'No terms provided';

    final startDate = contractData['startDate'];

    final endDate = contractData['endDate'];

    final start = startDate is Timestamp
        ? DateFormat(
            'MMMM dd, yyyy',
          ).format(startDate.toDate())
        : '--';

    final end = endDate is Timestamp
        ? DateFormat(
            'MMMM dd, yyyy',
          ).format(endDate.toDate())
        : '--';

    final ownerSignaturePoints = _getSignaturePoints('ownerSignature');

    final tenantSignaturePoints = _getSignaturePoints('tenantSignature');

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
            pw.Divider(
              color: PdfColors.grey400,
            ),
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
            'This Rental Agreement is entered into between '
            'the property owner identified below and the '
            'tenant identified in this agreement.',
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
                          'Owner Name\n$ownerName',
                        ),
                        pw.Text(
                          'Tenant Name\n$tenantName',
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(
                            top: 8,
                          ),
                          child: pw.Text(
                            'Room Number\n$roomNumber',
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(
                            top: 8,
                          ),
                          child: pw.Text(
                            'Contract Status\n$status',
                          ),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(
                            top: 8,
                          ),
                          child: pw.Text(
                            'Contract Term\n$start to $end',
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(
                            top: 8,
                          ),
                          child: pw.Text(
                            'Monthly Rent\n₱$monthlyRent',
                          ),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(
                            top: 8,
                          ),
                          child: pw.Text(
                            'Security Deposit\n₱$securityDeposit',
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(
                            top: 8,
                          ),
                          child: pw.Text(
                            'Advance Payment\n₱$advancePayment',
                          ),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(
                            top: 8,
                          ),
                          child: pw.Text(
                            'Electric Rate\n₱$electricRate/kWh',
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(
                            top: 8,
                          ),
                          child: pw.Text(
                            'Water Rate\n₱$waterRate/m³',
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
            'The Tenant agrees to pay the amounts stated '
            'in this Agreement in exchange for the use '
            'of the assigned rental premises.',
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
            terms.toString().trim().isEmpty
                ? 'No additional terms provided.'
                : terms.toString(),
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
            'By signing below, the Owner and Tenant acknowledge '
            'that the information and terms in this Rental '
            'Agreement have been reviewed and accepted.',
            style: const pw.TextStyle(
              fontSize: 10,
              lineSpacing: 3,
            ),
          ),
          pw.SizedBox(height: 16),
          _buildPdfSignatureSection(
            title: 'OWNER E-SIGNATURE',
            name: 'Owner: $ownerName',
            points: ownerSignaturePoints,
            emptyMessage: 'Owner signature has not been captured yet.',
          ),
          pw.SizedBox(height: 14),
          _buildPdfSignatureSection(
            title: 'TENANT E-SIGNATURE',
            name: 'Tenant: $tenantName',
            points: tenantSignaturePoints,
            emptyMessage: 'Tenant signature has not been captured yet.',
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return pdf.save();
      },
    );
  }

  // =====================================================
  // DETAIL ROW
  // =====================================================

  Widget _detailRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 15,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // SIGNATURE PREVIEW
  // =====================================================

  Widget _buildSignaturePreview({
    required BuildContext context,
    required List<Offset> points,
    required String emptyMessage,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    if (points.isEmpty) {
      return SizedBox(
        height: 70,
        child: Center(
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 70,
      width: double.infinity,
      child: ClipRect(
        child: CustomPaint(
          painter: SignaturePreviewPainter(
            points,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final tenantName = contractData['tenantName'] ?? 'Tenant';

    final ownerName = contractData['ownerName'] ?? 'Owner';

    final roomNumber = contractData['roomNumber'] ?? 'Room';

    final status = contractData['status'] ?? 'Pending Signature';

    final terms = contractData['termsAndConditions'] ?? 'No terms provided';

    final monthlyRent = contractData['monthlyRent'] ?? 0;

    final securityDeposit = contractData['securityDeposit'] ?? 0;

    final advancePayment = contractData['advancePayment'] ?? 0;

    final electricRate = contractData['electricRate'] ?? 0;

    final waterRate = contractData['waterRate'] ?? 0;

    final ownerSignaturePoints = _getSignaturePoints('ownerSignature');

    final tenantSignaturePoints = _getSignaturePoints('tenantSignature');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Contract Preview',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: () => _generatePdf(context),
            icon: Icon(
              Icons.print,
              color: colorScheme.onSurface,
              size: 21,
            ),
            tooltip: 'Print PDF',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =================================================
              // CONTRACT TITLE
              // =================================================

              Text(
                'RENTAL AGREEMENT CONTRACT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                  letterSpacing: 0.1,
                ),
              ),

              const SizedBox(height: 8),

              // =================================================
              // BASIC DETAILS
              // =================================================

              _detailRow(
                context: context,
                icon: Icons.person_outline,
                label: 'Owner',
                value: ownerName.toString(),
              ),

              _detailRow(
                context: context,
                icon: Icons.person_outline,
                label: 'Tenant',
                value: tenantName.toString(),
              ),

              _detailRow(
                context: context,
                icon: Icons.meeting_room_outlined,
                label: 'Room',
                value: roomNumber.toString(),
              ),

              _detailRow(
                context: context,
                icon: Icons.flag_outlined,
                label: 'Status',
                value: status.toString(),
              ),

              const SizedBox(height: 5),

              Divider(
                color: colorScheme.outlineVariant,
                height: 1,
              ),

              const SizedBox(height: 5),

              // =================================================
              // PAYMENT DETAILS
              // =================================================

              _detailRow(
                context: context,
                icon: Icons.payments_outlined,
                label: 'Monthly Rent',
                value: '₱$monthlyRent',
              ),

              _detailRow(
                context: context,
                icon: Icons.shield_outlined,
                label: 'Security Deposit',
                value: '₱$securityDeposit',
              ),

              _detailRow(
                context: context,
                icon: Icons.request_quote_outlined,
                label: 'Advance Payment',
                value: '₱$advancePayment',
              ),

              const SizedBox(height: 5),

              Divider(
                color: colorScheme.outlineVariant,
                height: 1,
              ),

              const SizedBox(height: 5),

              // =================================================
              // UTILITY DETAILS
              // =================================================

              _detailRow(
                context: context,
                icon: Icons.flash_on_outlined,
                label: 'Electric Rate',
                value: '₱$electricRate per kWh',
              ),

              _detailRow(
                context: context,
                icon: Icons.water_drop_outlined,
                label: 'Water Rate',
                value: '₱$waterRate per m³',
              ),

              const SizedBox(height: 8),

              // =================================================
              // CONTRACT SUMMARY
              // =================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.notes_outlined,
                          size: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Contract Summary',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      terms.toString().trim().isEmpty
                          ? 'No additional terms provided.'
                          : terms.toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 7),

              Divider(
                color: colorScheme.outlineVariant,
                height: 1,
              ),

              const SizedBox(height: 7),

              // =================================================
              // SIGNATURES SIDE BY SIDE
              // TENANT LEFT / OWNER RIGHT
              // =================================================

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tenant E-Signature',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 3),
                        _buildSignaturePreview(
                          context: context,
                          points: tenantSignaturePoints,
                          emptyMessage: 'Not signed',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Owner E-Signature',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 3),
                        _buildSignaturePreview(
                          context: context,
                          points: ownerSignaturePoints,
                          emptyMessage: 'Not signed',
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              Divider(
                color: colorScheme.outlineVariant,
                height: 1,
              ),

              const SizedBox(height: 5),

              // =================================================
              // PDF FOOTER LABEL
              // =================================================

              Row(
                children: [
                  Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Printable PDF-ready document',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// SIGNATURE PAINTER
// =====================================================

class SignaturePreviewPainter extends CustomPainter {
  final List<ui.Offset> points;
  final Color color;

  SignaturePreviewPainter(
    this.points, {
    this.color = Colors.black,
  });

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

    final rawWidth = (maxX - minX) == 0 ? 1.0 : maxX - minX;

    final rawHeight = (maxY - minY) == 0 ? 1.0 : maxY - minY;

    const padding = 8.0;

    final availableWidth = size.width - padding * 2;

    final availableHeight = size.height - padding * 2;

    final scaleX = availableWidth / rawWidth;

    final scaleY = availableHeight / rawHeight;

    final scale = scaleX < scaleY ? scaleX : scaleY;

    final scaledWidth = rawWidth * scale;

    final scaledHeight = rawHeight * scale;

    final offsetX = (size.width - scaledWidth) / 2;

    final offsetY = (size.height - scaledHeight) / 2;

    final paint = ui.Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..style = ui.PaintingStyle.stroke;

    ui.Offset transform(ui.Offset point) {
      return ui.Offset(
        offsetX + (point.dx - minX) * scale,
        offsetY + (point.dy - minY) * scale,
      );
    }

    for (int i = 1; i < points.length; i++) {
      final previousPoint = transform(points[i - 1]);

      final currentPoint = transform(points[i]);

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
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}
