import { shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { GlLoadingIcon } from '@gitlab/ui';
import App from 'ee/security_configuration/secret_detection/components/app.vue';
import ExclusionList from 'ee/security_configuration/secret_detection/components/exclusion_list.vue';
import ProjectSecurityExclusionQuery from 'ee/security_configuration/secret_detection/graphql/project_security_exclusions.query.graphql';
import EmptyState from 'ee/security_configuration/secret_detection/components/empty_state.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import ExclusionFormDrawer from 'ee/security_configuration/secret_detection/components/exclusion_form_drawer.vue';
import { DRAWER_MODES } from 'ee/security_configuration/secret_detection//constants';
import { projectSecurityExclusions } from '../mock_data';

Vue.use(VueApollo);

const mockExclusionListResolver = {
  data: {
    project: {
      id: 'gid://gitlab/Project/7',
      exclusions: {
        nodes: projectSecurityExclusions,
      },
    },
  },
};

const mockEmptyExclusionListResolver = {
  data: { project: { id: 'gid://gitlab/Project/7', exclusions: { nodes: [] } } },
};

describe('App', () => {
  let wrapper;
  let apolloProvider;

  const openMock = jest.fn();

  const createComponent = (options = {}) => {
    const {
      provide = {},
      resolver = jest.fn().mockResolvedValue(mockExclusionListResolver),
      ...otherOptions
    } = options;

    apolloProvider = createMockApollo([[ProjectSecurityExclusionQuery, resolver]]);

    wrapper = shallowMount(App, {
      apolloProvider,
      provide: {
        projectFullPath: 'group/project',
        ...provide,
      },
      stubs: {
        ExclusionFormDrawer: stubComponent(ExclusionFormDrawer, {
          methods: { open: openMock },
        }),
      },
      ...otherOptions,
    });
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findExclusionList = () => wrapper.findComponent(ExclusionList);

  it('renders the component', () => {
    createComponent();
    expect(wrapper.exists()).toBe(true);
  });

  it('displays loading icon when data is being fetched', async () => {
    createComponent();
    expect(findLoadingIcon().exists()).toBe(true);

    await waitForPromises();

    expect(findLoadingIcon().exists()).toBe(false);
  });

  it('displays empty state when there are no security exclusions', async () => {
    createComponent({
      resolver: jest.fn().mockResolvedValue(mockEmptyExclusionListResolver),
    });
    await waitForPromises();
    expect(wrapper.findComponent(EmptyState).exists()).toBe(true);
  });

  it('loads the exclusion drawer component', () => {
    createComponent();

    expect(wrapper.findComponent(ExclusionFormDrawer).exists()).toBe(true);
  });

  describe('Exclusion List', () => {
    it('displays security exclusions after data is fetched', async () => {
      createComponent();
      await waitForPromises();
      expect(findExclusionList().exists()).toBe(true);
      expect(findExclusionList().props('exclusions')).toEqual(projectSecurityExclusions);
    });

    describe('handles events correctly', () => {
      beforeEach(() => {
        createComponent();
      });

      it('@add-exclusion calls openDrawer with DRAWER_MODES.ADD', async () => {
        await waitForPromises();
        findExclusionList().vm.$emit('add-exclusion');
        expect(openMock).toHaveBeenCalledWith(DRAWER_MODES.ADD, undefined);
      });

      it('@edit-exclusion calls openDrawer with DRAWER_MODES.EDIT', async () => {
        await waitForPromises();
        findExclusionList().vm.$emit('edit-exclusion', { id: 1 });
        expect(openMock).toHaveBeenCalledWith(DRAWER_MODES.EDIT, { id: 1 });
      });

      it('@view-exclusion calls openDrawer with DRAWER_MODES.VIEW', async () => {
        await waitForPromises();
        findExclusionList().vm.$emit('view-exclusion', { id: 1 });
        expect(openMock).toHaveBeenCalledWith(DRAWER_MODES.VIEW, { id: 1 });
      });
    });
  });
});
