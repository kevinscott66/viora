import 'dart:io';
import 'package:flutter/material.dart';

ImageProvider artworkProvider(String path) => FileImage(File(path));
