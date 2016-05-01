// Copyright (c) 2016, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// import 'dart:convert' show JSON;
import 'dart:html' hide Event;

import 'package:charted/charts/charts.dart';
import 'package:firebase/firebase.dart';

Firebase firebase;
CartesianArea chartArea;

Map<int, Measurement> repoMeasurements;
Map<int, Measurement> galleryMeasurements;

// TODO: Tooltips should include sdk and commit info.

void main() {
  updateTimeSeriesChart('#time-series-chart');

  firebase = new Firebase("https://charted-firebase.firebaseio.com/");

  Firebase repoAnalysis = firebase.child("analysis/repo");
  Firebase galleryAnalysis = firebase.child("analysis/gallery");

  DateTime startDate = new DateTime.now().subtract(new Duration(days: 90));

  Query repoQuery = repoAnalysis
    .orderByChild('date')
    .startAt(key: 'date', value: startDate.millisecondsSinceEpoch)
    .limitToLast(1000);
  Query galleryQuery = galleryAnalysis
    .orderByChild('date')
    .startAt(key: 'date', value: startDate.millisecondsSinceEpoch)
    .limitToLast(1000);

  repoQuery.onValue.listen((Event event) {
    repoMeasurements = {};
    event.snapshot.forEach((DataSnapshot snapshot) {
      Measurement measurement = new Measurement(snapshot.val());
      repoMeasurements[measurement.dateMillis] = measurement;
    });
    _updateChart();
  });
  galleryQuery.onValue.listen((Event event) {
    galleryMeasurements = {};
    event.snapshot.forEach((DataSnapshot snapshot) {
      Measurement measurement = new Measurement(snapshot.val());
      galleryMeasurements[measurement.dateMillis] = measurement;
    });
    _updateChart();
  });
}

void _updateChart() {
  if (repoMeasurements == null || galleryMeasurements == null) return;

  List<int> times = new List.from(new Set<int>()
    ..addAll(repoMeasurements.keys)
    ..addAll(galleryMeasurements.keys)
  )..sort();

  List data = times.map((int time) {
    return [time, repoMeasurements[time]?.duration, galleryMeasurements[time]?.duration];
  }).toList();

  updateTimeSeriesChart('#time-series-chart', data);
}

class Measurement {
  final Map map;

  // {date: 1461740400000, duration: 18.599, sdk: 1.17.0-dev.1.0, commit: ab47234}
  Measurement(this.map);

  String get sdk => map['sdk'];
  String get commit => map['commit'];
  num get duration => map['duration'];
  num get dateMillis => map['date'];

  DateTime get date => new DateTime.fromMillisecondsSinceEpoch(dateMillis);

  String get dateString {
    DateTime d = date;
    return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  }

  String toString() => '${duration}s (${dateString})';
}

void updateTimeSeriesChart(String wrapperSelector, [List data]) {
  if (chartArea != null) {
    chartArea.data = new ChartData(_columnSpecs, data);
    chartArea.draw();
  } else {
    DivElement wrapper = document.querySelector(wrapperSelector);
    DivElement areaHost = wrapper.querySelector('.chart-host');
    DivElement legendHost = wrapper.querySelector('.chart-legend-host');

    data ??= _getPlaceholderData();

    ChartData chartData = new ChartData(_columnSpecs, data);
    ChartSeries series = new ChartSeries("Flutter Analysis Times", [1, 2], new LineChartRenderer());
    ChartConfig config = new ChartConfig([series], [0])..legend = new ChartLegend(legendHost);
    ChartState state = new ChartState();

    chartArea = new CartesianArea(
      areaHost,
      chartData,
      config,
      state: state
    );

    chartArea.addChartBehavior(new Hovercard(isMultiValue: true));
    chartArea.addChartBehavior(new AxisLabelTooltip());

    chartArea.draw();
  }
}

String _printDurationVal(num val) {
  if (val == null) return '';
  return val.toStringAsFixed(1) + 's';
}

Iterable _columnSpecs = [
  new ChartColumnSpec(
    label: 'Time',
    type: ChartColumnSpec.TYPE_TIMESTAMP
  ),
  new ChartColumnSpec(
    label: 'flutter analyze flutter-repo',
    type: ChartColumnSpec.TYPE_NUMBER,
    formatter: _printDurationVal
  ),
  new ChartColumnSpec(
    label: 'analysis server mega_gallery',
    type: ChartColumnSpec.TYPE_NUMBER,
    formatter: _printDurationVal
  )
];

Iterable _getPlaceholderData() {
  DateTime now = new DateTime.now();

  return [
    [now.subtract(new Duration(days: 30)).millisecondsSinceEpoch, 0.0, 0.0],
    [now.millisecondsSinceEpoch, 0.0, 0.0],
  ];
}
