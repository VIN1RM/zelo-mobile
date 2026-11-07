import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../contacts/domain/emergency_contact.dart';
import '../../../core/data/zelo_repository.dart';
import '../../../core/domain/app_failure.dart';
import '../domain/incident.dart';
import '../../../core/formatting/date_format.dart';

class ShareEmergency {
  ShareEmergency(this.repository);
  final ZeloRepository repository;
  static String message(
    Incident incident,
    String name,
    DateTime now, {
    bool test = false,
  }) {
    final location = incident.location;
    return '${test ? 'TESTE DO ZELO — NÃO É UMA EMERGÊNCIA\n' : ''}ZELO — ${incident.label}\n'
        '${name.isEmpty ? 'Usuário do ZELO' : name} solicita ajuda assistida.\n'
        'Ocorrência registrada em ${dateLabel(incident.occurredAt)}.\n'
        '${location == null ? 'Localização indisponível.' : '${location.describe(now)}\n${location.mapUrl}'}\n'
        'Este registro não confirma um acidente. Envio e entrega não são confirmados pelo ZELO.';
  }

  Future<void> share(
    Incident incident,
    String name,
    String channel,
    EmergencyContact? contact,
  ) async {
    final text = message(incident, name, DateTime.now().toUtc());
    var status = 'FAILED';
    try {
      if (channel == 'copy') {
        await Clipboard.setData(ClipboardData(text: text));
        status = 'COPIED';
      } else {
        final uri = channel == 'whatsapp' && contact?.phone != null
            ? Uri.https('wa.me', contact!.phone!.substring(1), {'text': text})
            : channel == 'email' && contact?.email != null
            ? Uri(
                scheme: 'mailto',
                path: contact!.email,
                query:
                    'subject=${Uri.encodeComponent('ZELO — pedido de ajuda')}&body=${Uri.encodeComponent(text)}',
              )
            : throw const AppFailure(
                'Selecione um contato com esse canal ou copie a mensagem.',
              );
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw const AppFailure(
            'Não foi possível abrir esse canal. Tente outro ou copie a mensagem.',
          );
        }
        status = 'OPENED';
      }
    } finally {
      await repository.store.db.insert('share_attempts', {
        'user_id': repository.uid,
        'incident_id': incident.id,
        'id': ZeloRepository.uuid.v4(),
        'payload': jsonEncode({
          'channel': channel,
          'status': status,
          'at': repository.now,
          'contactId': contact?.id,
        }),
      });
    }
  }
}
