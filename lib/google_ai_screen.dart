import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_ai_flutter/includes/keys.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';

class GoogleAiScreen extends StatefulWidget {
  const GoogleAiScreen({super.key});

  @override
  State<GoogleAiScreen> createState() => _GoogleAiScreenState();
}

class _GoogleAiScreenState extends State<GoogleAiScreen> {
  File? _image;
  final picker = ImagePicker();
  String _resultText = '';
  bool _isLoading = false;
  String _selectedCuisine = 'Italian';

  final List<String> _cuisines = [
    'Italian',
    'Chinese',
    'French',
    'Japanese',
    'Indian',
    'Mexican',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google AI'),
      ),
      body: Center(
        child: _isLoading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing your recipe...'),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _image == null
                      ? const Text('No image selected.')
                      : Image.file(
                          _image!,
                          width: MediaQuery.of(context).size.width / 2,
                          height: MediaQuery.of(context).size.height / 4,
                        ),
                  DropdownButton<String>(
                    value: _selectedCuisine,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCuisine = newValue!;
                      });
                    },
                    items:
                        _cuisines.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                  ElevatedButton(
                    onPressed: _pickImage,
                    child: const Text('Pick Image'),
                  ),
                  ElevatedButton(
                    onPressed: _sendRequest,
                    child: const Text('Submit'),
                  ),
                  Expanded(
                    flex: 2,
                    child: _resultText.isNotEmpty
                        ? Markdown(
                            data: _resultText,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(fontSize: 16),
                            ),
                          )
                        : const Text('No result yet'),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    });
  }

  Future<void> _sendRequest() async {
    if (_image == null) return;

    setState(() {
      _isLoading = true;
    });

    final model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: Keys.googleAIApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.4,
        topK: 32,
        topP: 1,
        maxOutputTokens: 4096,
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
      ],
    );

    final prompt = ''' Recommend a recipe for me based on the provided image.
The recipe should only contain real, edible ingredients.
If the image or images attached don't contain any food items, respond to say that you cannot recommend a recipe with inedible ingredients.
Adhere to food safety and handling best practices like ensuring that poultry is fully cooked.
Give me a recipe that is inspired by the cuisine $_selectedCuisine. and no any other cuisines.
I have the following dietary restrictions: None
Optionally also include the following ingredients: olive oil, salt, pepper, milk
After providing the recipe, explain creatively why the recipe is good based on only the ingredients used in the recipe. Tell a short story of a travel experience that inspired the recipe.
Provide a summary of how many people the recipe will serve and the the nutritional information per serving.
List out any ingredients that are potential allergens. ''';

    final bytes = await _image!.readAsBytes();
    final imagesParts = [DataPart('image/jpeg', bytes)];

    final content = [
      Content.text(prompt),
      Content.multi([...imagesParts])
    ];

    final response = await model.generateContent(content);

    setState(() {
      _resultText = response.text.toString();
      _isLoading = false;
    });
  }
}
