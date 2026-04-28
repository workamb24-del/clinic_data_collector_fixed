
import 'dart:convert';
import 'dart:html' as html;
import 'package:csv/csv.dart';
import 'models.dart';

Future<void> exportClinicsToCsv(List<ClinicModel> clinics) async {
  final rows = <List<dynamic>>[
    [
      'Code',
      'Clinic Name',
      'Doctor Name',
      'Mobile',
      'Phone',
      'Specialty',
      'City',
      'Area',
      'Address',
      'Latitude',
      'Longitude',
      'Status',
      'Created By',
      'Created At',
      'Image URL',
      'Raw Text',
      'Confidence',
    ],
    ...clinics.map((c) => [
      c.code,
      c.clinicName ?? '',
      c.doctorName ?? '',
      c.mobile ?? '',
      c.phone ?? '',
      c.specialty ?? '',
      c.city ?? '',
      c.area ?? '',
      c.addressText ?? '',
      c.lat ?? '',
      c.lng ?? '',
      c.status,
      c.createdBy ?? '',
      c.createdAt.toIso8601String(),
      c.imageUrl ?? '',
      c.rawText ?? '',
      c.confidence ?? '',
    ]),
  ];

  final csv = const ListToCsvConverter().convert(rows);
  final bytes = utf8.encode('\ufeff$csv'); // BOM keeps Arabic readable in Excel.
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final now = DateTime.now();
  final fileName = 'clinics_export_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}.csv';
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
