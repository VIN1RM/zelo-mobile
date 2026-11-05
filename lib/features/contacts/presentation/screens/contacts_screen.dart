import 'package:flutter/material.dart';

import '../../../../shared/widgets/feature_placeholder.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Contatos de emergência',
      icon: Icons.people_outline,
      description:
          'O cadastro e o gerenciamento de contatos serão implementados '
          'nesta etapa.',
    );
  }
}
