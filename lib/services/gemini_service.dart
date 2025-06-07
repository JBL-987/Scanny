import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
  static const String _apiKey =
      'your-api_key'; 
  static const String _childFriendlyPrompt = '''
You are a very good assistant at explaining things to young children who are just starting to learn.

Your task is to describe an image in a way that is:

Easy for young children (ages 4–8) to understand

Uses simple and cheerful language

Educational but not boring

Includes fun emojis

Maximum of 3–4 short sentences

Focuses on the main object in the image

Example of a good answer:
"🐱 This is a cute kitty! Cats have pointy ears and long tails. They love to play and drink milk. Cats are pets that love their family!"

Now, describe this image in a fun way for a little kid:


''';

  static Future<String> describeImage(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        return "🤔 Oops, I can’t really see what’s in this picture. Can you try taking another photo?";
      }
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": _childFriendlyPrompt},
              {
                "inline_data": {"mime_type": "image/jpeg", "data": base64Image},
              },
            ],
          },
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 200,
        },
        "safetySettings": [
          {
            "category": "HARM_CATEGORY_HARASSMENT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE",
          },
          {
            "category": "HARM_CATEGORY_HATE_SPEECH",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE",
          },
          {
            "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE",
          },
          {
            "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
            "threshold": "BLOCK_MEDIUM_AND_ABOVE",
          },
        ],
      };
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['candidates'] != null &&
            responseData['candidates'].isNotEmpty &&
            responseData['candidates'][0]['content'] != null &&
            responseData['candidates'][0]['content']['parts'] != null &&
            responseData['candidates'][0]['content']['parts'].isNotEmpty) {
          String description =
              responseData['candidates'][0]['content']['parts'][0]['text'];
          description = _cleanAndValidateResponse(description);

          return description;
        }
      }
      return _getFallbackDescription();
    } catch (e) {
      print('Error calling Gemini API: $e');
      return _getFallbackDescription();
    }
  }

  static String _cleanAndValidateResponse(String response) {
    response = response.trim();
    if (response.length > 300) {
      response = response.substring(0, 300) + "...";
    }

    if (!response.contains('🌟') &&
        !response.contains('🎉') &&
        !response.contains('😊') &&
        !response.contains('🔍') &&
        !response.contains('🎨') &&
        !response.contains('🌈')) {
      response = "🌟 " + response;
    }

    return response;
  }

  static String _getFallbackDescription() {
    final fallbacks = [
      "🌟 Wow, this is such an interesting picture! I can see lots of cool things here. Let’s try showing me another picture!",
      "🎉 What a great photo! There are so many things we can learn from it. Let’s take another one!",
      "🔍 Hmm, there’s something interesting in this picture! But I need a clearer photo to explain it better.",
      "🎨 What a beautiful photo! Every picture has a fun story we can learn together.",
      "🌈 Such a lovely photo! The world is full of amazing things we can explore together!",
    ];

    return fallbacks[DateTime.now().millisecond % fallbacks.length];
  }

  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode ==
          400; 
    } catch (e) {
      return false;
    }
  }
}
