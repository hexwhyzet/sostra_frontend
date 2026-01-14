class IncidentStatistics {
  final int totalCount;
  final Map<String, StatusStatistics> statusStatistics;
  final Map<int, LevelStatistics> levelStatistics;
  final CriticalStatistics criticalStatistics;
  final double averageLevel;
  final Map<int, PointStatistics> pointStatistics;
  final Map<int, ResponsibleStatistics> responsibleStatistics;
  final List<IncidentListItem> incidents;

  IncidentStatistics({
    required this.totalCount,
    required this.statusStatistics,
    required this.levelStatistics,
    required this.criticalStatistics,
    required this.averageLevel,
    required this.pointStatistics,
    required this.responsibleStatistics,
    required this.incidents,
  });

  factory IncidentStatistics.fromJson(Map<String, dynamic> json) {
    Map<String, StatusStatistics> statusStats = {};
    if (json['status_statistics'] != null) {
      json['status_statistics'].forEach((key, value) {
        statusStats[key] = StatusStatistics.fromJson(value);
      });
    }

    Map<int, LevelStatistics> levelStats = {};
    if (json['level_statistics'] != null) {
      json['level_statistics'].forEach((key, value) {
        levelStats[int.parse(key.toString())] = LevelStatistics.fromJson(value);
      });
    }

    Map<int, PointStatistics> pointStats = {};
    if (json['point_statistics'] != null) {
      json['point_statistics'].forEach((key, value) {
        pointStats[int.parse(key.toString())] = PointStatistics.fromJson(value);
      });
    }

    Map<int, ResponsibleStatistics> responsibleStats = {};
    if (json['responsible_statistics'] != null) {
      json['responsible_statistics'].forEach((key, value) {
        responsibleStats[int.parse(key.toString())] =
            ResponsibleStatistics.fromJson(value);
      });
    }

    List<IncidentListItem> incidentsList = [];
    if (json['incidents'] != null) {
      incidentsList = (json['incidents'] as List)
          .map((item) => IncidentListItem.fromJson(item))
          .toList();
    }

    return IncidentStatistics(
      totalCount: json['total_count'] ?? 0,
      statusStatistics: statusStats,
      levelStatistics: levelStats,
      criticalStatistics: CriticalStatistics.fromJson(
          json['critical_statistics'] ?? {}),
      averageLevel: (json['average_level'] ?? 0).toDouble(),
      pointStatistics: pointStats,
      responsibleStatistics: responsibleStats,
      incidents: incidentsList,
    );
  }
}

class StatusStatistics {
  final int count;
  final String display;
  final double percentage;

  StatusStatistics({
    required this.count,
    required this.display,
    required this.percentage,
  });

  factory StatusStatistics.fromJson(Map<String, dynamic> json) {
    return StatusStatistics(
      count: json['count'] ?? 0,
      display: json['display'] ?? '',
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}

class LevelStatistics {
  final int count;
  final double percentage;

  LevelStatistics({
    required this.count,
    required this.percentage,
  });

  factory LevelStatistics.fromJson(Map<String, dynamic> json) {
    return LevelStatistics(
      count: json['count'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}

class CriticalStatistics {
  final CriticalItem critical;
  final CriticalItem nonCritical;

  CriticalStatistics({
    required this.critical,
    required this.nonCritical,
  });

  factory CriticalStatistics.fromJson(Map<String, dynamic> json) {
    return CriticalStatistics(
      critical: CriticalItem.fromJson(json['critical'] ?? {}),
      nonCritical: CriticalItem.fromJson(json['non_critical'] ?? {}),
    );
  }
}

class CriticalItem {
  final int count;
  final double percentage;

  CriticalItem({
    required this.count,
    required this.percentage,
  });

  factory CriticalItem.fromJson(Map<String, dynamic> json) {
    return CriticalItem(
      count: json['count'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}

class PointStatistics {
  final String name;
  final int count;
  final double percentage;

  PointStatistics({
    required this.name,
    required this.count,
    required this.percentage,
  });

  factory PointStatistics.fromJson(Map<String, dynamic> json) {
    return PointStatistics(
      name: json['name'] ?? '',
      count: json['count'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}

class ResponsibleStatistics {
  final String name;
  final int count;
  final double percentage;

  ResponsibleStatistics({
    required this.name,
    required this.count,
    required this.percentage,
  });

  factory ResponsibleStatistics.fromJson(Map<String, dynamic> json) {
    return ResponsibleStatistics(
      name: json['name'] ?? '',
      count: json['count'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }
}

class IncidentListItem {
  final int id;
  final String name;
  final String description;
  final String status;
  final int level;
  final bool isCritical;
  final DateTime createdAt;
  final int? authorId;
  final String? authorName;
  final int? responsibleUserId;
  final String? responsibleUserName;
  final int? pointId;
  final String? pointName;

  IncidentListItem({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.level,
    required this.isCritical,
    required this.createdAt,
    this.authorId,
    this.authorName,
    this.responsibleUserId,
    this.responsibleUserName,
    this.pointId,
    this.pointName,
  });

  factory IncidentListItem.fromJson(Map<String, dynamic> json) {
    return IncidentListItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? '',
      level: json['level'] ?? 0,
      isCritical: json['is_critical'] ?? false,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      authorId: json['author__id'],
      authorName: json['author__display_name'],
      responsibleUserId: json['responsible_user__id'],
      responsibleUserName: json['responsible_user__display_name'],
      pointId: json['point__id'],
      pointName: json['point__name'],
    );
  }
}

