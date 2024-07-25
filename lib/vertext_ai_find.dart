import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_ai_flutter/configs.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class VertexAIFindCowScreen extends StatefulWidget {
  const VertexAIFindCowScreen({super.key});

  @override
  State<VertexAIFindCowScreen> createState() => _VertexAIFindCowScreenState();
}

class _VertexAIFindCowScreenState extends State<VertexAIFindCowScreen> {
  File? _image;
  final picker = ImagePicker();
  String _resultText = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find My Cow'),
      ),
      body: Center(
        child: _isLoading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing your result...'),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _image == null
                      ? const Text(
                          'No image selected.',
                        )
                      : Image.file(
                          _image!,
                          width: MediaQuery.of(context).size.width / 2,
                          height: MediaQuery.of(context).size.height / 4,
                        ),
                  ElevatedButton(
                    onPressed: _pickImage,
                    child: const Text('Pick Your Cow'),
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
                              p: const TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.bold),
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

    try {
      final bytes = await _image!.readAsBytes();
      final base64Image = base64Encode(bytes);

      if (!mounted) {
        return;
      }

      final serviceAccountJson = await DefaultAssetBundle.of(context)
          .loadString('assets/service_account.json');

      final serviceAccount = json.decode(serviceAccountJson);

      final accountCredentials =
          ServiceAccountCredentials.fromJson(serviceAccount);
      final scopes = ['https://www.googleapis.com/auth/cloud-platform'];

      final client = http.Client();
      final accessCredentials = await obtainAccessCredentialsViaServiceAccount(
        accountCredentials,
        scopes,
        client,
      );

      var accessToken = accessCredentials.accessToken.data;

      final response = await http.post(
        Uri.parse('https://us-central1-aiplatform.googleapis.com/v1/'
            'projects/${Configs.projectId}'
            '/locations/us-central1/'
            'endpoints/${Configs.endpointID}:predict'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'instances': [
            {
              'content': base64Image,
            },
          ],
          'parameters': {
            'confidenceThreshold': 0.5,
            'maxPredictions': 5,
          },
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        debugPrint(responseData.toString());
        final predictions = responseData['predictions'] as List;
        final displayNames = predictions[0]['displayNames'] as List;

        setState(() {
          if (displayNames.contains('MyCattle')) {
            _resultText = 'This cow is your cow!';
          } else if (displayNames.contains('OtherCattle')) {
            _resultText = 'This is NOT your cow!';
          } else {
            _resultText = 'Cow identification result is unclear.';
          }
        });
      } else {
        setState(() {
          _resultText = 'Error: ${response.reasonPhrase}';
        });
      }
    } catch (e) {
      setState(() {
        _resultText = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
