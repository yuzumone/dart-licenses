import 'dart:io';
import 'package:args/args.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

void main(List<String> arguments) async {
  final parser = ArgParser();
  parser.addOption('path',
      abbr: 'p',
      defaultsTo: './pubspec.lock',
      help: 'Set the path pubspec.lock');
  parser.addFlag('help', abbr: 'h', help: 'Display this message',
      callback: (help) {
    if (help) {
      print(parser.usage);
      exit(64);
    }
  });
  final result = parser.parse(arguments);
  final path = result['path'];

  final lock = await _getYaml(path);
  final outputs = [];
  for (var p in lock['packages'].values) {
    var name = p['description']['name'];
    var url = p['description']['url'];
    var doc = await _getDocument(name, url);

    if (doc == null) {
      outputs.add('$name, unknown');
      continue;
    }
    for (var e
        in doc.getElementsByTagName('aside').first.querySelectorAll('h3')) {
      if (e.text == 'License') {
        var license = e.nextElementSibling?.text.replaceAll(' (LICENSE)', '');
        outputs.add('$name, $license');
      }
    }
  }

  print(outputs.join('\n'));
  exit(0);
}

Future<YamlMap> _getYaml(path) async {
  var file = File(path);
  return loadYaml(await file.readAsString());
}

Future<Document?> _getDocument(String name, String url) async {
  var uri = Uri.parse('$url/packages/$name');
  var res = await http.get(uri);
  if (res.statusCode >= 300) {
    return null;
  }
  return parse(res.body);
}
