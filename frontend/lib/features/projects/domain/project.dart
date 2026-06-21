/// Project summary / detail model.
class Project {
  const Project({
    required this.id,
    required this.projectNumber,
    required this.projectName,
    required this.customerName,
    required this.phone,
    required this.currentStage,
    required this.progress,
    this.altPhone,
    this.address,
    this.siteLocation,
    this.projectType,
    this.workDescription,
    this.startDate,
    this.expectedCompletionDate,
    this.quotationAmount,
    this.supervisorId,
    this.designerId,
    this.remarks,
    this.contacts,
  });

  final String id;
  final String projectNumber;
  final String projectName;
  final String customerName;
  final String phone;
  final String currentStage;
  final int progress;
  final String? altPhone;
  final String? address;
  final String? siteLocation;
  final String? projectType;
  final String? workDescription;
  final String? startDate;
  final String? expectedCompletionDate;
  final num? quotationAmount;
  final String? supervisorId;
  final String? designerId;
  final String? remarks;
  final ProjectContacts? contacts;

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'] as String,
        projectNumber: j['projectNumber'] as String? ?? '',
        projectName: j['projectName'] as String? ?? '',
        customerName: j['customerName'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        currentStage: j['currentStage'] as String? ?? 'discussion',
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        altPhone: j['altPhone'] as String?,
        address: j['address'] as String?,
        siteLocation: j['siteLocation'] as String?,
        projectType: j['projectType'] as String?,
        workDescription: j['workDescription'] as String?,
        startDate: j['startDate']?.toString(),
        expectedCompletionDate: j['expectedCompletionDate']?.toString(),
        quotationAmount: j['quotationAmount'] as num?,
        supervisorId: j['supervisorId'] as String?,
        designerId: j['designerId'] as String?,
        remarks: j['remarks'] as String?,
        contacts: j['contacts'] is Map
            ? ProjectContacts.fromJson(j['contacts'] as Map<String, dynamic>)
            : null,
      );
}

/// Contacts a worker is allowed to see (admin + supervisor only).
class ProjectContacts {
  const ProjectContacts({
    this.adminName,
    this.adminPhone,
    this.supervisorName,
    this.supervisorPhone,
  });

  final String? adminName;
  final String? adminPhone;
  final String? supervisorName;
  final String? supervisorPhone;

  factory ProjectContacts.fromJson(Map<String, dynamic> j) => ProjectContacts(
        adminName: j['adminName'] as String?,
        adminPhone: j['adminPhone'] as String?,
        supervisorName: j['supervisorName'] as String?,
        supervisorPhone: j['supervisorPhone'] as String?,
      );
}

const kProjectStages = [
  'discussion', '3d_design', 'drawing', 'material_purchase', 'cutting', 'making',
  'lamination', 'painting', 'packing', 'transport', 'installation', 'checking',
  'completed',
];
