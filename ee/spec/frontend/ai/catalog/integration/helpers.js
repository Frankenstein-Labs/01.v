import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import {
  AI_CATALOG_INDEX_ROUTE,
  AI_CATALOG_AGENTS_SHOW_ROUTE,
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_NEW_ROUTE,
  AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_FLOWS_SHOW_ROUTE,
  AI_CATALOG_FLOWS_NEW_ROUTE,
  AI_CATALOG_FLOWS_EDIT_ROUTE,
  AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
  AI_CATALOG_MCP_SERVERS_ROUTE,
  AI_CATALOG_MCP_SERVERS_SHOW_ROUTE,
  AI_CATALOG_MCP_SERVERS_NEW_ROUTE,
  AI_CATALOG_MCP_SERVERS_EDIT_ROUTE,
} from 'ee/ai/catalog/router/constants';

Vue.use(VueApollo);
Vue.use(VueRouter);

export const ElementRootRouterLinkStub = {
  name: 'RouterLink',
  props: ['to'],
  template: '<a :href="to"><slot /></a>',
};

export const EXPLORE_PROVIDE = {
  isGlobalNamespace: true,
  isProjectNamespace: false,
  isGroupNamespace: false,
  projectId: null,
  projectPath: null,
  groupId: null,
  groupPath: null,
  rootGroupId: null,
  glAbilities: { readAiCatalog: true, reportAiCatalogItem: true },
};

export const PROJECT_PROVIDE = {
  isGlobalNamespace: false,
  isProjectNamespace: true,
  isGroupNamespace: false,
  projectId: '1',
  projectPath: 'group-1/project-1',
  groupId: null,
  groupPath: null,
  rootGroupId: '1',
  duoSettings: {
    duoCustomAgentsEnabled: true,
    duoCustomFlowsEnabled: true,
    duoExternalAgentsEnabled: true,
  },
};

export const GROUP_PROVIDE = {
  isGlobalNamespace: false,
  isProjectNamespace: false,
  isGroupNamespace: true,
  projectId: null,
  projectPath: null,
  groupId: '1',
  groupPath: 'group-1',
  rootGroupId: null,
  duoSettings: {
    duoCustomAgentsEnabled: true,
    duoCustomFlowsEnabled: true,
    duoExternalAgentsEnabled: true,
  },
};

// Cross-namespace provides: the user browses from a namespace in group-2,
// while the catalog item is owned by group-1. This exercises cross-group RBAC.
export const EXTERNAL_PROJECT_PROVIDE = {
  isGlobalNamespace: false,
  isProjectNamespace: true,
  isGroupNamespace: false,
  projectId: '2',
  projectPath: 'group-2/project-2',
  groupId: null,
  groupPath: null,
  rootGroupId: '2',
  duoSettings: {
    duoCustomAgentsEnabled: true,
    duoCustomFlowsEnabled: true,
    duoExternalAgentsEnabled: true,
  },
};

export const EXTERNAL_GROUP_PROVIDE = {
  isGlobalNamespace: false,
  isProjectNamespace: false,
  isGroupNamespace: true,
  projectId: null,
  projectPath: null,
  groupId: '2',
  groupPath: 'group-2',
  rootGroupId: null,
};

const EmptyRouteComponent = { template: '<div />' };

const ALL_ROUTES = [
  { name: AI_CATALOG_INDEX_ROUTE, path: '/', component: EmptyRouteComponent },
  { name: AI_CATALOG_AGENTS_ROUTE, path: '/agents', component: EmptyRouteComponent },
  { name: AI_CATALOG_AGENTS_NEW_ROUTE, path: '/agents/new', component: EmptyRouteComponent },
  { name: AI_CATALOG_AGENTS_SHOW_ROUTE, path: '/agents/:id', component: EmptyRouteComponent },
  { name: AI_CATALOG_AGENTS_EDIT_ROUTE, path: '/agents/:id/edit', component: EmptyRouteComponent },
  {
    name: AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
    path: '/agents/:id/duplicate',
    component: EmptyRouteComponent,
  },
  { name: AI_CATALOG_FLOWS_ROUTE, path: '/flows', component: EmptyRouteComponent },
  { name: AI_CATALOG_FLOWS_NEW_ROUTE, path: '/flows/new', component: EmptyRouteComponent },
  { name: AI_CATALOG_FLOWS_SHOW_ROUTE, path: '/flows/:id', component: EmptyRouteComponent },
  { name: AI_CATALOG_FLOWS_EDIT_ROUTE, path: '/flows/:id/edit', component: EmptyRouteComponent },
  {
    name: AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
    path: '/flows/:id/duplicate',
    component: EmptyRouteComponent,
  },
  { name: AI_CATALOG_MCP_SERVERS_ROUTE, path: '/mcp-servers', component: EmptyRouteComponent },
  {
    name: AI_CATALOG_MCP_SERVERS_NEW_ROUTE,
    path: '/mcp-servers/new',
    component: EmptyRouteComponent,
  },
  {
    name: AI_CATALOG_MCP_SERVERS_SHOW_ROUTE,
    path: '/mcp-servers/:id',
    component: EmptyRouteComponent,
  },
  {
    name: AI_CATALOG_MCP_SERVERS_EDIT_ROUTE,
    path: '/mcp-servers/:id/edit',
    component: EmptyRouteComponent,
  },
];

const DEFAULT_ROUTE = {
  name: AI_CATALOG_AGENTS_SHOW_ROUTE,
  params: { id: '1' },
  query: {},
};

export const ROUTE_PRESETS = {
  agentShow: {
    name: AI_CATALOG_AGENTS_SHOW_ROUTE,
    params: { id: '1' },
    query: {},
  },
  agentList: {
    name: AI_CATALOG_AGENTS_ROUTE,
    params: {},
    query: {},
  },
  agentEdit: {
    name: AI_CATALOG_AGENTS_EDIT_ROUTE,
    params: { id: '1' },
    query: {},
  },
  agentNew: {
    name: AI_CATALOG_AGENTS_NEW_ROUTE,
    params: {},
    query: {},
  },
  agentDuplicate: {
    name: AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
    params: { id: '1' },
    query: {},
  },
  flowList: {
    name: AI_CATALOG_FLOWS_ROUTE,
    params: {},
    query: {},
  },
  flowNew: {
    name: AI_CATALOG_FLOWS_NEW_ROUTE,
    params: {},
    query: {},
  },
  flowShow: {
    name: AI_CATALOG_FLOWS_SHOW_ROUTE,
    params: { id: '1' },
    query: {},
  },
  flowEdit: {
    name: AI_CATALOG_FLOWS_EDIT_ROUTE,
    params: { id: '1' },
    query: {},
  },
  flowDuplicate: {
    name: AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
    params: { id: '1' },
    query: {},
  },
  mcpServerList: {
    name: AI_CATALOG_MCP_SERVERS_ROUTE,
    params: {},
    query: {},
  },
  mcpServerShow: {
    name: AI_CATALOG_MCP_SERVERS_SHOW_ROUTE,
    params: { id: '1' },
    query: {},
  },
  mcpServerNew: {
    name: AI_CATALOG_MCP_SERVERS_NEW_ROUTE,
    params: {},
    query: {},
  },
  mcpServerEdit: {
    name: AI_CATALOG_MCP_SERVERS_EDIT_ROUTE,
    params: { id: '1' },
    query: {},
  },
};

export const createMockRouter = (route = DEFAULT_ROUTE) => {
  const router = new VueRouter({
    mode: 'abstract',
    routes: ALL_ROUTES,
  });
  router.push({ name: route.name, params: route.params, query: route.query }).catch(() => {});
  return router;
};

export const createIntegrationWrapper = (
  component,
  {
    provide = {},
    props = {},
    apolloHandlers = [],
    route = DEFAULT_ROUTE,
    stubs = {},
    mocks = {},
    router: externalRouter,
  } = {},
) => {
  const mockApollo = createMockApollo(apolloHandlers);
  const router = externalRouter ?? createMockRouter(route);

  const toast = { show: jest.fn() };

  const wrapper = mountExtended(component, {
    attachTo: document.body,
    apolloProvider: mockApollo,
    router,
    propsData: props,
    provide: {
      ...EXPLORE_PROVIDE,
      ...provide,
    },
    stubs: {
      teleport: true,
      RouterLink: ElementRootRouterLinkStub,
      ...stubs,
    },
    mocks: {
      $toast: toast,
      ...mocks,
    },
  });

  return { wrapper, apolloProvider: mockApollo, router, toast };
};

export const ACTION_STATE = {
  VISIBLE: 'visible',
  HIDDEN: 'hidden',
  DISABLED: 'disabled',
};

export const openActionsDropdown = (wrapper) => {
  const dropdown = wrapper.findByTestId('more-actions-dropdown');
  if (dropdown.exists()) {
    return dropdown.trigger('click');
  }
  return Promise.resolve();
};

export const expectActions = (wrapper, actions) => {
  for (const [id, expectedState] of Object.entries(actions)) {
    if (!Object.values(ACTION_STATE).includes(expectedState)) {
      throw new Error(
        `Invalid state "${expectedState}" for "${id}". Must be one of: ${Object.values(ACTION_STATE).join(', ')}.`,
      );
    }

    const element = wrapper.findByTestId(id);

    if (expectedState === ACTION_STATE.HIDDEN) {
      expect(element.exists()).toBe(false);
    } else {
      expect(element.exists()).toBe(true);

      if (expectedState === ACTION_STATE.DISABLED) {
        const isDisabled =
          element.attributes('disabled') !== undefined ||
          element.attributes('aria-disabled') === 'true';
        expect(isDisabled).toBe(true);
      }
    }
  }
};

const clickDropdownItem = async (wrapper, testId) => {
  const item = wrapper.findByTestId(testId);
  await item.find('button').trigger('click');
  await Vue.nextTick();
};

const clickModalPrimaryButton = async (modalId) => {
  const primaryButton = document.querySelector(`#${modalId} .js-modal-action-primary`);
  primaryButton.click();
  await Vue.nextTick();
};

export const clickDeleteAndConfirm = async (wrapper) => {
  await clickDropdownItem(wrapper, 'delete-button');
  await waitForPromises();
  await clickModalPrimaryButton('delete-item-modal');
};

export const clickDisableAndConfirm = async (wrapper) => {
  const btn = wrapper.findByTestId('disable-button');
  await btn.trigger('click');
  await waitForPromises();
  await clickModalPrimaryButton('disable-item-modal');
};

export const fillFormField = async (wrapper, testId, value) => {
  const field = wrapper.findByTestId(testId);
  await field.setValue(value);
};

export const submitAgentForm = async (wrapper) => {
  const form = wrapper.find('form');
  await form.trigger('submit');
  await waitForPromises();
};

export const clickEnableButton = async (wrapper) => {
  const btn = wrapper.findByTestId('enable-button');
  await btn.trigger('click');
  await Vue.nextTick();
  await waitForPromises();
};

export const selectEnableModalDropdownItem = async (toggleId, itemId) => {
  const toggle = document.getElementById(toggleId);
  toggle.click();
  await Vue.nextTick();
  await waitForPromises();

  const selector = `[data-testid="listbox-item-${itemId}"]`;
  const option = document.querySelector(selector);
  option.click();
  await Vue.nextTick();
};

export const selectDropdownItem = async (wrapper, toggleId, itemId) => {
  wrapper.find(`#${toggleId}`).element.click();
  await Vue.nextTick();
  await waitForPromises();

  wrapper.find(`[data-testid="listbox-item-${itemId}"]`).element.click();
  await Vue.nextTick();
};

export const submitEnableModal = async () => {
  await clickModalPrimaryButton('enable-item-modal');
};

export const clickReportAndFillForm = async (wrapper, { reason, body } = {}) => {
  await openActionsDropdown(wrapper);
  await clickDropdownItem(wrapper, 'report-button');
  await Vue.nextTick();
  await waitForPromises();

  if (reason) {
    const radios = document.querySelectorAll('#ai-catalog-item-report-modal input[type="radio"]');
    const target = [...radios].find((r) => r.value === reason);
    if (target) {
      target.click();
      await Vue.nextTick();
    }
  }

  if (body) {
    const textarea = document.querySelector('#ai-catalog-item-report-modal #report-body');
    if (textarea) {
      textarea.value = body;
      textarea.dispatchEvent(new Event('input', { bubbles: true }));
      await Vue.nextTick();
    }
  }

  await clickModalPrimaryButton('ai-catalog-item-report-modal');
};

export const SourceEditorStub = {
  props: ['value'],
  template: '<textarea :value="value" @input="$emit(\'input\', $event.target.value)" />',
};
