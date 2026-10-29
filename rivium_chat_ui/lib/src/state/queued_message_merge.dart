import 'package:rivium_chat/rivium_chat.dart';

/// Keeps a message the offline outbox queued on screen exactly once:
/// "Waiting for network…", then the stored message, or failed with Retry.

/// Label of a message the offline outbox keeps until the network is back.
const waitingForNetworkLabel = 'Waiting for network…';

/// A pending message the SDK queued while offline (id `local_<clientMessageId>`).
bool isQueuedOffline(Message message) =>
    message.isPending && message.id.startsWith(PendingMessage.localIdPrefix);

/// The answer of `sendMessage` for the optimistic copy [placeholderId]: a
/// queued (pending) message replaces it; a stored one replaces it, unless the
/// live event already showed it (then the copy goes).
void applySendResult(List<Message> messages, String placeholderId, Message sent) {
  final cmid = sent.clientMessageId;
  if (!sent.isPending &&
      cmid != null &&
      messages.any((m) => m.id != placeholderId && !m.isPending && m.clientMessageId == cmid)) {
    messages.removeWhere((m) => m.id == placeholderId);
    final i = messages.indexWhere((m) => m.clientMessageId == cmid);
    if (i >= 0) messages[i] = sent;
    return;
  }
  final i = messages.indexWhere((m) => m.id == placeholderId);
  if (i >= 0) {
    messages[i] = sent;
    return;
  }
  final shown = messages.indexWhere((m) => m.id == sent.id);
  if (shown >= 0) {
    messages[shown] = sent;
  } else if (sent.isPending) {
    messages.insert(0, sent);
  }
}

/// A live message event: updates the copy already shown (same id, the message
/// queued offline with the same clientMessageId, or the optimistic copy with
/// the same sender and text), else adds it on top. Never twice.
void mergeLiveMessage(List<Message> messages, Message message) {
  final existing = messages.indexWhere((m) => m.id == message.id);
  final cmid = message.clientMessageId;
  final queued = cmid == null
      ? -1
      : messages.indexWhere((m) => m.id != message.id && m.clientMessageId == cmid);
  if (existing >= 0) {
    messages[existing] = message;
    if (queued >= 0) messages.removeAt(queued);
  } else if (queued >= 0) {
    messages[queued] = message;
  } else {
    // The real version of a pending optimistic message (same sender + text)
    final pending = messages.indexWhere((m) =>
        m.isPending &&
        !m.id.startsWith(PendingMessage.localIdPrefix) &&
        m.senderUserId == message.senderUserId &&
        m.content == message.content);
    if (pending >= 0) {
      messages[pending] = message;
    } else {
      messages.insert(0, message); // newest first
    }
  }
}

/// The outbox stored a queued message: replaces its waiting copy ([localId]),
/// or drops that copy when the live event already showed the message.
void mergeSentMessage(List<Message> messages, String localId, Message message) {
  final cmid = message.clientMessageId;
  final shown = messages.indexWhere((m) =>
      m.id == message.id || (!m.isPending && cmid != null && m.clientMessageId == cmid));
  final local = messages.indexWhere((m) => m.id == localId);
  if (shown >= 0) {
    if (local >= 0 && local != shown) messages.removeAt(local);
    final i = messages.indexWhere((m) => m.id == message.id);
    if (i >= 0) messages[i] = message;
  } else if (local >= 0) {
    messages[local] = message;
  } else {
    messages.insert(0, message);
  }
}

/// A queued message left the queue unsent: failed, with Retry.
void markQueuedFailed(List<Message> messages, String localId) {
  final i = messages.indexWhere((m) => m.id == localId);
  if (i >= 0) messages[i] = messages[i].copyWith(isPending: false, isFailed: true);
}

/// Adds what the outbox still holds for the room (e.g. after a restart).
void addQueuedMessages(List<Message> messages, List<Message> queued) {
  for (final pending in queued) {
    final known = messages.any((m) =>
        m.id == pending.id ||
        (m.clientMessageId != null && m.clientMessageId == pending.clientMessageId));
    if (!known) messages.insert(0, pending); // oldest first in, newest ends on top
  }
}
