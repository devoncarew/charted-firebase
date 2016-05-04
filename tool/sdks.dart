
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:firebase/firebase_io.dart';

FirebaseClient firebase;

// TODO: take an arg for the sdk to use

main(List<String> args) async {
  if (args.length != 1) {
    print('usage: dart tool/sdks <sdk version>');
    exit(1);
  }

  if (Platform.environment['FIREBASE_CRED'] == null) {
    print('Please set FIREBASE_CRED.');
    exit(1);
  }

  List<SdkRelease> releases = [
    // new SdkRelease('1.15.0-dev.0.0', new DateTime(2016, DateTime.JANUARY, 28)),
    // new SdkRelease('1.15.0-dev.1.0', new DateTime(2016, DateTime.FEBRUARY, 2)),
    // new SdkRelease('1.15.0-dev.2.0', new DateTime(2016, DateTime.FEBRUARY, 10)),
    // new SdkRelease('1.15.0-dev.3.0', new DateTime(2016, DateTime.FEBRUARY, 17)),
    // new SdkRelease('1.15.0-dev.4.0', new DateTime(2016, DateTime.FEBRUARY, 24)),
    // new SdkRelease('1.15.0-dev.5.0', new DateTime(2016, DateTime.MARCH, 2)),
    // new SdkRelease('1.15.0-dev.5.1', new DateTime(2016, DateTime.MARCH, 9)),

    new SdkRelease('1.16.0-dev.0.0', new DateTime(2016, DateTime.MARCH, 10)),
    new SdkRelease('1.16.0-dev.1.0', new DateTime(2016, DateTime.MARCH, 16)),
    new SdkRelease('1.16.0-dev.2.0', new DateTime(2016, DateTime.MARCH, 22)),
    new SdkRelease('1.16.0-dev.3.0', new DateTime(2016, DateTime.MARCH, 30)),
    new SdkRelease('1.16.0-dev.4.0', new DateTime(2016, DateTime.APRIL, 6)),
    new SdkRelease('1.16.0-dev.5.0', new DateTime(2016, DateTime.APRIL, 12)),
    new SdkRelease('1.16.0-dev.5.1', new DateTime(2016, DateTime.APRIL, 17)),
    new SdkRelease('1.16.0-dev.5.2', new DateTime(2016, DateTime.APRIL, 19)),
    new SdkRelease('1.16.0-dev.5.3', new DateTime(2016, DateTime.APRIL, 19, 12)),
    new SdkRelease('1.16.0-dev.5.4', new DateTime(2016, DateTime.APRIL, 20)),
    new SdkRelease('1.16.0-dev.5.5', new DateTime(2016, DateTime.APRIL, 25)),

    new SdkRelease('1.17.0-dev.0.0', new DateTime(2016, DateTime.APRIL, 26)),
    new SdkRelease('1.17.0-dev.1.0', new DateTime(2016, DateTime.APRIL, 27)),
    new SdkRelease('1.17.0-dev.2.0', new DateTime(2016, DateTime.MAY, 4)),
  ];

  firebase = new FirebaseClient(Platform.environment['FIREBASE_CRED']);

  // TODO: use 'which'
  Directory.current = new Directory('/Users/devoncarew/projects/flutter');

  if (args.first == '--all') {
    for (SdkRelease release in releases.reversed) {
      await _measure(release);
    }
  } else {
    SdkRelease release = releases.singleWhere((release) => release.version == args.first);
    await _measure(release);
  }
}

const int kRunCount = 3;

Future _measure(SdkRelease release) async {
  print('${release}');
  File stamp = new File('bin/cache/dart-sdk.stamp');
  if (stamp.existsSync()) stamp.deleteSync();
  new File('bin/cache/dart-sdk.version').writeAsStringSync(release.version);
  await _run('bin/cache/update_dart_sdk.sh', []);

  // Run kRunCount times, take the fastest time.
  num bestGalleryTime = 1000.0;

  File benchmarkFile = new File('dev/benchmarks/mega_gallery/analysis_benchmark.json');

  for (int i = 0; i < kRunCount; i++) {
    if (benchmarkFile.existsSync()) benchmarkFile.deleteSync();
    await _run('flutter', ['analyze', '--watch', '--benchmark'],
      cwd: 'dev/benchmarks/mega_gallery', throwOnFail: false);
    num time = _getBenchmarkTime(benchmarkFile);
    print('gallery analysis in ${time} seconds.');
    bestGalleryTime = math.min(bestGalleryTime, time);
  }

  print(await firebase.post(
    Uri.parse('https://charted-firebase.firebaseio.com/analysis/gallery.json'), {
      'date': release.date.millisecondsSinceEpoch,
      'duration': bestGalleryTime,
      'sdk': release.version
    }
  ));

  // Run kRunCount times, take the fastest time.
  num bestRepoTime = 1000.0;

  benchmarkFile = new File('analysis_benchmark.json');

  for (int i = 0; i < kRunCount; i++) {
    if (benchmarkFile.existsSync()) benchmarkFile.deleteSync();
    await _run('flutter', ['analyze', '--flutter-repo', '--benchmark'], throwOnFail: false);
    num time = _getBenchmarkTime(benchmarkFile);
    print('repo analysis in ${time} seconds.');
    bestRepoTime = math.min(bestRepoTime, time);
  }

  print(await firebase.post(
    Uri.parse('https://charted-firebase.firebaseio.com/analysis/repo.json'), {
      'date': release.date.millisecondsSinceEpoch,
      'duration': bestRepoTime,
      'sdk': release.version
    }
  ));

  print('');
}

num _getBenchmarkTime(File file) {
  Map benchmark = JSON.decode(file.readAsStringSync());
  var time = benchmark['time'];
  return time is String ? double.parse(time) : time;
}

Future _run(String cmd, List<String> args, { String cwd, bool throwOnFail: true }) async {
  print('$cmd ${args.join(' ')}');
  Process process = await Process.start(cmd, args, workingDirectory: cwd);
  process.stdout
    .transform(UTF8.decoder)
    .transform(const LineSplitter())
    .listen(print);
  process.stderr
    .transform(UTF8.decoder)
    .transform(const LineSplitter())
    .listen(print);
  int exitCode = await process.exitCode.timeout(new Duration(seconds: 200)).catchError((e) {
    process.kill();
    throw e;
  });
  if (throwOnFail) {
    if (exitCode != 0) throw 'exit $exitCode';
  }
}

class SdkRelease {
  final String version;
  final DateTime date;

  SdkRelease(this.version, this.date);

  String get dateString => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String toString() => '${version} (${dateString})';
}
