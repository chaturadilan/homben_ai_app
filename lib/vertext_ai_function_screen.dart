import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:flutter/material.dart';

class VertexAIFunctionScreen extends StatefulWidget {
  const VertexAIFunctionScreen({super.key});

  @override
  createState() => _VertexAIFunctionScreenState();
}

class _VertexAIFunctionScreenState extends State<VertexAIFunctionScreen> {
  final TextEditingController _controller = TextEditingController(
      text: 'How much is 50 US dollars worth in Sri Lankan Rupees?');
  String _resultText = '';
  bool _isLoading = false;

  final exchangeRateTool = FunctionDeclaration(
      'findExchangeRate',
      'Returns the exchange rate between currencies on given date.',
      Schema(SchemaType.object, properties: {
        'currencyDate': Schema(SchemaType.string,
            description: 'A date in YYYY-MM-DD format or '
                'the exact value "latest" if a time period is not specified.'),
        'currencyFrom': Schema(SchemaType.string,
            description: 'The currency code of the currency to convert from, '
                'such as "USD".'),
        'currencyTo': Schema(SchemaType.string,
            description: 'The currency code of the currency to convert to, '
                'such as "USD".')
      }, requiredProperties: [
        'currencyDate',
        'currencyFrom'
      ]));

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final model = FirebaseVertexAI.instance.generativeModel(
        model: 'gemini-1.5-flash-001',
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
        tools: [
          Tool(functionDeclarations: [exchangeRateTool])
        ]);
    final chat = model.startChat();
    var prompt = _controller.text;

    // Send the message to the generative model.
    var response = await chat.sendMessage(Content.text(prompt));

    final functionCalls = response.functionCalls.toList();
    // When the model response with a function call, invoke the function.
    if (functionCalls.isNotEmpty) {
      final functionCall = functionCalls.first;
      final result = switch (functionCall.name) {
        // Forward arguments to the hypothetical API.
        'findExchangeRate' => await findExchangeRate(functionCall.args),
        // Throw an exception if the model attempted to call a function that was
        // not declared.
        _ => throw UnimplementedError(
            'Function not implemented: ${functionCall.name}')
      };
      // Send the response to the model so that it can use the result to generate
      // text for the user.
      response = await chat
          .sendMessage(Content.functionResponse(functionCall.name, result));
    }

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
            Expanded(
              flex: 1,
              child: TextField(
                controller: _controller,
                maxLines: null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Ask about Currency',
                ),
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

  Future<Map<String, Object?>> findExchangeRate(
    Map<String, Object?> arguments,
  ) async =>
      // This hypothetical API returns a JSON such as:
      // {"base":"USD","date":"2024-04-17","rates":{"LKR": 300}}
      {
        'date': arguments['currencyDate'],
        'base': arguments['currencyFrom'],
        'rates': <String, Object?>{arguments['currencyTo'] as String: 300}
      };
}
