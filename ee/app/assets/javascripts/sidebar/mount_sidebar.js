import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { apolloProvider } from '~/graphql_shared/issuable_client';
import { TYPE_ISSUE } from '~/issues/constants';
import { parseBoolean } from '~/lib/utils/common_utils';
import * as CEMountSidebar from '~/sidebar/mount_sidebar';
import { pinia } from '~/pinia/instance';
import CveIdRequest from './components/cve_id_request/cve_id_request.vue';
import SidebarIterationWidget from './components/iteration/sidebar_iteration_widget.vue';
import SidebarHealthStatusWidget from './components/health_status/sidebar_health_status_widget.vue';
import SidebarWeightWidget from './components/weight/sidebar_weight_widget.vue';
import SidebarEscalationPolicy from './components/incidents/sidebar_escalation_policy.vue';
import { IssuableAttributeType } from './constants';

Vue.use(VueApollo);

const mountSidebarWeightWidget = () => {
  const el = document.querySelector('.js-sidebar-weight-widget-root');

  if (!el) {
    return null;
  }

  const { canEdit, projectPath, issueIid } = el.dataset;

  return initVueApp({
    el,
    name: 'SidebarWeightWidgetRoot',
    apolloProvider,
    provide: {
      canUpdate: parseBoolean(canEdit),
      isClassicSidebar: true,
    },
    component: SidebarWeightWidget,
    props: {
      fullPath: projectPath,
      iid: issueIid,
      issuableType: TYPE_ISSUE,
    },
  });
};

const mountSidebarHealthStatusWidget = () => {
  const el = document.querySelector('.js-sidebar-health-status-widget-root');

  if (!el) {
    return null;
  }

  const { iid, fullPath, issuableType, canEdit } = el.dataset;

  return initVueApp({
    el,
    name: 'SidebarHealthStatusWidgetRoot',
    apolloProvider,
    provide: {
      canUpdate: parseBoolean(canEdit),
    },
    component: SidebarHealthStatusWidget,
    props: {
      fullPath,
      iid,
      issuableType,
    },
  });
};

function mountSidebarCveIdRequest() {
  const el = document.querySelector('.js-sidebar-cve-id-request-root');

  if (!el) {
    return null;
  }

  const { iid, fullPath } = CEMountSidebar.getSidebarOptions();

  return initVueApp({
    pinia,
    el,
    name: 'SidebarCveIdRequestRoot',
    provide: {
      iid: String(iid),
      fullPath,
    },
    component: CveIdRequest,
  });
}

function mountSidebarIterationWidget() {
  const el = document.querySelector('.js-sidebar-iteration-widget-root');

  if (!el) {
    return null;
  }

  const { groupPath, canEdit, projectPath, issueIid } = el.dataset;

  return initVueApp({
    el,
    name: 'SidebarIterationWidgetRoot',
    apolloProvider,
    provide: {
      canUpdate: parseBoolean(canEdit),
      isClassicSidebar: true,
    },
    component: SidebarIterationWidget,
    props: {
      attrWorkspacePath: groupPath,
      workspacePath: projectPath,
      iid: issueIid,
      issuableType: TYPE_ISSUE,
      issuableAttribute: IssuableAttributeType.Iteration,
    },
  });
}

function mountSidebarEscalationPolicy() {
  const el = document.querySelector('.js-sidebar-escalation-policy-root');

  if (!el) {
    return null;
  }

  const { canEdit, projectPath, issueIid, hasEscalationPolicies } = el.dataset;

  return initVueApp({
    el,
    name: 'SidebarEscalationPolicyRoot',
    apolloProvider,
    provide: {
      canUpdate: parseBoolean(canEdit),
      isClassicSidebar: true,
    },
    component: SidebarEscalationPolicy,
    props: {
      projectPath,
      iid: issueIid,
      escalationsPossible: parseBoolean(hasEscalationPolicies),
    },
  });
}

export const { getSidebarOptions } = CEMountSidebar;

export function mountSidebar(mediator) {
  CEMountSidebar.mountSidebar(mediator);
  mountSidebarWeightWidget();
  mountSidebarHealthStatusWidget();
  mountSidebarIterationWidget();
  mountSidebarEscalationPolicy();
  mountSidebarCveIdRequest();
}
