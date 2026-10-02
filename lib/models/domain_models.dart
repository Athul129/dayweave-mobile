import '../core/date_time/dayweave_date_time.dart';

class Note {
  const Note({required this.id, required this.userId, required this.title, required this.body, required this.createdAt, required this.updatedAt});
  factory Note.fromDatabase(Map<String, dynamic> row) => Note(
        id: row['id'].toString(), userId: row['user_id'].toString(), title: row['title'] as String, body: row['body'] as String,
        createdAt: DayweaveTimestamp.parse(row['created_at'] as String), updatedAt: DayweaveTimestamp.parse(row['updated_at'] as String),
      );
  final String id; final String userId; final String title; final String body; final DayweaveTimestamp createdAt; final DayweaveTimestamp updatedAt;
}

class DailyIntention {
  const DailyIntention({required this.userId, required this.date, required this.intention, required this.updatedAt});
  factory DailyIntention.fromDatabase(Map<String, dynamic> row) => DailyIntention(
        userId: row['user_id'].toString(), date: LocalDate.parse(row['date'] as String), intention: row['intention'] as String,
        updatedAt: DayweaveTimestamp.parse(row['updated_at'] as String),
      );
  final String userId; final LocalDate date; final String intention; final DayweaveTimestamp updatedAt;
}

class DailyReflection {
  const DailyReflection({required this.id, required this.userId, required this.date, required this.wentWell, required this.carryForward, required this.createdAt, required this.updatedAt});
  factory DailyReflection.fromDatabase(Map<String, dynamic> row) => DailyReflection(
        id: row['id'].toString(), userId: row['user_id'].toString(), date: LocalDate.parse(row['date'] as String),
        wentWell: row['went_well'] as String, carryForward: row['carry_forward'] as String,
        createdAt: DayweaveTimestamp.parse(row['created_at'] as String), updatedAt: DayweaveTimestamp.parse(row['updated_at'] as String),
      );
  final String id; final String userId; final LocalDate date; final String wentWell; final String carryForward; final DayweaveTimestamp createdAt; final DayweaveTimestamp updatedAt;
}

class FocusSession {
  const FocusSession({required this.id, required this.sessionId, required this.userId, required this.taskId, required this.taskTitle, required this.taskDate, required this.plannedDurationSeconds, required this.startedAt, required this.completedAt, required this.pausedSeconds, required this.createdAt});
  factory FocusSession.fromDatabase(Map<String, dynamic> row) => FocusSession(
        id: row['id'].toString(), sessionId: row['session_id'] as String, userId: row['user_id'].toString(), taskId: row['task_id']?.toString(),
        taskTitle: row['task_title'] as String, taskDate: row['task_date'] == null ? null : LocalDate.parse(row['task_date'] as String),
        plannedDurationSeconds: row['planned_duration_seconds'] as int, startedAt: DayweaveTimestamp.parse(row['started_at'] as String),
        completedAt: DayweaveTimestamp.parse(row['completed_at'] as String), pausedSeconds: row['paused_seconds'] as int,
        createdAt: DayweaveTimestamp.parse(row['created_at'] as String),
      );
  final String id; final String sessionId; final String userId; final String? taskId; final String taskTitle; final LocalDate? taskDate;
  final int plannedDurationSeconds; final DayweaveTimestamp startedAt; final DayweaveTimestamp completedAt; final int pausedSeconds; final DayweaveTimestamp createdAt;
}
