import VueRouter from 'vue-router';

import {
  ROUTE_STANDARDS_ADHERENCE,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  ROUTE_VIOLATIONS,
  ROUTE_NEW_FRAMEWORK,
  ROUTE_EDIT_FRAMEWORK,
  ROUTE_NEW_FRAMEWORK_SUCCESS,
  ROUTE_BLANK_FRAMEWORK,
  ROUTE_EXPORT_FRAMEWORK,
  ROUTE_DASHBOARD,
} from './constants';

import MainLayout from './components/main_layout.vue';

import ComplianceDashboard from './components/dashboard/compliance_dashboard.vue';
import ViolationsReport from './components/violations_report/violations_report.vue';
import FrameworksReport from './components/frameworks_report/report.vue';
import FrameworkWizard from './components/frameworks_report/wizard/framework_wizard.vue';
import ProjectsReport from './components/projects_report/report.vue';
import StandardsReport from './components/standards_adherence_report/report.vue';
import StandardsAdherenceUpsell from './components/standards_adherence_report/standards_adherence_upsell.vue';
import NewFrameworkSuccess from './components/frameworks_report/wizard/new_framework_success.vue';

export function createRouter(basePath, props) {
  const {
    groupPath,
    groupName,
    groupComplianceCenterPath,
    projectId,
    projectPath,
    projectName,
    rootAncestorPath,
    rootAncestorName,
    rootAncestorComplianceCenterPath,
    routes: availableRoutes,
    adherenceReportEnabled,
    adherenceReportUpgradePath,
  } = props;

  const availableTabRoutes = [
    {
      path: ROUTE_DASHBOARD,
      name: ROUTE_DASHBOARD,
      component: ComplianceDashboard,
      props: {
        groupPath,
        rootAncestorPath,
      },
    },
    {
      path: ROUTE_STANDARDS_ADHERENCE,
      name: ROUTE_STANDARDS_ADHERENCE,
      component: adherenceReportEnabled ? StandardsReport : StandardsAdherenceUpsell,
      props: adherenceReportEnabled
        ? {
            groupPath,
            projectPath,
            rootAncestorPath,
          }
        : {
            upgradePath: adherenceReportUpgradePath,
          },
    },
    {
      path: ROUTE_VIOLATIONS,
      name: ROUTE_VIOLATIONS,
      component: ViolationsReport,
      props: {
        groupPath,
        projectPath,
      },
    },
    {
      path: ROUTE_FRAMEWORKS,
      name: ROUTE_FRAMEWORKS,
      component: FrameworksReport,
      props: {
        groupPath,
        projectPath,
        rootAncestor: {
          path: rootAncestorPath,
          name: rootAncestorName,
          complianceCenterPath: rootAncestorComplianceCenterPath,
        },
      },
    },
    {
      path: ROUTE_PROJECTS,
      name: ROUTE_PROJECTS,
      component: ProjectsReport,
      props: {
        groupPath,
        groupName,
        groupComplianceCenterPath,
        projectId,
        projectPath,
        projectName,
        rootAncestor: {
          path: rootAncestorPath,
          name: rootAncestorName,
          complianceCenterPath: rootAncestorComplianceCenterPath,
        },
      },
    },
  ].filter(({ name }) => availableRoutes.includes(name));

  const defaultRoute = availableTabRoutes[0].name;

  const routes = [
    {
      path: `/${ROUTE_FRAMEWORKS}/new`,
      name: ROUTE_NEW_FRAMEWORK,
      component: FrameworkWizard,
    },
    {
      path: '/frameworks/blank',
      name: ROUTE_BLANK_FRAMEWORK,
      component: FrameworkWizard,
    },
    {
      path: `/${ROUTE_FRAMEWORKS}/new/success`,
      name: ROUTE_NEW_FRAMEWORK_SUCCESS,
      component: NewFrameworkSuccess,
    },
    {
      path: `/${ROUTE_FRAMEWORKS}/:id`,
      name: ROUTE_EDIT_FRAMEWORK,
      component: FrameworkWizard,
    },
    {
      path: '/',
      component: MainLayout,
      props: {
        availableTabs: availableRoutes,
        projectPath,
        groupPath,
        rootAncestor: {
          path: rootAncestorPath,
          name: rootAncestorName,
          complianceCenterPath: rootAncestorComplianceCenterPath,
        },
      },
      children: [...availableTabRoutes, { path: '*', redirect: { name: defaultRoute } }],
    },
    {
      name: ROUTE_EXPORT_FRAMEWORK,
      path: '/frameworks/:id.json',
    },
  ];

  return new VueRouter({
    mode: 'history',
    base: basePath,
    routes,
  });
}
