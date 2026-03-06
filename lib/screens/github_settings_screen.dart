import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/github_service.dart';

class GitHubSettingsScreen extends StatefulWidget {
  const GitHubSettingsScreen({super.key});

  @override
  State<GitHubSettingsScreen> createState() => _GitHubSettingsScreenState();
}

class _GitHubSettingsScreenState extends State<GitHubSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _ownerController = TextEditingController();
  final _repoController = TextEditingController();
  final _branchController = TextEditingController(text: 'main');

  bool _isLoading = false;
  bool _isTesting = false;
  bool _obscureToken = true;
  bool _isConfigured = false;
  String? _statusMessage;
  bool _statusSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  Future<void> _loadExistingConfig() async {
    final config = await GitHubService.getConfig();
    setState(() {
      _tokenController.text = config['token'] ?? '';
      _ownerController.text = config['repoOwner'] ?? '';
      _repoController.text = config['repoName'] ?? '';
      _branchController.text = config['branch'] ?? 'main';
      _isConfigured = config['token'] != null && config['repoOwner'] != null;
    });
  }

  Future<void> _testConnection() async {
    if (_tokenController.text.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter a GitHub token first.';
        _statusSuccess = false;
      });
      return;
    }
    setState(() {
      _isTesting = true;
      _statusMessage = null;
    });
    final result = await GitHubService.validateToken(_tokenController.text.trim());
    setState(() {
      _isTesting = false;
      _statusMessage = result.message;
      _statusSuccess = result.success;
    });
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    // Validate token before saving
    final testResult =
        await GitHubService.validateToken(_tokenController.text.trim());
    if (!testResult.success) {
      setState(() {
        _isLoading = false;
        _statusMessage = testResult.message;
        _statusSuccess = false;
      });
      return;
    }

    await GitHubService.saveConfig(
      token: _tokenController.text.trim(),
      repoOwner: _ownerController.text.trim(),
      repoName: _repoController.text.trim(),
      branch: _branchController.text.trim().isEmpty
          ? 'main'
          : _branchController.text.trim(),
    );

    setState(() {
      _isLoading = false;
      _isConfigured = true;
      _statusMessage = 'Configuration saved! Papers can now be shared.';
      _statusSuccess = true;
    });
  }

  Future<void> _clearConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear GitHub Config'),
        content: const Text(
            'This will remove the saved GitHub token and settings. You will no longer be able to upload or access shared papers.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Clear')),
        ],
      ),
    );

    if (confirmed == true) {
      await GitHubService.clearConfig();
      _tokenController.clear();
      _ownerController.clear();
      _repoController.clear();
      _branchController.text = 'main';
      setState(() {
        _isConfigured = false;
        _statusMessage = 'Configuration cleared.';
        _statusSuccess = false;
      });
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _ownerController.dispose();
    _repoController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GitHub Cloud Settings'),
        actions: [
          if (_isConfigured)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear config',
              onPressed: _clearConfig,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: AppColors.info, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'How it works',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Papers you upload are stored in your GitHub repository\n'
                      '• Any user with the same config can browse and download them\n'
                      '• You need a GitHub Personal Access Token (classic) with repo scope',
                      style: TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Status banner
              if (_isConfigured && _statusMessage == null)
                _StatusBanner(
                  success: true,
                  message: 'GitHub cloud is configured and active.',
                ),
              if (_statusMessage != null)
                _StatusBanner(
                    success: _statusSuccess, message: _statusMessage!),
              if (_statusMessage != null) const SizedBox(height: 12),

              // Token field
              const Text('Personal Access Token',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _tokenController,
                obscureText: _obscureToken,
                decoration: InputDecoration(
                  hintText: 'ghp_xxxxxxxxxxxxxxxxxxxxxx',
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(_obscureToken
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => _obscureToken = !_obscureToken),
                      ),
                      IconButton(
                        icon: _isTesting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline),
                        tooltip: 'Test token',
                        onPressed: _isTesting ? null : _testConnection,
                      ),
                    ],
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Token is required' : null,
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _showTokenHelp(context),
                child: const Text(
                  'How to create a token? Tap here',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      decoration: TextDecoration.underline),
                ),
              ),
              const SizedBox(height: 20),

              // Repo owner field
              const Text('Repository Owner (GitHub username)',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _ownerController,
                decoration: const InputDecoration(
                  hintText: 'e.g. shahildemo',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Owner is required' : null,
              ),
              const SizedBox(height: 20),

              // Repo name field
              const Text('Repository Name',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _repoController,
                decoration: const InputDecoration(
                  hintText: 'e.g. question-paper-library',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty
                        ? 'Repository name is required'
                        : null,
              ),
              const SizedBox(height: 20),

              // Branch field
              const Text('Branch (default: main)',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _branchController,
                decoration: const InputDecoration(
                  hintText: 'main',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveConfig,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          _isConfigured ? 'Update Configuration' : 'Save Configuration',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTokenHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('How to create a GitHub Token',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text(
              '1. Go to github.com and log in\n'
              '2. Click your profile picture → Settings\n'
              '3. Scroll down → Developer settings\n'
              '4. Personal access tokens → Tokens (classic)\n'
              '5. Generate new token (classic)\n'
              '6. Give it a name (e.g. "Question Paper App")\n'
              '7. Check the "repo" scope\n'
              '8. Click Generate token\n'
              '9. Copy the token and paste it here',
              style: TextStyle(fontSize: 14, height: 1.8),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool success;
  final String message;

  const _StatusBanner({required this.success, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (success ? AppColors.success : AppColors.error)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (success ? AppColors.success : AppColors.error)
              .withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle : Icons.error_outline,
            color: success ? AppColors.success : AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: success ? AppColors.success : AppColors.error,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
