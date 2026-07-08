import 'package:flutter_test/flutter_test.dart';
import 'package:worklog_studio/domain/project.dart';
import 'package:worklog_studio/domain/task.dart';
import 'package:worklog_studio/state/project_task_state.dart';

import '../helpers/test_fakes.dart';

Project _project(String id, {String name = 'Project'}) => Project(
      id: id,
      name: name,
      description: '',
      createdAt: DateTime(2025, 1, 1),
    );

Task _task(String id, String projectId, {String title = 'Task'}) => Task(
      id: id,
      projectId: projectId,
      title: title,
      description: '',
      status: TaskStatus.open,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  late FakeProjectRepository projectRepo;
  late FakeTaskRepository taskRepo;
  late FakeClock clock;

  ProjectTaskState buildSut() => ProjectTaskState(
        projectRepository: projectRepo,
        taskRepository: taskRepo,
        clock: clock,
      );

  setUp(() {
    projectRepo = FakeProjectRepository();
    taskRepo = FakeTaskRepository();
    clock = FakeClock(DateTime(2025, 1, 1, 9));
  });

  group('loadData', () {
    test('populates projects and tasks from repositories', () async {
      projectRepo.all; // confirm empty before seeding
      await projectRepo.insert(_project('p1'));
      await taskRepo.insert(_task('t1', 'p1'));

      final sut = buildSut();
      await Future<void>.delayed(Duration.zero); // let _init complete

      expect(sut.projects, hasLength(1));
      expect(sut.projects.first.id, 'p1');
      expect(sut.tasks, hasLength(1));
      expect(sut.tasks.first.id, 't1');
    });

    test('emits a notification when data loads', () async {
      await projectRepo.insert(_project('p1'));
      final sut = buildSut();
      int notifications = 0;
      sut.addListener(() => notifications++);

      await Future<void>.delayed(Duration.zero);

      expect(notifications, 1);
    });
  });

  group('createProject', () {
    test('persists a new project and triggers reload', () async {
      final sut = buildSut();
      await Future<void>.delayed(Duration.zero);

      await sut.createProject('New Project', 'desc');

      expect(sut.projects, hasLength(1));
      expect(sut.projects.first.name, 'New Project');
      expect(projectRepo.all, hasLength(1));
    });

    test('uses the clock for createdAt', () async {
      final sut = buildSut();
      await Future<void>.delayed(Duration.zero);

      final project = await sut.createProject('P', '');

      expect(project.createdAt, clock.now());
    });
  });

  group('updateProject', () {
    test('persists the updated project and triggers reload', () async {
      await projectRepo.insert(_project('p1', name: 'Old Name'));
      final sut = buildSut();
      await Future<void>.delayed(Duration.zero);

      await sut.updateProject(sut.projects.first.copyWith(name: 'New Name'));

      expect(sut.projects.first.name, 'New Name');
      expect(projectRepo.all.first.name, 'New Name');
    });
  });

  group('deleteProject', () {
    test('removes the project from the repository and triggers reload', () async {
      await projectRepo.insert(_project('p1'));
      final sut = buildSut();
      await Future<void>.delayed(Duration.zero);
      expect(sut.projects, hasLength(1));

      await sut.deleteProject('p1');

      expect(sut.projects, isEmpty);
      expect(projectRepo.all, isEmpty);
    });
  });

  group('createTask', () {
    test('persists a new task and triggers reload', () async {
      await projectRepo.insert(_project('p1'));
      final sut = buildSut();
      await Future<void>.delayed(Duration.zero);

      await sut.createTask('p1', 'My Task', '');

      expect(sut.tasks, hasLength(1));
      expect(sut.tasks.first.title, 'My Task');
    });
  });

  group('updateTask', () {
    test('persists the updated task and triggers reload', () async {
      await taskRepo.insert(_task('t1', 'p1', title: 'Old'));
      final sut = buildSut();
      await Future<void>.delayed(Duration.zero);

      await sut.updateTask(sut.tasks.first.copyWith(title: 'New'));

      expect(sut.tasks.first.title, 'New');
    });
  });

  group('deleteTask', () {
    test('removes the task and triggers reload', () async {
      await taskRepo.insert(_task('t1', 'p1'));
      final sut = buildSut();
      await Future<void>.delayed(Duration.zero);

      await sut.deleteTask('t1');

      expect(sut.tasks, isEmpty);
    });
  });

  group('updateDraft', () {
    test('sets projectId and preserves taskId when project does not change', () async {
      final sut = buildSut();
      sut.updateDraft(projectId: 'p1', taskId: 't1');
      expect(sut.draftProjectId, 'p1');
      expect(sut.draftTaskId, 't1');

      sut.updateDraft(projectId: 'p1', taskId: 't2');
      expect(sut.draftTaskId, 't2');
    });

    test('clears taskId when projectId changes', () async {
      final sut = buildSut();
      sut.updateDraft(projectId: 'p1', taskId: 't1');

      sut.updateDraft(projectId: 'p2');

      expect(sut.draftProjectId, 'p2');
      expect(sut.draftTaskId, isNull);
    });

    test('clearTaskId flag clears taskId independently of projectId change', () {
      final sut = buildSut();
      sut.updateDraft(projectId: 'p1', taskId: 't1');

      sut.updateDraft(clearTaskId: true);

      expect(sut.draftProjectId, 'p1');
      expect(sut.draftTaskId, isNull);
    });

    test('sets comment', () {
      final sut = buildSut();
      sut.updateDraft(comment: 'hello');
      expect(sut.draftComment, 'hello');
    });

    test('notifies listeners', () {
      final sut = buildSut();
      int count = 0;
      sut.addListener(() => count++);

      sut.updateDraft(comment: 'x');

      expect(count, 1);
    });
  });

  group('clearDraft', () {
    test('resets all draft fields to null/empty', () {
      final sut = buildSut();
      sut.updateDraft(projectId: 'p1', taskId: 't1', comment: 'c');

      sut.clearDraft();

      expect(sut.draftProjectId, isNull);
      expect(sut.draftTaskId, isNull);
      expect(sut.draftComment, '');
    });
  });
}
