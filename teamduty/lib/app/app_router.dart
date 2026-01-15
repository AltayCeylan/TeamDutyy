import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_page.dart' as auth;

import '../features/home/admin_home_page.dart';
import '../features/home/employee_home_page.dart';
import '../features/home/create_company_page.dart';
import '../features/home/create_invite_page.dart';

import '../features/tasks/task_detail_page.dart';

import '../features/admin/departments_page.dart';
import '../features/admin/employees_page.dart';
import '../features/admin/create_task_page.dart';
// Eğer manager sayfan varsa aç:
// import '../features/manager/manager_home_page.dart';
import '../features/manager/manager_home_page.dart';
import '../features/manager/manager_create_task_page.dart';
import '../features/admin/admin_tasks_page.dart';
import '../features/admin/managers_page.dart';









class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
  path: '/admin/managers',
  builder: (context, state) => const ManagersPage(),
),

      GoRoute(
  path: '/admin/tasks',
  builder: (context, state) {
    final qp = state.uri.queryParameters;

    return AdminTasksPage(
      initialStatus: qp['status'], // "pending" | "done" | null
      initialOnlyOverdue: qp['overdue'] == '1',
      initialOnlyMine: qp['mine'] == '1',
      initialDepartmentId: qp['departmentId'],
      initialQuery: qp['q'],
    );
  },
),

     
      GoRoute(
  path: '/manager',
  builder: (context, state) => const ManagerHomePage(),
),
GoRoute(
  path: '/manager',
  builder: (context, state) => const ManagerHomePage(),
),
GoRoute(
  path: '/manager/task/create',
  builder: (context, state) => const ManagerCreateTaskPage(),
),


      GoRoute(
        path: '/login',
        builder: (context, state) => const auth.LoginPage(),
      ),

      // HOME
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminHomePage(),
      ),
      GoRoute(
        path: '/employee',
        builder: (context, state) => const EmployeeHomePage(),
      ),
      // Manager eklediysen aç:
      // GoRoute(
      //   path: '/manager',
      //   builder: (context, state) => const ManagerHomePage(),
      // ),

      // Şirket oluştur
      GoRoute(
        path: '/company/create',
        builder: (context, state) => const CompanyCreatePage(),
      ),

      // Admin sayfaları
      GoRoute(
        path: '/admin/invite',
        builder: (context, state) => const CreateInvitePage(),
      ),
      GoRoute(
        path: '/admin/departments',
        builder: (context, state) => const DepartmentsPage(),
      ),
      GoRoute(
        path: '/admin/employees',
        builder: (context, state) => const EmployeesPage(),
      ),
      GoRoute(
        path: '/admin/task/create',
        builder: (context, state) => const CreateTaskPage(),
      ),

      // Görev detayı
      GoRoute(
        path: '/company/:companyId/task/:taskId',
        builder: (context, state) {
          final companyId = state.pathParameters['companyId']!;
          final taskId = state.pathParameters['taskId']!;
          return TaskDetailPage(companyId: companyId, taskId: taskId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Sayfa bulunamadı: ${state.uri}'),
        ),
      ),
    ),
  );
}
