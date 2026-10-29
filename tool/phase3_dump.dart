import 'dart:convert';
import 'dart:io';

import 'package:masar_al_lugha/reading.dart';
import 'package:masar_al_lugha/grammar.dart';
import 'package:masar_al_lugha/conversation.dart';

/// Phase-3 Batch C: dump the three skill corpora as JSON for the
/// Python content auditor. Run: dart run tool/phase3_dump.dart > out.json
void main() {
  final out = {
    'reading': [
      for (final t in ReadingCatalog.texts)
        {
          'id': t.id,
          'courseId': t.courseId,
          'level': t.level,
          'titleAr': t.titleAr,
          'body': t.body,
          'sentencesAr': t.sentencesAr,
          'questions': [
            for (final q in t.questions)
              {
                'promptAr': q.promptAr,
                'options': q.options,
                'correct': q.correct
              },
          ],
        },
    ],
    'grammar': [
      for (final l in GrammarCatalog.lessons)
        {
          'id': l.id,
          'courseId': l.courseId,
          'level': l.level,
          'titleAr': l.titleAr,
          'pointsAr': l.pointsAr,
          'drills': [
            for (final d in l.drills)
              {
                'prompt': d.prompt,
                'options': d.options,
                'correct': d.correct,
                'explainAr': d.explainAr,
              },
          ],
        },
    ],
    'conversation': [
      for (final sc in ConversationCatalog.scenarios)
        {
          'id': sc.id,
          'courseId': sc.courseId,
          'level': sc.level,
          'titleAr': sc.titleAr,
          'roleAr': sc.roleAr,
          'closing': sc.closing,
          'closingAr': sc.closingAr,
          'steps': [
            for (final st in sc.steps)
              {
                'partner': st.partner,
                'partnerAr': st.partnerAr,
                'acceptAny': st.acceptAny,
                'sampleReply': st.sampleReply,
                'sampleReplyAr': st.sampleReplyAr,
              },
          ],
        },
    ],
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(out));
}
