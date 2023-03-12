import 'dart:io';
import 'dart:convert' show json, HtmlEscape, base64Decode;
import 'settings.dart' as settings;
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' show Request, Response;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart' show Router;
import 'package:shelf_static/shelf_static.dart' show createFileHandler;

final Router app = Router();
const HtmlEscape htmlEscape = HtmlEscape();

class Entry {
  final String href;
  final String title;
  final DateTime lastmod;
  Entry(this.href, this.title, this.lastmod);
}

String encodePath(String path) {
  return '/' + Uri.file(path.substring(1), windows: false).path;
}

Future<DateTime> register_files(Directory dir) async {
  final String href_dir = path.normalize(dir.absolute.path).replaceFirst(
          path.normalize(settings.document_root.absolute.path), '') +
      '/';
  List<Entry> dirs = [], files = []; // このディレクトリにあるもの

  String get_html(String title, String body) {
    String res = '<!DOCTYPE html>';
    res += '<title>${htmlEscape.convert(title)}</title>';
    res += body;
    return res;
  }

  await Future.forEach(dir.listSync(), (FileSystemEntity entity) async {
    final String basename = path.basename(entity.path);
    if (entity is Directory) {
      dirs.add(new Entry(
          basename + '/', basename + '/', await register_files(entity)));
    } else if (entity is File) {
      final String ext = path.extension(entity.path).toLowerCase();
      if (settings.exts.contains(ext)) {
        if (ext == '.enex') {
          app.get(encodePath(href_dir + basename), (Request request) {
            return Response.found('./');
          });
          app.get(encodePath(href_dir + basename + '/'), (Request request) {
            return Response.found('../');
          });
          var enex = json.decode((await Process.run(
                  settings.enex_parser.path, [entity.absolute.path]))
              .stdout);
          int noteID = 1;
          enex['Notes'].forEach((var note) {
            String body = '';

            body += '<a href="../">戻る</a>';

            body +=
                '<p>作成日:${htmlEscape.convert(note['Created'] ?? '')} 更新日:${htmlEscape.convert(note['Updated'] ?? '')}</p>';

            body +=
                '<p>タグ: ${htmlEscape.convert((note['Tags'] ?? []).join(' '))}</p>';

            body += '<p>タスク:</p><ul>';
            (note['Tasks'] ?? []).forEach((var task) {
              body += '<li>';
              var title = htmlEscape.convert(task['Title'] ?? 'task');
              if ((task['TaskStatus'] ?? '') == 'open') {
                body += title;
              } else {
                body += '<del>${title}</del>';
              }
            });
            body += '</ul>';

            int resourceID = 1;
            (note['Resources'] ?? []).forEach((var resource) {
              String href =
                  encodePath(href_dir + basename + '/${noteID}/${resourceID}');
              String mime = resource['Mime'] ?? 'application/octet-stream';

              // ノート内のen-mediaタグを置き換え
              if (note['Body'] is String) {
                String filename = (resource['ResourceAttributes'] is Map &&
                        resource['ResourceAttributes']['FileName'] is String)
                    ? resource['ResourceAttributes']['FileName']
                    : 'filename';

                note['Body'] = note['Body'].replaceAll(
                    RegExp('<en-media [^>]+${resource['Hash']}[^>]+/>'),
                    '<a href="${htmlEscape.convert(href)}">${htmlEscape.convert(filename)}</a><br>' +
                        ((mime == 'application/pdf')
                            ? '<iframe src="${htmlEscape.convert(href)}"></iframe><br>'
                            : (mime.startsWith('image/') &&
                                    int.tryParse(resource['Width']) is int &&
                                    int.tryParse(resource['Height']) is int)
                                ? '<img src="${htmlEscape.convert(href)}" width="${int.parse(resource['Width'])}px" height="${int.parse(resource['Height'])}px"/><br>'
                                : ''));
              }

              app.get(href, (Request request) {
                if (resource['Data'] is String) {
                  return Response.ok(
                      base64Decode(
                              resource['Data'].replaceAll(RegExp(r'\s'), ''))
                          .cast<int>(),
                      headers: {'Content-Type': mime});
                }
                return Response.notFound('Not Found');
              });
              resourceID++;
            });
            body += '<hr>';
            body += note['Body'] ?? '';
            String href = encodePath(href_dir + basename + '/${noteID}');
            files.add(new Entry(
                href,
                note['Title'] ?? 'title',
                DateTime.tryParse(note['Updated'] ?? '') ??
                    DateTime.fromMillisecondsSinceEpoch(0)));
            app.get(href, (Request request) {
              return Response.ok(get_html(note['Title'] ?? 'title', body),
                  headers: {'Content-Type': 'text/html'});
            });

            noteID++;
          });
          return;
        }
      }
      String href = encodePath(href_dir + basename);
      files.add(new Entry(href, basename, await entity.lastModified()));
      app.get(href, createFileHandler(entity.path, url: href.substring(1)));
    }
  });

  // このディレクトリに対応するページを設定する
  String body = '';
  if (href_dir != '/') {
    body += '<a href="../">戻る</a>';
  }
  body += '<h1>${htmlEscape.convert(href_dir)}</h1>';
  body += '<table><tr><th></th><th>更新日時</th></tr>';
  (dirs + files).forEach((Entry entry) {
    body += '<tr>';
    body +=
        '<td><a href="${htmlEscape.convert(entry.href)}">${htmlEscape.convert(entry.title)}</a></td>';
    body += '<td>${htmlEscape.convert(entry.lastmod.toString())}</td>';
    body += '</tr>';
  });
  body += '</table>';
  app.get(encodePath(href_dir), (Request request) {
    return Response.ok(get_html(href_dir, body),
        headers: {'Content-Type': 'text/html'});
  });

  // このディレクトリの最終更新日時を返す
  DateTime res_lastmod = DateTime.fromMillisecondsSinceEpoch(0);
  (dirs + files).forEach((Entry entry) {
    if (entry.lastmod.isAfter(res_lastmod)) {
      res_lastmod = entry.lastmod;
    }
  });
  return res_lastmod;
}

void main() async {
  await register_files(settings.document_root);
  await io.serve(app, settings.server_address, settings.server_port);
}
