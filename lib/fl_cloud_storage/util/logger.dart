import 'package:logger/logger.dart';

class MyPrinter extends LogPrinter {
  MyPrinter(this.prefix);

  final String prefix;

  @override
  List<String> log(LogEvent event) {
    return ['[$prefix] (${event.level.name}) ${event.message}'];
  }
}
