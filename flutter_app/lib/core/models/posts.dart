import 'package:flutter/material.dart';

import 'package:rule_post/core/models/uploaded_file.dart';


class Post {
  final String id;
  final int enquiryNumber;
  final int roundNumber;
  final int responseNumber;
  final String titleText;
  final String? enquiryText;
  final bool isOpen;
  final List<UploadedFile> attachments;
  final String? author;

  Post({
    required this.id,
    required this.enquiryNumber,
    required this.roundNumber,
    required this.responseNumber,
    required this.titleText,
    required this.isOpen,
    this.enquiryText,
    this.attachments = const [],
    this.author,
  });

  Map<String, dynamic> toMap() {
    return {
      'enquiryNumber': enquiryNumber,
      'roundNumber': roundNumber,
      'responseNumber': responseNumber,
      'titleText': titleText,
      'isOpen': isOpen,
      'enquiryText': enquiryText,
      'attachments': attachments.map((file) => file.toMap()).toList(),
      'author': author,
    };
  }

  factory Post.fromMap(String id, Map<String, dynamic> map) {
    return Post(
      id: id,
      enquiryNumber: map['enquiryNumber'] ?? 0,
      roundNumber: map['roundNumber'] ?? 0,
      responseNumber: map['responseNumber'] ?? 0,
      titleText: map['titleText'] ?? '',
      isOpen: map['isOpen'] ?? true,
      enquiryText: map['enquiryText'],
      attachments: map['attachments'] != null
          ? (map['attachments'] as List)
              .map((item) => UploadedFile.fromMap(Map<String, dynamic>.from(item)))
              .toList()
          : [],
      author: map['author'],
    );
  }
}

class PostMeta extends Post {
  final DateTime createdAt;
  final String postType;
  final String userId;
  final String teamId;
  final bool anonymous;
  final Map<String, dynamic>? teamColourMap;
  final Color? postColour;

  PostMeta({
    required super.id,
    required super.enquiryNumber,
    required super.roundNumber,
    required super.responseNumber,
    required super.titleText,
    required super.isOpen,
    super.enquiryText,
    super.attachments,
    super.author,
    required this.createdAt,
    required this.postType,
    required this.userId,
    required this.teamId,
    required this.anonymous,
    this.teamColourMap,
    this.postColour,
  });

  @override
  Map<String, dynamic> toMap() {
    final base = super.toMap();
    return {
      ...base,
      'createdAt': createdAt,
      'postType': postType,
      'userId': userId,
      'teamId': teamId,
      'anonymous': anonymous,
      'teamColourMap': teamColourMap,
      'postColour': postColour,
    };
  }

  factory PostMeta.fromMap(String id, Map<String, dynamic> map) {
    return PostMeta(
      id: id,
      enquiryNumber: map['enquiryNumber'] ?? 0,
      roundNumber: map['roundNumber'] ?? 0,
      responseNumber: map['responseNumber'] ?? 0,
      titleText: map['titleText'] ?? '',
      isOpen: map['isOpen'] ?? true,
      enquiryText: map['enquiryText'],
      attachments: map['attachments'] != null
          ? (map['attachments'] as List)
              .map((item) => UploadedFile.fromMap(Map<String, dynamic>.from(item)))
              .toList()
          : [],
      author: map['author'],
      createdAt: map['createdAt'] ?? DateTime(2000, 1, 1, 0, 0),
      postType: map['postType'] ?? '',
      userId: map['userId'] ?? '',
      teamId: map['teamId'] ?? '',
      anonymous: map['anonymous'] ?? true,
      teamColourMap: map['teamColourMap'],
      postColour: map['postColour'],
    );
  }
}


class PostInput {
  final String title;
  final String? text;
  final List<UploadedFile> attachments;

  PostInput({
    required this.title,
    this.text,
    this.attachments = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'text': text,
      'attachments': attachments.map((file) => file.toMap()).toList(),
    };
  }

  factory PostInput.fromMap(String id, Map<String, dynamic> map) {
    return PostInput(
      title: map['title'] ?? '',
      text: map['text'],
      attachments: map['attachments'] != null
          ? (map['attachments'] as List)
              .map((item) => UploadedFile.fromMap(Map<String, dynamic>.from(item)))
              .toList()
          : [],
    );
  }
}