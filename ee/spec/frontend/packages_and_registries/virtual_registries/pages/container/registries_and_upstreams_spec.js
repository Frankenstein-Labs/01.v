import { GlTabs, GlTab, GlButton } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import getUpstreamsQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_container_upstreams.query.graphql';
import getUpstreamsCountQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_container_upstreams_count.query.graphql';
import CleanupPolicyStatus from 'ee/packages_and_registries/virtual_registries/components/cleanup_policy_status.vue';
import ContainerRegistriesAndUpstreams from 'ee/packages_and_registries/virtual_registries/pages/container/registries_and_upstreams.vue';
import RegistriesList from 'ee/packages_and_registries/virtual_registries/components/common/registries/list.vue';
import {
  CONTAINER_REGISTRIES_INDEX,
  CONTAINER_UPSTREAMS_INDEX,
} from 'ee/packages_and_registries/virtual_registries/pages/container/routes';
import UpstreamsList from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/list.vue';
import ContainerI18n from 'ee/packages_and_registries/virtual_registries/pages/container/i18n';
import {
  groupContainerUpstreams,
  groupContainerUpstreamsCount,
} from 'ee_jest/packages_and_registries/virtual_registries/mock_data';

Vue.use(VueApollo);

describe('ContainerRegistriesAndUpstreams', () => {
  let wrapper;
  let mockRouter;

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findButton = () => wrapper.findComponent(GlButton);
  const findCleanupPolicyStatus = () => wrapper.findComponent(CleanupPolicyStatus);
  const findTabs = () => wrapper.findComponent(GlTabs);
  const findAllTabs = () => wrapper.findAllComponents(GlTab);
  const findRegistriesTab = () => findAllTabs().at(0);
  const findUpstreamsTab = () => findAllTabs().at(1);
  const findRegistriesList = () => wrapper.findComponent(RegistriesList);
  const findUpstreamsList = () => wrapper.findComponent(UpstreamsList);

  const createComponent = ({ route = { name: CONTAINER_REGISTRIES_INDEX }, provide = {} } = {}) => {
    mockRouter = {
      push: jest.fn(),
      resolve: jest.fn().mockReturnValue({ href: '/' }),
    };

    wrapper = shallowMountExtended(ContainerRegistriesAndUpstreams, {
      apolloProvider: createMockApollo([
        [getUpstreamsQuery, jest.fn().mockResolvedValue({ data: { ...groupContainerUpstreams } })],
        [
          getUpstreamsCountQuery,
          jest.fn().mockResolvedValue({ data: { ...groupContainerUpstreamsCount } }),
        ],
      ]),
      provide: {
        i18n: ContainerI18n,
        getUpstreamsQuery,
        getUpstreamsCountQuery,
        fullPath: 'gitlab-org',
        glAbilities: {
          createVirtualRegistry: true,
        },
        maxRegistriesCount: 5,
        ...provide,
      },
      mocks: {
        $router: mockRouter,
        $route: route,
      },
    });
  };

  beforeEach(async () => {
    createComponent();

    await waitForPromises();
  });

  describe('rendering', () => {
    it('renders the page heading', () => {
      expect(findPageHeading().props('heading')).toBe('Container virtual registries');
    });

    describe('page heading', () => {
      it('renders the page heading', () => {
        expect(findPageHeading().text()).toBe(
          'You can add up to 5 registries per top-level group.',
        );
      });
    });

    describe('when user does not have permission', () => {
      beforeEach(async () => {
        createComponent({
          provide: {
            glAbilities: {
              createVirtualRegistry: false,
            },
          },
        });

        await waitForPromises();
        await findRegistriesList().vm.$emit('update-count', 2);
      });

      it('does not render create registry button', () => {
        expect(findButton().exists()).toBe(false);
        expect(findPageHeading().text()).not.toContain('Maximum number of registries reached.');
      });
    });

    describe('when maxRegistriesCount limit has been reached', () => {
      beforeEach(async () => {
        await findRegistriesList().vm.$emit('update-count', 5);
      });

      it('does not render create registry button', () => {
        expect(findButton().exists()).toBe(false);
        expect(findPageHeading().text()).toContain('Maximum number of registries reached.');
      });
    });

    it('renders the cleanup policy status component', () => {
      expect(findCleanupPolicyStatus().exists()).toBe(true);
    });

    it('renders tabs component', () => {
      expect(findTabs().exists()).toBe(true);
    });

    it('renders registries and upstreams tabs', () => {
      expect(findAllTabs()).toHaveLength(2);
    });
  });

  describe('registries tab', () => {
    it('has correct title', () => {
      expect(findRegistriesTab().attributes('title')).toBe('Registries');
      expect(findRegistriesTab().props()).toMatchObject({
        tabCount: null,
        tabCountSrText: '',
      });
    });

    it('is active when on registries route', () => {
      expect(findRegistriesTab().attributes('active')).toBe('true');
    });

    it('is not active when on upstreams route', () => {
      createComponent({ route: { name: CONTAINER_UPSTREAMS_INDEX } });

      expect(findRegistriesTab().attributes('active')).not.toBeDefined();
    });

    it('renders RegistriesList component', () => {
      expect(findRegistriesList().exists()).toBe(true);
    });

    it('navigates to registries index on click', async () => {
      await findRegistriesTab().vm.$emit('click');

      expect(mockRouter.push).toHaveBeenCalledWith({ name: CONTAINER_REGISTRIES_INDEX });
    });

    describe('when RegistriesList emits `update-count` event', () => {
      beforeEach(() => {
        findRegistriesList().vm.$emit('update-count', 2);
      });

      it('renders registries count', () => {
        expect(findRegistriesTab().props()).toMatchObject({
          tabCount: 2,
          tabCountSrText: '2 registries',
        });
      });

      it('renders create registry button if user has permission', () => {
        expect(findButton().text()).toBe('Create registry');
        expect(findButton().props('to')).toStrictEqual({ name: 'REGISTRY_NEW' });
        expect(findPageHeading().text()).not.toContain('Maximum number of registries reached.');
      });
    });
  });

  describe('upstreams tab', () => {
    it('has correct title', () => {
      expect(findUpstreamsTab().attributes('title')).toBe('Upstreams');
    });

    it('is not active when on registries route', () => {
      expect(findUpstreamsTab().attributes('active')).not.toBeDefined();
    });

    it('is active when on upstreams route', () => {
      createComponent({ route: { name: CONTAINER_UPSTREAMS_INDEX } });

      expect(findUpstreamsTab().attributes('active')).toBe('true');
    });

    it('navigates to upstreams index on click', async () => {
      await findUpstreamsTab().vm.$emit('click');

      expect(mockRouter.push).toHaveBeenCalledWith({ name: CONTAINER_UPSTREAMS_INDEX });
    });

    it('renders upstreams list', () => {
      expect(findUpstreamsList().exists()).toBe(true);
      expect(findUpstreamsList().props('upstreams')).toEqual(
        expect.objectContaining({
          nodes: groupContainerUpstreams.group.upstreams.nodes,
        }),
      );
    });
  });
});
