import 'package:flutter/material.dart';

/// Demo login screen for selecting a user role
///
/// In a real app, this would be your actual authentication flow
class LoginScreen extends StatefulWidget {
  final void Function(String userId, String userName, String role) onLogin;

  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _selectedRole = 'buyer';

  // Demo users - in a real app, these come from your auth system
  final Map<String, List<DemoUser>> _demoUsers = {
    'buyer': [
      const DemoUser('buyer-001', 'John Buyer', 'buyer'),
    ],
    'seller': [
      const DemoUser('seller-001', 'Sarah Seller', 'seller'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final users = _demoUsers[_selectedRole] ?? [];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Logo/Title
              Icon(
                Icons.chat_bubble_outline,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'RiviumChat Demo',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'E-commerce Chat Example',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Role selector
              Text(
                'Select your role:',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'buyer',
                    label: Text('Buyer'),
                    icon: Icon(Icons.shopping_bag_outlined),
                  ),
                  ButtonSegment(
                    value: 'seller',
                    label: Text('Seller'),
                    icon: Icon(Icons.store_outlined),
                  ),
                ],
                selected: {_selectedRole},
                onSelectionChanged: (selection) {
                  setState(() => _selectedRole = selection.first);
                },
              ),

              const SizedBox(height: 24),

              // User selection
              Text(
                'Select a demo user:',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _UserCard(
                      user: user,
                      onTap: () => widget.onLogin(
                        user.id,
                        user.name,
                        user.role,
                      ),
                    );
                  },
                ),
              ),

              const Spacer(),

              // Info text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This demo shows buyer-seller chat for orders. '
                        'Try opening the app in two windows with different users!',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final DemoUser user;
  final VoidCallback onTap;

  const _UserCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSeller = user.role == 'seller';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isSeller
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.primary,
                child: Icon(
                  isSeller ? Icons.store : Icons.person,
                  color: isSeller
                      ? theme.colorScheme.onTertiary
                      : theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      user.id,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DemoUser {
  final String id;
  final String name;
  final String role;

  const DemoUser(this.id, this.name, this.role);
}
