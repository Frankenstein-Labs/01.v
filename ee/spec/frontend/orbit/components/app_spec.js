import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import App from 'ee/orbit/components/app.vue';
import enabledMemberNamespacesQuery from 'ee/orbit/graphql/queries/enabled_member_namespaces.query.graphql';

Vue.use(VueApollo);

describe('OrbitApp tab tracking', () => {
  let wrapper;

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = async ({ routeName = 'explore' } = {}) => {
    const enabledHandler = jest.fn().mockResolvedValue({
      data: { groups: { nodes: [{ id: 'gid://gitlab/Group/1', knowledgeGraphEnabled: true }] } },
    });
    const apolloProvider = createMockApollo([[enabledMemberNamespacesQuery, enabledHandler]]);

    wrapper = mount(App, {
      apolloProvider,
      propsData: { configureMode: null, adminConfigurationPath: null },
      mocks: { $route: { name: routeName } },
      stubs: {
        'router-link': {
          props: ['to'],
          mixins: [glListenersMixin],
          template: '<a data-testid="orbit-tab" v-on="glListeners()"><slot /></a>',
        },
        'router-view': true,
        ConnectSection: true,
        AdminConfigureButton: true,
        GroupsConfigureButton: true,
      },
    });

    await waitForPromises();
  };

  it.each([
    ['schema', 'click_orbit_explore_tab', 0],
    ['explore', 'click_orbit_schema_tab', 1],
  ])(
    'from %s route, tracks %s when the inactive tab is clicked',
    async (routeName, action, index) => {
      await createComponent({ routeName });
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await wrapper.findAll('[data-testid="orbit-tab"]').at(index).trigger('click');

      expect(trackEventSpy).toHaveBeenCalledWith(action, {}, undefined);
    },
  );

  it.each([
    ['explore', 0],
    ['schema', 1],
  ])('does not track when clicking the already-active %s tab', async (routeName, index) => {
    await createComponent({ routeName });
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    await wrapper.findAll('[data-testid="orbit-tab"]').at(index).trigger('click');

    expect(trackEventSpy).not.toHaveBeenCalled();
  });
});
