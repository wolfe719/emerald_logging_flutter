import 'dart:collection';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'ansi_parser.dart';

ListQueue<OutputEvent> _outputEventBuffer = ListQueue();

class FullLogs {
  StringBuffer fullLogs = StringBuffer('Start: ');
}

class OutputEvent {
  final Level level;
  final List<String> lines;

  OutputEvent(this.level, this.lines);
}

class RotatingLogConsole extends StatefulWidget {
  final bool dark;
  final bool showCloseButton;

  late final LogConsole logConsole;

  RotatingLogConsole({this.dark = false, this.showCloseButton = false, Key? key}) : super(key: key) {
    logConsole = LogConsole(dark: dark, showCloseButton: showCloseButton);
  }

  static Future<void> open(BuildContext context, {bool? dark}) async {
    var logConsole = RotatingLogConsole(
      showCloseButton: true,
      dark: dark ?? Theme.of(context).brightness == Brightness.dark,
    );
    PageRoute route;
    if (Platform.isIOS) {
      route = CupertinoPageRoute(builder: (_) => logConsole);
    } else {
      route = MaterialPageRoute(builder: (_) => logConsole);
    }

    await Navigator.push(context, route);
  }

  static void add(OutputEvent outputEvent, {int? bufferSize = 1000}) {
    while (_outputEventBuffer.length >= (bufferSize ?? 1)) {
      _outputEventBuffer.removeFirst();
    }
    _outputEventBuffer.add(outputEvent);
  }

  @override
  State<RotatingLogConsole> createState() => _RotatingLogConsoleState();
}

class _RotatingLogConsoleState extends State<RotatingLogConsole> {
  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
        builder: (context, orientation) {
          // Rotate the widget based on the current orientation
          return RotatedBox(
              quarterTurns: orientation == Orientation.landscape ? 1 : 0,
              child: widget.logConsole,
          );
        }
    );
  }
}

class LogConsole extends StatefulWidget {
  final bool dark;
  final bool showCloseButton;

  LogConsole({this.dark = false, this.showCloseButton = false});

  static Future<void> open(BuildContext context, {bool? dark}) async {
    var logConsole = LogConsole(
      showCloseButton: true,
      dark: dark ?? Theme.of(context).brightness == Brightness.dark,
    );
    PageRoute route;
    if (Platform.isIOS) {
      route = CupertinoPageRoute(builder: (_) => logConsole);
    } else {
      route = MaterialPageRoute(builder: (_) => logConsole);
    }

    await Navigator.push(context, route);
  }

  static void add(OutputEvent outputEvent, {int? bufferSize = 1000}) {
    while (_outputEventBuffer.length >= (bufferSize ?? 1)) {
      _outputEventBuffer.removeFirst();
    }
    _outputEventBuffer.add(outputEvent);
  }

  @override
  _LogConsoleState createState() => _LogConsoleState();
}

class RenderedEvent {
  final int id;
  final Level level;
  final TextSpan span;
  final String lowerCaseText;

  RenderedEvent(this.id, this.level, this.span, this.lowerCaseText);
}

class _LogConsoleState extends State<LogConsole> {
  ListQueue<RenderedEvent> _renderedBuffer = ListQueue();
  List<RenderedEvent> _filteredBuffer = [];

  var logs = FullLogs().fullLogs;

  var _scrollController = ScrollController();
  var _filterController = TextEditingController();

  Level? _filterLevel = Level.CONFIG;
  double _logFontSize = 14;

  var _currentId = 0;
  bool _scrollListenerEnabled = true;
  bool _followBottom = true;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (!_scrollListenerEnabled) return;
      var scrolledToBottom = _scrollController.offset >=
          _scrollController.position.maxScrollExtent;
      setState(() {
        _followBottom = scrolledToBottom;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _renderedBuffer.clear();
    for (var event in _outputEventBuffer) {
      _renderedBuffer.add(_renderEvent(event));
    }
    _refreshFilter();
  }

  void _refreshFilter() {
    var newFilteredBuffer = _renderedBuffer.where((it) {
      var logLevelMatches = it.level.value >= _filterLevel!.value;
      if (!logLevelMatches) {
        return false;
      } else if (_filterController.text.isNotEmpty) {
        var filterText = _filterController.text.toLowerCase();
        return it.lowerCaseText.contains(filterText);
      } else {
        return true;
      }
    }).toList();
    setState(() {
      _filteredBuffer = newFilteredBuffer;
    });

    if (_followBottom) {
      Future.delayed(Duration.zero, _scrollToBottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: widget.dark
          ? ThemeData(
              brightness: Brightness.dark,
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    secondary: Colors.blueGrey,
                  ),
            )
          : ThemeData(
              brightness: Brightness.light,
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    secondary: Colors.lightBlueAccent,
                  ),
            ),
      home: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildTopBar(context),
              SizedBox(height: 8),
              Expanded(
                child: _buildLogContent(),
              ),
              SizedBox(height: 8),
              _buildBottomBar(),
            ],
          ),
        ),
        floatingActionButton: AnimatedOpacity(
          opacity: _followBottom ? 0 : 1,
          duration: Duration(milliseconds: 150),
          child: Padding(
            padding: EdgeInsets.only(bottom: 60),
            child: FloatingActionButton(
              mini: true,
              clipBehavior: Clip.antiAlias,
              child: Icon(
                Icons.arrow_downward,
                color: widget.dark ? Colors.white : Colors.lightBlue[900],
              ),
              onPressed: _scrollToBottom,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogContent() {
    logs.clear();
    return Container(
      color: widget.dark ? Colors.black : Colors.grey[150],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1600,
          child: ListView.builder(
            shrinkWrap: true,
            controller: _scrollController,
            itemBuilder: (context, index) {
              var logEntry = _filteredBuffer[index];
              logs.write(logEntry.lowerCaseText + "\n");
              return Text.rich(
                logEntry.span,
                key: Key(logEntry.id.toString()),
                style: TextStyle(
                    fontSize: _logFontSize,
                    color: logEntry.level.toColor(widget.dark)),
              );
            },
            itemCount: _filteredBuffer.length,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return LogBar(
      dark: widget.dark,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Text(
            "Log Console",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          IconButton(
            icon: Icon(
              Icons.content_copy_rounded,
              color: Colors.greenAccent,
            ),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text: logs.toString(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              setState(() {
                _logFontSize++;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.remove),
            onPressed: () {
              setState(() {
                if (_logFontSize >= 2) {
                  _logFontSize--;
                }
              });
            },
          ),
          if (widget.showCloseButton)
            IconButton(
              icon: Icon(
                Icons.cancel,
                color: Colors.red[200],
                size: 30,
              ),
              onPressed: () {
                Navigator.pop(context);
                logs.clear();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return LogBar(
      dark: widget.dark,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Expanded(
            child: TextField(
              style: TextStyle(fontSize: 20),
              controller: _filterController,
              onChanged: (s) => _refreshFilter(),
              decoration: InputDecoration(
                labelText: "Filter log output",
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(width: 20),
          DropdownButton(
            value: _filterLevel,
            items: [
              DropdownMenuItem(
                child: Text("FINEST"),
                value: Level.FINEST,
              ),
              DropdownMenuItem(
                child: Text("FINER"),
                value: Level.FINER,
              ),
              DropdownMenuItem(
                child: Text("FINE"),
                value: Level.FINE,
              ),
              DropdownMenuItem(
                child: Text("CONFIG"),
                value: Level.CONFIG,
              ),
              DropdownMenuItem(
                child: Text("INFO"),
                value: Level.INFO,
              ),
              DropdownMenuItem(
                child: Text("WARNING"),
                value: Level.WARNING,
              ),
              DropdownMenuItem(
                child: Text("SEVERE"),
                value: Level.SEVERE,
              ),
              DropdownMenuItem(
                child: Text("SHOUT"),
                value: Level.SHOUT,
              ),
            ],
            onChanged: (dynamic value) {
              _filterLevel = value;
              _refreshFilter();
            },
          )
        ],
      ),
    );
  }

  void _scrollToBottom() async {
    _scrollListenerEnabled = false;

    setState(() {
      _followBottom = true;
    });

    var scrollPosition = _scrollController.position;
    await _scrollController.animateTo(
      scrollPosition.maxScrollExtent,
      duration: new Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );

    _scrollListenerEnabled = true;
  }

  RenderedEvent _renderEvent(OutputEvent event) {
    var parser = AnsiParser(widget.dark);
    var text = event.lines.join('\n');
    parser.parse(text);
    return RenderedEvent(
      _currentId++,
      event.level,
      TextSpan(children: parser.spans),
      text.toLowerCase(),
    );
  }
}

class LogBar extends StatelessWidget {
  final bool? dark;
  final Widget? child;

  LogBar({this.dark, this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            if (!dark!)
              BoxShadow(
                color: Colors.grey[400]!,
                blurRadius: 3,
              ),
          ],
        ),
        child: Material(
          color: dark! ? Colors.blueGrey[900] : Colors.white,
          child: Padding(
            padding: EdgeInsets.fromLTRB(15, 8, 15, 8),
            child: child,
          ),
        ),
      ),
    );
  }
}

extension LevelExtension on Level {
  Color toColor(bool dark) {
    if (this == Level.CONFIG) {
      return dark ? Colors.white38 : Colors.black38;
    } else if (this == Level.INFO) {
      return dark ? Colors.white : Colors.black;
    } else if (this == Level.WARNING) {
      return Colors.orange;
    } else if (this == Level.SEVERE) {
      return Colors.red;
    } else if (this == Level.SHOUT) {
      return Colors.pinkAccent;
    } else if ([Level.FINEST, Level.FINER, Level.FINE].contains(this)) {
      return dark ? Colors.white60 : Colors.blueGrey;
    } else {
      // ALL, NONE
      return dark ? Colors.white : Colors.black;
    }
  }
}
