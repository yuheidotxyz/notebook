import 'dart:io';

final String server_address = 'localhost';
final int server_port = 8080;
final Directory document_root = Directory('www').absolute;
final List<String> exts = ['.enex'];
final File enex_parser = File('enex_parser').absolute;
