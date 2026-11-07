export '../../core/formatting/date_format.dart';

/// Labels at the presentation boundary. Persisted values remain unchanged.
String outcomeLabel(String value) => switch (value) {
  'PENDING' => 'Aguardando resposta',
  'CANCELLED' => 'Alerta cancelado',
  'HELP_REQUESTED' => 'Ajuda solicitada',
  'TIMED_OUT' => 'Sem resposta no prazo',
  'SAFE' => 'Estou bem',
  'NEEDS_HELP' => 'Preciso de ajuda',
  'UNKNOWN' => 'Condição não informada',
  'PREPARING' => 'Preparando proteção',
  'ACTIVE' => 'Proteção ativa',
  'LIMITED' => 'Monitoramento limitado',
  'COMPLETED' => 'Trajeto encerrado',
  'INTERRUPTED' => 'Monitoramento interrompido',
  _ => 'Estado não informado',
};

String entityLabel(Object? value) => switch (value) {
  'contacts' => 'Contato de emergência',
  'profiles' => 'Dados da conta',
  'sessions' => 'Trajeto',
  'incidents' => 'Ocorrência',
  'updates' => 'Atualização da ocorrência',
  _ => 'Registro',
};

String syncStateLabel(Object? value) => switch (value) {
  'PENDING' => 'Aguardando sincronização',
  'DENIED' => 'Acesso não autorizado',
  'CONFLICT' => 'Alterações para revisar',
  _ => 'Verificando sincronização',
};

String syncErrorLabel(Object? value) => switch (value) {
  'permission-denied' || 'unauthenticated' =>
    'O acesso não foi autorizado. Confira sua conta e tente novamente.',
  'unavailable' || 'deadline-exceeded' =>
    'O serviço não respondeu. Tentaremos novamente quando houver conexão.',
  'failed-precondition' =>
    'O serviço precisa de uma configuração para concluir esta atualização.',
  'CONFLICT' ||
  'CONTACT_REVISION_CONFLICT' ||
  'CONTACT_GENERATION_CONFLICT' ||
  'CONTACT_MISSING' =>
    'Há outra versão deste registro. Revise antes de substituir seus dados.',
  'REMOTE_DELETED' => 'Este registro foi excluído em outro aparelho.',
  null => 'Salvo no aparelho. Aguardando a próxima tentativa automática.',
  _ =>
    'Não foi possível concluir a última tentativa. Seus dados continuam no aparelho.',
};

String channelLabel(Object? value) => switch (value) {
  'whatsapp' => 'WhatsApp',
  'email' => 'E-mail',
  'copy' => 'Cópia da mensagem',
  _ => 'Compartilhamento',
};
String shareStateLabel(Object? value) => switch (value) {
  'OPENED' => 'Aplicativo aberto · envio não confirmado',
  'COPIED' => 'Mensagem copiada',
  'FAILED' => 'Não foi possível abrir o canal',
  _ => 'Envio não confirmado',
};
String diagnosticLabel(Object? value) => switch (value) {
  'NATIVE_UNCONFIRMED' => 'Não foi possível confirmar o monitoramento',
  'MONITORING_STARTED' => 'Monitoramento iniciado',
  'MONITORING_STOPPED' => 'Monitoramento encerrado',
  'SYNC_UNAVAILABLE' => 'Sincronização indisponível',
  'NATIVE_RECOVERED' => 'Comunicação com o monitoramento restabelecida',
  _ => 'Verificação do aplicativo',
};
