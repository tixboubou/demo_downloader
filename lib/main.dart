import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scoped_model/scoped_model.dart';


/// This dummy app allows you to download an episode.
/// Episode model is very simple and is described at the bottom of this file.
/// Ancillary class: DownloadInfo that binds an Episode with a taskId provided by the downloader.

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Flutter Demo',
      theme: new ThemeData(),
      home: new HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  Episode episode;
  EpisodeDownloader downloader;

  HomePage() {
    this.downloader = new EpisodeDownloader();
    this.episode = new Episode({
      "title": "Dummy episode",
      "guid": "dummy-episode",
      "link": "https://media-b2.classicipodcast.it/file/classicipodcast-audiobooks/audiobooks/divina_commedia/divina_commedia_002_inferno_canto_i.mp3",
    });
  }

  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Episode downloader demo',
      home: new Scaffold(
        appBar: new AppBar(title: new Text('Episode downloader demo')),
        body: new Container(
          child: new ListView(shrinkWrap: true, children: [
            // This widget will be re-rendered when episode.state changes (toDownload -> downloading...)
            // thanks to Model class provided by package:scoped_model/scoped_model.dart
            new ScopedModel<Episode>(
              model: episode,
              child: new ListTile(
                title: new Text(this.episode.title),
                trailing: new ScopedModelDescendant<Episode>(
                  builder: (context, child, episode) {
                    if (episode.state == EpisodeState.downloading) {
                      return new Container(
                        height: 32.0,
                        width: 32.0,
                        child: new Padding(
                          padding: EdgeInsets.all(6.0),
                          child: new CircularProgressIndicator(
                            strokeWidth: 2.0,
                            value: episode.downloadProgress),));
                    } else if (episode.state == EpisodeState.toDownload) {
                      return new Container(
                        height: 32.0,
                        width: 32.0,
                        child: new IconButton(
                          icon: new Icon(Icons.cloud_download),
                          onPressed: () {
                            downloader.performDownloadEpisode(episode);
                          })
                      );
                    } else {
                      return new IconButton(
                        icon: new Icon(Icons.play_arrow),
                        onPressed: () {
                          // Ellipsis
                          print("Going to play episode ${episode.title} from ${episode.localFilePath}");
                        });
                    }
                  }),
              ))
          ]),
        )));
  }
}


class DownloadInfo {
  Episode episode;
  String taskId;
  String filePath;

  DownloadInfo({this.episode, this.taskId, this.filePath});
}

class EpisodeDownloader {

  List<DownloadInfo> _downloadInfoList;

  EpisodeDownloader() {
    this._downloadInfoList = new List();

    FlutterDownloader.registerCallback((id, status, progress) {
      DownloadInfo downloadInfo = this.getDownloadInfoFromTaskId(id);
      if (downloadInfo != null) {
        if (status == DownloadTaskStatus.running) {
          downloadInfo.episode.setState(EpisodeState.downloading);
          downloadInfo.episode.setDownloadProgress(progress / 100.0);
        } else if (status == DownloadTaskStatus.complete) {
          downloadInfo.episode.setState(EpisodeState.downloaded);
          downloadInfo.episode.setDownloadProgress(1.0);
        } else {
          downloadInfo.episode.setState(EpisodeState.toDownload);
          downloadInfo.episode.setDownloadProgress(0.0);
        }
      }
      print('Download task ($id) is in status ($status) and process ($progress)');
    });
  }

  Future<void> performDownloadEpisode(Episode episode) async {
    var link = episode.link;
    var path = await getEpisodesDirectoryPath();
    var filename = episode.guid + ".mp3";

    print("Downloading $link as $filename in $path");

    String taskId = await FlutterDownloader.enqueue(
      url: link,
      savedDir: path,
      fileName: filename,
      showNotification: true,
    );

    return _downloadInfoList.add(new DownloadInfo(
      taskId: taskId,
      episode: episode,
      filePath: join(path, filename),
    ));
  }

  Future<void> onComplete(DownloadInfo downloadInfo) async {
    downloadInfo.episode.setLocalFilePath(downloadInfo.filePath);
  }

  DownloadInfo getDownloadInfoFromTaskId(String taskId) {
    if (this._downloadInfoList.length < 1) return null;
    return this._downloadInfoList.firstWhere((dli) => dli.taskId == taskId, orElse: () => null);
  }

  static Future<String> getEpisodesDirectoryPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final String episodesPath = join(directory.path, "episodes");
    // Creating directory
    await new Directory(episodesPath).create(recursive: true);
    return episodesPath;
  }

}

enum EpisodeState { toDownload, downloading, downloaded, playing, paused }

class Episode extends Model {
  String guid;
  String title;
  String link;
  EpisodeState _state;
  double _downloadProgress;
  String _localFilePath;


  Episode(Map data) {
    this.guid = data["guid"];
    this.title = data["title"];
    this.link = data["link"];

    this._state = EpisodeState.toDownload;
    this._downloadProgress = 0.0;
  }

  EpisodeState get state => this._state ?? EpisodeState.toDownload;

  void setState(EpisodeState state) {
    this._state = state;
    notifyListeners();
  }

  double get downloadProgress => this._downloadProgress ?? 0.0;

  void setDownloadProgress(double x) {
    this._downloadProgress = x;
    notifyListeners();
  }

  String get localFilePath => this._localFilePath;

  void setLocalFilePath(String filePath) {
    if (filePath == null) {
      return;
    }
    this._localFilePath = filePath;
    if (this._state == EpisodeState.downloading ||
      this._state == EpisodeState.toDownload) {
      this._state = EpisodeState.downloaded;
    }
    notifyListeners();
  }
}

