import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge/shared/models/models.dart';

void main() {
  group('Coverage', () {
    test('parses counts and percentage', () {
      final coverage = Coverage.fromJson({
        'matched_required': 4,
        'total_required': 6,
        'percentage': 66.67,
      });

      expect(coverage.matchedRequired, 4);
      expect(coverage.totalRequired, 6);
      expect(coverage.percentage, 66.67);
    });

    test('treats an undefined percentage as null', () {
      final coverage = Coverage.fromJson({
        'matched_required': 0,
        'total_required': 0,
        'percentage': null,
      });

      expect(coverage.percentage, isNull);
    });
  });

  group('AnalysisDetail', () {
    test('separates matched, missing and related skills', () {
      final detail = AnalysisDetail.fromJson({
        'id': 'a1',
        'status': 'completed',
        'created_at': '2026-11-24T10:00:00Z',
        'coverage': {
          'matched_required': 2,
          'total_required': 3,
          'percentage': 66.67,
        },
        'matched_skills': [
          {'skill': 'Docker', 'evidence': 'Containerized services with Docker.', 'confidence': 1.0},
        ],
        'missing_skills': [
          {'skill': 'Kubernetes', 'priority': 'high', 'reason': 'Required by the target role'},
        ],
        'related_skills': [
          {'skill': 'Python', 'priority': 'medium', 'reason': 'Related experience: FastAPI'},
        ],
      });

      expect(detail.isCompleted, isTrue);
      expect(detail.coverage?.percentage, 66.67);
      expect(detail.matchedSkills.single.skill, 'Docker');
      expect(detail.missingSkills.single.priority, 'high');
      expect(detail.relatedSkills.single.skill, 'Python');
    });
  });

  group('Roadmap', () {
    test('computes progress from completed tasks', () {
      final roadmap = Roadmap.fromJson({
        'id': 'r1',
        'analysis_id': 'a1',
        'created_at': '2026-11-24T10:00:00Z',
        'tasks': [
          {'id': 't2', 'title': 'Second', 'status': 'completed', 'sort_order': 2},
          {'id': 't1', 'title': 'First', 'status': 'pending', 'sort_order': 1},
        ],
      });

      expect(roadmap.tasks.first.id, 't1');
      expect(roadmap.completedCount, 1);
      expect(roadmap.progress, 0.5);
    });
  });

  group('ResumeDetail', () {
    test('parses verbatim evidence', () {
      final resume = ResumeDetail.fromJson({
        'id': 'r1',
        'status': 'completed',
        'created_at': '2026-11-24T10:00:00Z',
        'original_filename': 'resume.pdf',
        'skills': [
          {'skill': 'React', 'evidence': 'Built a React dashboard.', 'confidence': 1.0},
        ],
      });

      expect(resume.originalFilename, 'resume.pdf');
      expect(resume.skills.single.evidence, 'Built a React dashboard.');
    });
  });
}
