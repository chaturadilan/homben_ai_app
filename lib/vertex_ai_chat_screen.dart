import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';

class VertexAIChatScreen extends StatefulWidget {
  const VertexAIChatScreen({super.key});

  @override
  createState() => _VertexAIChatScreenState();
}

class _VertexAIChatScreenState extends State<VertexAIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  String _resultText = '';
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final model = FirebaseVertexAI.instance.generativeModel(
      model: 'gemini-1.5-flash',
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
    final prompt = [Content.text('Write a story about ${_controller.text}')];
    final response = await model.generateContent(prompt);

    setState(() {
      _resultText = response.text!;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vertex AI Chat'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _controller,
              maxLines: null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Type your message',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendMessage,
              child: const Text('Submit'),
            ),
            const SizedBox(height: 10),
            if (_isLoading) const CircularProgressIndicator(),
            const SizedBox(height: 10),
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Text(
                  _resultText,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
