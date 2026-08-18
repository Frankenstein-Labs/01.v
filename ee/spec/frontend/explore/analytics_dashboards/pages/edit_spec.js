import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlEmptyState, GlDashboardLayout } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ExploreAnalyticsDashboardEdit from 'ee/explore/analytics_dashboards/pages/edit.vue';
import DashboardSettingsDrawer from 'ee/explore/analytics_dashboards/components/dashboard_settings_drawer.vue';
import AddPanelDrawer from 'ee/explore/analytics_dashboards/components/add_panel_drawer.vue';
import DashboardLoader from '~/explore/analytics_dashboards/components/dashboard_loader.vue';
import AnalyticsDashboardPanel from '~/analytics/shared/components/analytics_dashboard_panel.vue';
import getDashboardQuery from '~/explore/analytics_dashboards/graphql/get_dashboard.query.graphql';
import updateCustomDashboardMutation from 'ee/explore/analytics_dashboards/graphql/update_custom_dashboard.mutation.graphql';
import { mockDashboardResponse } from '../mock_data';

Vue.use(VueApollo);

describe('ExploreAnalyticsDashboardEdit', () => {
  let wrapper;
  let mockApollo;

  const mockBreadcrumbState = { name: '', slug: '', update: jest.fn() };
  const mockToastShow = jest.fn();

  const dashboardId = 'gid://gitlab/Analytics::CustomDashboards::Dashboard/3';

  const successMutationHandler = jest.fn().mockResolvedValue({
    data: {
      updateCustomDashboard: {
        dashboard: {
          id: dashboardId,
          name: 'Custom dashboard',
          description: 'A very much more specific description',
        },
        errors: [],
      },
    },
  });

  const createMockApolloProvider = ({
    queryResponse = mockDashboardResponse,
    mutationHandler = successMutationHandler,
  } = {}) =>
    createMockApollo([
      [getDashboardQuery, jest.fn().mockResolvedValue({ data: queryResponse })],
      [updateCustomDashboardMutation, mutationHandler],
    ]);

  const mockResolvedQuery = (queryResponse = mockDashboardResponse) =>
    createMockApolloProvider({ queryResponse });

  const emptyDashboardResponse = {
    customDashboard: {
      ...mockDashboardResponse.customDashboard,
      config: {
        ...mockDashboardResponse.customDashboard.config,
        panels: [],
      },
    },
  };

  const createComponent = ({ requestHandlers, stubs = {} } = {}) => {
    mockApollo = requestHandlers || createMockApolloProvider();
    jest.spyOn(mockApollo.defaultClient, 'mutate');

    wrapper = shallowMountExtended(ExploreAnalyticsDashboardEdit, {
      apolloProvider: mockApollo,
      provide: { breadcrumbState: mockBreadcrumbState },
      mocks: { $route: { params: { slug: '3' } }, $toast: { show: mockToastShow } },
      stubs: { DashboardLoader, ...stubs },
    });
  };

  // Renders the panel scoped slot for each configured panel so the panel
  // contents can be asserted under a shallow mount.
  const GlDashboardLayoutStub = {
    name: 'GlDashboardLayoutStub',
    props: ['config'],
    template: `
      <div>
        <div v-for="(panel, index) in config.panels" :key="index">
          <slot name="panel" :panel="panel"></slot>
        </div>
      </div>
    `,
  };

  const findAddPanelButton = () => wrapper.findComponentByTestId('dashboard-add-panel-button');
  const findEmptyStateAddPanelButton = () =>
    wrapper.findComponentByTestId('empty-state-add-panel-button');
  const findSaveButton = () => wrapper.findComponentByTestId('dashboard-save-button');
  const findSettingsButton = () => wrapper.findComponentByTestId('dashboard-settings-button');
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findSettingsDrawer = () => wrapper.findComponent(DashboardSettingsDrawer);
  const findSaveError = () => wrapper.findComponentByTestId('dashboard-save-error');
  const findAddPanelDrawer = () => wrapper.findComponent(AddPanelDrawer);
  const findDashboardLayout = () => wrapper.findComponent(GlDashboardLayout);
  const findPanels = () => wrapper.findAllComponents(AnalyticsDashboardPanel);

  describe('actions', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('shows the Add Panel button', () => {
      expect(findAddPanelButton().exists()).toBe(true);
      expect(findAddPanelButton().text()).toContain('Add panel');
    });

    it('shows the Settings cog button', () => {
      expect(findSettingsButton().exists()).toBe(true);
      expect(findSettingsButton().attributes('icon')).toBe('settings');
    });
  });

  describe('empty state', () => {
    it('does not show when there are panels', async () => {
      createComponent();
      await waitForPromises();

      expect(findEmptyState().exists()).toBe(false);
    });

    it('shows when there are no panels', async () => {
      createComponent({
        requestHandlers: mockResolvedQuery(emptyDashboardResponse),
      });
      await waitForPromises();

      expect(findEmptyState().exists()).toBe(true);
      expect(findEmptyState().props()).toMatchObject({
        title: 'Start building your dashboard',
        description: 'Add panels to this dashboard to visualize your analytics data.',
        illustrationName: 'empty-epic-md',
      });
    });
  });

  describe('settings drawer', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the settings drawer', () => {
      expect(findSettingsDrawer().exists()).toBe(true);
    });

    it('passes the correct props to the settings drawer', () => {
      expect(findSettingsDrawer().props()).toMatchObject({
        open: false,
        dashboardConfig: expect.any(Object),
        dashboardId: 'gid://gitlab/Analytics::CustomDashboards::Dashboard/3',
      });
    });

    describe('when the settings button is clicked', () => {
      beforeEach(async () => {
        findSettingsButton().vm.$emit('click');
        await nextTick();
      });

      it('opens the settings drawer', () => {
        expect(findSettingsDrawer().props('open')).toBe(true);
      });

      describe('when the settings drawer emits close', () => {
        beforeEach(async () => {
          findSettingsDrawer().vm.$emit('close');
          await nextTick();
        });

        it('closes the settings drawer', () => {
          expect(findSettingsDrawer().props('open')).toBe(false);
        });
      });
    });
  });

  describe('add panel drawer', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the add panel drawer', () => {
      expect(findAddPanelDrawer().exists()).toBe(true);
    });

    it('is closed by default', () => {
      expect(findAddPanelDrawer().props('open')).toBe(false);
    });

    describe('when the add panel button is clicked', () => {
      beforeEach(async () => {
        findAddPanelButton().vm.$emit('click');
        await nextTick();
      });

      it('opens the add panel drawer', () => {
        expect(findAddPanelDrawer().props('open')).toBe(true);
      });

      describe('when the add panel drawer emits close', () => {
        beforeEach(async () => {
          findAddPanelDrawer().vm.$emit('close');
          await nextTick();
        });

        it('closes the add panel drawer', () => {
          expect(findAddPanelDrawer().props('open')).toBe(false);
        });
      });
    });

    describe('when there are no panels', () => {
      beforeEach(async () => {
        createComponent({
          requestHandlers: mockResolvedQuery(emptyDashboardResponse),
        });
        await waitForPromises();
      });

      it('opens the add panel drawer when the empty state add panel button is clicked', async () => {
        expect(findAddPanelDrawer().props('open')).toBe(false);

        findEmptyStateAddPanelButton().vm.$emit('click');
        await nextTick();

        expect(findAddPanelDrawer().props('open')).toBe(true);
      });
    });
  });

  describe('drawer mutual exclusivity', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('closes the settings drawer when the add panel drawer is opened', async () => {
      findSettingsButton().vm.$emit('click');
      await nextTick();
      expect(findSettingsDrawer().props('open')).toBe(true);

      findAddPanelButton().vm.$emit('click');
      await nextTick();

      expect(findAddPanelDrawer().props('open')).toBe(true);
      expect(findSettingsDrawer().props('open')).toBe(false);
    });

    it('closes the add panel drawer when the settings drawer is opened', async () => {
      findAddPanelButton().vm.$emit('click');
      await nextTick();
      expect(findAddPanelDrawer().props('open')).toBe(true);

      findSettingsButton().vm.$emit('click');
      await nextTick();

      expect(findSettingsDrawer().props('open')).toBe(true);
      expect(findAddPanelDrawer().props('open')).toBe(false);
    });
  });

  describe('dashboard layout', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the dashboard layout with the loaded config', () => {
      const { config } = mockDashboardResponse.customDashboard;

      expect(findDashboardLayout().props('config')).toEqual({
        ...config,
        // Each panel is assigned a unique id by the dashboard loader.
        panels: config.panels.map((panel) => ({
          ...panel,
          id: expect.stringMatching(/^panel-\d+$/),
        })),
      });
    });

    it('renders an editable (non-static) grid', () => {
      expect(findDashboardLayout().props('isStaticGrid')).toBe(false);
    });

    describe('panels', () => {
      const { panels } = mockDashboardResponse.customDashboard.config;

      beforeEach(async () => {
        createComponent({ stubs: { GlDashboardLayout: GlDashboardLayoutStub } });
        await waitForPromises();
      });

      it('renders a panel for each configured panel', () => {
        expect(findPanels()).toHaveLength(panels.length);
      });

      it('passes the panel config to each rendered panel', () => {
        findPanels().wrappers.forEach((panel, index) => {
          expect(panel.props()).toMatchObject({
            title: panels[index].title,
            visualization: panels[index].visualization,
          });
        });
      });
    });

    describe('when the layout emits a change', () => {
      const reorderedPanels = [
        { id: 'panel-2', gridAttributes: { xPos: 0, yPos: 0, width: 3, height: 1 } },
        { id: 'panel-1', gridAttributes: { xPos: 3, yPos: 0, width: 3, height: 1 } },
      ];

      beforeEach(async () => {
        findDashboardLayout().vm.$emit('changed', { panels: reorderedPanels });
        await nextTick();
      });

      it('updates the layout config with the new panels', () => {
        expect(findDashboardLayout().props('config').panels).toEqual(reorderedPanels);
      });
    });
  });

  describe('adding a panel', () => {
    const visualization = { type: 'Glql', options: {} };
    const title = 'My panel';

    beforeEach(async () => {
      createComponent();
      await waitForPromises();

      findAddPanelButton().vm.$emit('click');
      await nextTick();

      findAddPanelDrawer().vm.$emit('add-panel', { title, visualization });
      await nextTick();
    });

    it('appends the new panel to the layout config', () => {
      const { panels } = findDashboardLayout().props('config');
      const initialCount = mockDashboardResponse.customDashboard.config.panels.length;

      expect(panels).toHaveLength(initialCount + 1);
      expect(panels[panels.length - 1]).toMatchObject({
        id: expect.stringMatching(/^panel-\d+$/),
        title,
        visualization,
        gridAttributes: { width: 6, height: 3 },
      });
    });

    it('closes the add panel drawer', () => {
      expect(findAddPanelDrawer().props('open')).toBe(false);
    });
  });

  describe('saving the dashboard', () => {
    const expectedInput = {
      id: dashboardId,
      name: 'Custom dashboard',
      description: 'A very much more specific description',
      config: expect.objectContaining({
        title: 'Custom dashboard',
        description: 'A very much more specific description',
        panels: expect.any(Array),
      }),
    };

    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('does not save until triggered', () => {
      expect(mockApollo.defaultClient.mutate).not.toHaveBeenCalled();
    });

    it('passes the saving state to the settings drawer', () => {
      expect(findSettingsDrawer().props('isSaving')).toBe(false);
    });

    it('does not show a save error', () => {
      expect(findSaveError().exists()).toBe(false);
    });

    describe.each`
      source                | trigger
      ${'edit save button'} | ${() => findSaveButton().vm.$emit('click')}
      ${'settings drawer'}  | ${() => findSettingsDrawer().vm.$emit('save')}
    `('when saving is triggered by the $source', ({ trigger }) => {
      beforeEach(async () => {
        trigger();
        await waitForPromises();
      });

      it('sends the update mutation with the dashboard config', () => {
        expect(mockApollo.defaultClient.mutate).toHaveBeenCalledWith(
          expect.objectContaining({
            mutation: updateCustomDashboardMutation,
            variables: { input: expect.objectContaining(expectedInput) },
          }),
        );
      });

      it('evicts the dashboard from the cache', () => {
        const mutateCall = mockApollo.defaultClient.mutate.mock.calls[0][0];
        expect(mutateCall.update).toBeDefined();
      });
    });

    it('shows the saving state while the mutation is in flight', async () => {
      findSaveButton().vm.$emit('click');
      await nextTick();

      expect(findSaveButton().props('loading')).toBe(true);
      expect(findSettingsDrawer().props('isSaving')).toBe(true);
    });

    describe('when the title and description are updated via the drawer', () => {
      beforeEach(async () => {
        findSettingsDrawer().vm.$emit('update', {
          ...findSettingsDrawer().props('dashboardConfig'),
          title: 'New title',
          description: 'New description',
        });
        await nextTick();
      });

      it('reflects the updated config in the settings drawer immediately', () => {
        expect(findSettingsDrawer().props('dashboardConfig')).toMatchObject({
          title: 'New title',
          description: 'New description',
        });
      });

      it('sends the updated config when saving', async () => {
        findSaveButton().vm.$emit('click');
        await waitForPromises();

        expect(mockApollo.defaultClient.mutate).toHaveBeenCalledWith(
          expect.objectContaining({
            variables: {
              input: expect.objectContaining({
                name: 'New title',
                description: 'New description',
              }),
            },
          }),
        );
      });
    });

    it('trims the title and description before sending the mutation', async () => {
      findSettingsDrawer().vm.$emit('update', {
        ...findSettingsDrawer().props('dashboardConfig'),
        title: '  Custom dashboard  ',
        description: '  A very much more specific description  ',
      });
      await nextTick();

      findSaveButton().vm.$emit('click');
      await waitForPromises();

      expect(mockApollo.defaultClient.mutate).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: {
            input: expect.objectContaining({
              name: 'Custom dashboard',
              description: 'A very much more specific description',
            }),
          },
        }),
      );
    });

    describe('panel serialization', () => {
      const findSavedPanels = () =>
        mockApollo.defaultClient.mutate.mock.calls[0][0].variables.input.config.panels;

      it('serializes each configured panel into the mutation format', async () => {
        findSaveButton().vm.$emit('click');
        await waitForPromises();

        const { panels } = mockDashboardResponse.customDashboard.config;

        // The client-only grid `id` is dropped and `visualization` becomes the
        // JSON `visualizationConfig` field the mutation expects.
        expect(findSavedPanels()).toEqual(
          panels.map(({ visualization, ...panel }) => ({
            ...panel,
            visualizationConfig: visualization,
          })),
        );
      });

      it('sends visualizationConfig and drops the client-side visualization and id', async () => {
        findSaveButton().vm.$emit('click');
        await waitForPromises();

        findSavedPanels().forEach((panel) => {
          expect(panel).toHaveProperty('visualizationConfig');
          expect(panel).not.toHaveProperty('visualization');
          expect(panel).not.toHaveProperty('id');
        });
      });

      it('serializes an added panel with its title', async () => {
        const visualization = { type: 'Glql', options: {} };

        findAddPanelButton().vm.$emit('click');
        await nextTick();
        findAddPanelDrawer().vm.$emit('add-panel', { title: 'Open issues', visualization });
        await nextTick();

        findSaveButton().vm.$emit('click');
        await waitForPromises();

        expect(findSavedPanels()).toContainEqual({
          title: 'Open issues',
          visualizationConfig: visualization,
          gridAttributes: { width: 6, height: 3 },
        });
      });
    });

    describe('when the title is blank', () => {
      beforeEach(async () => {
        findSettingsDrawer().vm.$emit('update', {
          ...findSettingsDrawer().props('dashboardConfig'),
          title: '   ',
          description: 'Test',
        });
        await nextTick();

        findSaveButton().vm.$emit('click');
        await waitForPromises();
      });

      it('does not send the mutation', () => {
        expect(mockApollo.defaultClient.mutate).not.toHaveBeenCalled();
      });

      it('shows the title required error at the top of the page', () => {
        expect(findSaveError().text()).toContain('Dashboard title is required');
      });
    });

    describe('on a successful save', () => {
      beforeEach(async () => {
        findSettingsButton().vm.$emit('click');
        await nextTick();

        findSettingsDrawer().vm.$emit('save');
        await waitForPromises();
      });

      it('closes the settings drawer', () => {
        expect(findSettingsDrawer().props('open')).toBe(false);
      });

      it('stops the saving state', () => {
        expect(findSettingsDrawer().props('isSaving')).toBe(false);
      });

      it('shows a success toast', () => {
        expect(mockToastShow).toHaveBeenCalledWith('Dashboard saved.');
      });
    });

    describe('when the mutation returns errors', () => {
      const error = 'Dashboard name already exists';

      beforeEach(async () => {
        createComponent({
          requestHandlers: createMockApolloProvider({
            mutationHandler: jest.fn().mockResolvedValue({
              data: {
                updateCustomDashboard: { dashboard: null, errors: [error] },
              },
            }),
          }),
        });
        await waitForPromises();

        findSettingsButton().vm.$emit('click');
        await nextTick();

        findSettingsDrawer().vm.$emit('save');
        await waitForPromises();
      });

      it('shows the error at the top of the page', () => {
        expect(findSaveError().text()).toContain(error);
      });

      it('keeps the settings drawer open', () => {
        expect(findSettingsDrawer().props('open')).toBe(true);
      });

      it('clears the error when the alert is dismissed', async () => {
        findSaveError().vm.$emit('dismiss');
        await nextTick();

        expect(findSaveError().exists()).toBe(false);
      });
    });

    describe('when the mutation fails', () => {
      beforeEach(async () => {
        createComponent({
          requestHandlers: createMockApolloProvider({
            mutationHandler: jest.fn().mockRejectedValue(new Error('Network error')),
          }),
        });
        await waitForPromises();

        findSaveButton().vm.$emit('click');
        await waitForPromises();
      });

      it('shows the generic error message at the top of the page', () => {
        expect(findSaveError().text()).toContain('Failed to update dashboard. Please try again.');
      });

      it('stops the saving state', () => {
        expect(findSettingsDrawer().props('isSaving')).toBe(false);
      });
    });
  });
});
