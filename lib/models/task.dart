enum TaskEnergy { deep, light, social }
enum TaskSection { morning, midday, afternoon }

TaskEnergy taskEnergyFromDatabase(String value) => TaskEnergy.values.firstWhere(
      (item) => item.name.toLowerCase() == value.toLowerCase(),
      orElse: () => TaskEnergy.light,
    );

TaskSection taskSectionFromDatabase(String value) => TaskSection.values.firstWhere(
      (item) => item.name.toLowerCase() == value.toLowerCase(),
      orElse: () => TaskSection.afternoon,
    );

class Task {
  const Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.note,
    required this.time,
    required this.minutes,
    required this.energy,
    required this.done,
    required this.section,
    required this.date,
  });

  factory Task.fromDatabase(Map<String, dynamic> row) => Task(
        id: row['id'].toString(),
        userId: row['user_id'].toString(),
        title: row['title'] as String,
        note: row['note'] as String,
        time: row['time'] as String,
        minutes: row['minutes'] as int,
        energy: taskEnergyFromDatabase(row['energy'] as String),
        done: row['done'] as bool,
        section: taskSectionFromDatabase(row['section'] as String),
        date: row['date'] as String,
      );

  final String id;
  final String userId;
  final String title;
  final String note;
  final String time;
  final int minutes;
  final TaskEnergy energy;
  final bool done;
  final TaskSection section;
  final String date;

  Map<String, dynamic> toDatabase() => {
        'user_id': userId,
        'title': title,
        'note': note,
        'time': time,
        'minutes': minutes,
        'energy': energy.name[0].toUpperCase() + energy.name.substring(1),
        'done': done,
        'section': section.name[0].toUpperCase() + section.name.substring(1),
        'date': date,
      };
}
