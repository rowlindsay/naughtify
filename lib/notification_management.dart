import 'dart:async';
import 'platform_comm.dart';
import 'dart:convert';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class NotificationManager {

  PlatformMethods pMethods;
  NotificationStorage storage;
  JSONEncoder _encoder;

  List<Session> _sessions = new List<Session>();

  NotificationManager(this.pMethods,this.storage) {
    _encoder = new JSONEncoder(this);
  }

  bool _isLoaded = false;

  bool notLoaded() {
    return !_isLoaded;
  }

  // adds the session and sorts it by time
  addSession(Session s) {
    int newerSessions = 0;
    for (Session other in _sessions) {
      if (other.newerThan(s))
        newerSessions++;
    }
    _sessions.insert(newerSessions, s);

    //// FILE WRITE!! ////
    writeToFile();
    //// !!!!!!!!!!!! ////

  }

  int getNumNotifications() {
    int num = 0;
    for (Session s in _sessions) {
      num += s.getNotifications().length;
    }
    return num;
  }

  int getNumSessions() {
    return _sessions.length;
  }

  List<Session> getSessions() {
    return _sessions;
  }

  Session getSession(int index) {
    return _sessions[index];
  }

  bool contains(NotificationEntry n) {
    for (Session s in _sessions) {
      if (s.contains(n))
        return true;
    }
    return false;
  }

  // TODO: figure out why it doesn't work for new sessions
  void eraseHistory() {
    _sessions.clear();
    storage.writeInfo('[]');
  }

  //TODO: test for jank and maybe move to separate isolate

  // checks platform class and decodes
  Future<String> decodeNewNotifications() async {
    String info = await pMethods.fetchNotifications();
    _encoder.decode(info);
    return info;
  }

  // decodes history
  Future<String> decodeFromFile() async {
    if (!_isLoaded) {
      String info = await storage.readInfo();
      _encoder.decode(info);
      // TODO: exceptions
      _isLoaded = true;
      return info;
    } else {
      return 'already loaded';
    }
  }

  Future<File> writeToFile() async {
    String encodedInfo = '[${_encoder.encodeSessions()}]';
    return await storage.writeInfo(encodedInfo);
  }

}

// MODELS

class Session {

  List<NotificationEntry> _notifications;

  int newest = 0;
  String start, end;

  Session(this.start,this.end) {
    _notifications = new List<NotificationEntry>();
  }

  // adds and sorts notification
  add(NotificationEntry n) {
    int newer = 0;
    for (NotificationEntry other in _notifications) {
      if (other.timeCode > n.timeCode)
        newer++;
    }
    _notifications.insert(newer, n);
    if (newer == 0)
      newest = n.timeCode;
  }

  bool contains(NotificationEntry n) {
    return _notifications.contains(n);
  }

  int length() {
    return _notifications.length;
  }

  bool newerThan(Session other) {
    return newest > other.newest;
  }

  String getStartTime() {
    return start;
  }

  String getEndTime() {
    return end;
  }

  List<NotificationEntry> getNotifications() {
    return _notifications;
  }

  int getNumNotifications() {
    return _notifications.length;
  }
}

class NotificationEntry {

  String packageName;
  int timeCode;
  String rawInfo;
  String title;
  String text;
  Image packIcon;

  NotificationEntry(this.packageName, this.timeCode);

  // using automatic decoding to model
  NotificationEntry.fromJSON(Map<String, dynamic> jsonObject)
    : packageName = jsonObject['packagename'],
      timeCode = jsonObject['timecode'],
      rawInfo = jsonObject['rawinfo'],
      title = jsonObject['title'],
      text = jsonObject['text'];



  Future<Image> getPackIcon(NotificationStorage storage) async {
    if (packIcon == null) {
      packIcon = await storage.getPackIcon(packageName);
    }
    return packIcon;
  }


  // equality used to remove duplicate notifications (currently buggy)

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is NotificationEntry &&
              runtimeType == other.runtimeType &&
              packageName == other.packageName &&
              sqrt(pow((other.timeCode - timeCode),2)) < 100; // Filter out close notifs
              //TODO: fix this (apps that send two things)

  @override
  int get hashCode =>
      packageName.hashCode ^
      timeCode.hashCode;
}

// STORAGE

class NotificationStorage {

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return  directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    print('local path: $path');
    return new File('$path/sessions.json');
  }

  Future<String> readInfo() async {
    try {
      final file = await _localFile;
      return await file.readAsString();
    } catch (e) {
      print('error reading history file : $e');
      return '[]';
    }
  }

  Future<File> writeInfo(String info) async {
    final file = await _localFile;
    return await file.writeAsString(info);
  }

  Future<Image> getPackIcon(String packName) async {
    final path = await _localPath;
    File iconFile = new File('$path/packicons/${packName}.png');
    return new Image.file(iconFile);
  }
}

class Utilities {

  static String convertTime(int millis) {
    DateTime date = new DateTime.fromMillisecondsSinceEpoch(millis);

    var format = new DateFormat("Hms");
    var timeString = format.format(date);

    return timeString;
  }

}

class JSONEncoder {

  NotificationManager manager;

  JSONEncoder(this.manager);

  decode(String info) {

    // DEPENDENT ON JSON FORMAT

    List sessions = json.decode(info);

    for (Map sessionInfo in sessions) {

      Session session = new Session(sessionInfo["starttime"],sessionInfo["endtime"]);
      List notifications = sessionInfo['notifications'];

      for (Map notificationInfo in notifications) {
        var notification = NotificationEntry.fromJSON(notificationInfo);
        if (!manager.contains(notification))
          session.add(notification);
      }

      if (session.length() > 0)
        manager.addSession(session);
    }

  }

  // MANUAL ENCODING

  String encodeSessions({int index = 0}) {
    if (index >= manager.getSessions().length) {
      return "";
    } else if (index >= 1) {
      return ',${encodeSession(manager.getSession(index))}' + encodeSessions(index: index+1);
    } else {
      return '${encodeSession(manager.getSession(index))}' + encodeSessions(index: index+1);
    }
  }

  String encodeSession(Session s) {
    return '{"starttime": "${s.getStartTime()}","endtime": "${s.getEndTime()}","notifications": [${_encodeNotifications(s)}]}';
  }

  String _encodeNotifications(Session s, {int index = 0}) {
    List<NotificationEntry> notifications = s.getNotifications();
    if (index >= notifications.length) {
      return "";
    } else if (index >= 1) {
      return ',${_encodeNotification(notifications[index])}' + _encodeNotifications(s, index: index + 1);
    } else {
      return '${_encodeNotification(notifications[index])}' + _encodeNotifications(s, index: index + 1);
    }
  }

  String _encodeNotification(NotificationEntry n) {
    return '{"timecode": ${n.timeCode},"packagename": "${n.packageName}",'
        '"rawinfo": "${n.rawInfo}","title": "${n.title}","text": "${n.text}"}';
  }

}
