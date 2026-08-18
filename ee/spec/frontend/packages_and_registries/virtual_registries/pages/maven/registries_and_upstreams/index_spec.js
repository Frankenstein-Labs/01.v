import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlTab } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import getUpstreamsQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstreams.query.graphql';
import getUpstreamsCountQuery from 'ee/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstreams_count.query.graphql';
import MavenRegistriesAndUpstreamsApp from 'ee/packages_and_registries/virtual_registries/pages/maven/registries_and_upstreams/index.vue';
import RegistriesList from 'ee/packages_and_registries/virtual_registries/components/common/registries/list.vue';
import UpstreamsList from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/list.vue';
import CleanupPolicyStatus from 'ee/packages_and_registries/virtual_registries/components/cleanup_policy_status.vue';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import { groupMavenUpstreams, groupMavenUpstreamsCount } from '../../../mock_data';

jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils');

Vue.use(VueApollo);

describe('MavenRegistriesAndUpstreamsApp', () => {
  let wrapper;

  const defaultProvide = {
    fullPath: 'gitlab-org',
  };

  const mockError = new Error('GraphQL error');
  const mavenUpstreamsHandler = jest.fn().mockResolvedValue({ data: { ...groupMavenUpstreams } });
  const mavenUpstreamsCountHandler = jest
    .fn()
    .mockResolvedValue({ data: { ...groupMavenUpstreamsCount } });
  const errorHandler = jest.fn().mockRejectedValue(mockError);

  const createComponent = ({
    handlers = [
      [getUpstreamsQuery, mavenUpstreamsHandler],
      [getUpstreamsCountQuery, mavenUpstreamsCountHandler],
    ],
  } = {}) => {
    wrapper = shallowMountExtended(MavenRegistriesAndUpstreamsApp, {
      apolloProvider: createMockApollo(
        handlers,
        {},
        {
          typePolicies: {
            MavenUpstreamConnection: { merge: true },
          },
        },
      ),
      provide: {
        getUpstreamsQuery,
        getUpstreamsCountQuery,
        ...defaultProvide,
      },
      stubs: {
        GlTabs: true,
        UpstreamsList: stubComponent(UpstreamsList),
      },
    });
  };

  const findTabs = () => wrapper.findAllComponents(GlTab);
  const findRegistriesTab = () => findTabs().at(0);
  const findUpstreamsTab = () => findTabs().at(1);
  const findRegistriesList = () => wrapper.findComponent(RegistriesList);
  const findUpstreamsList = () => wrapper.findComponent(UpstreamsList);
  const findCleanupPolicyStatus = () => wrapper.findComponent(CleanupPolicyStatus);
  const findUserCalloutDismisser = () => wrapper.findComponent(UserCalloutDismisser);

  beforeEach(() => {
    createComponent();
  });

  it('renders registries tab', () => {
    expect(findRegistriesTab().attributes('title')).toBe('Registries');
    expect(findRegistriesTab().props()).toMatchObject({
      queryParamValue: 'registries',
      tabCount: null,
      tabCountSrText: '',
    });
  });

  it('renders upstreams tab', () => {
    expect(findUpstreamsTab().attributes('title')).toBe('Upstreams');
    expect(findUpstreamsTab().props()).toMatchObject({
      queryParamValue: 'upstreams',
      tabCount: null,
      tabCountSrText: '',
    });
  });

  it('renders RegistriesList component', () => {
    expect(findRegistriesList().exists()).toBe(true);
  });

  it('renders UpstreamsList component', () => {
    expect(findUpstreamsList().exists()).toBe(true);
  });

  it('renders CleanupPolicyStatus component', () => {
    expect(findCleanupPolicyStatus().exists()).toBe(true);
  });

  it('renders UserCalloutDismisser component', () => {
    expect(findUserCalloutDismisser().props('featureName')).toBe(
      'virtual_registry_permission_change_alert',
    );
  });

  describe('when RegistriesList emits `update-count` event', () => {
    beforeEach(() => {
      findRegistriesList().vm.$emit('update-count', 5);
    });

    it('renders registries count', () => {
      expect(findRegistriesTab().props()).toMatchObject({
        tabCount: 5,
        tabCountSrText: '5 registries',
      });
    });
  });

  describe('when UpstreamsList emits `submit` event with search term', () => {
    beforeEach(async () => {
      await findUpstreamsList().vm.$emit('submit', 'test');
    });

    it('sets searchTerm for UpstreamsList component', () => {
      expect(findUpstreamsList().props('searchTerm')).toBe('test');
    });

    it('calls upstreams count query with upstream name', () => {
      expect(mavenUpstreamsHandler).toHaveBeenCalledTimes(2);
      expect(mavenUpstreamsHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({
          groupPath: 'gitlab-org',
          upstreamName: 'test',
        }),
      );
    });
  });

  describe('when UpstreamsList emits `page-change` event with prev page params', () => {
    beforeEach(async () => {
      await findUpstreamsList().vm.$emit('page-change', { before: 'cursor' });
    });

    it('sets page params for MavenUpstreamsList component', () => {
      expect(mavenUpstreamsHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({
          before: 'cursor',
          last: 20,
        }),
      );
    });
  });

  describe('when upstreams count query returns response', () => {
    beforeEach(async () => {
      await waitForPromises();
    });

    it('renders upstreams count', () => {
      expect(findUpstreamsTab().props()).toMatchObject({
        tabCount: 5,
        tabCountSrText: '5 upstreams',
      });
    });
  });

  describe('when upstreams count query fails', () => {
    it('renders upstreams count', async () => {
      createComponent({
        handlers: [
          [getUpstreamsQuery, errorHandler],
          [getUpstreamsCountQuery, mavenUpstreamsCountHandler],
        ],
      });

      await waitForPromises();

      expect(captureException).toHaveBeenCalledWith({
        component: 'MavenVirtualRegistriesAndUpstreamsApp',
        error: mockError,
      });
    });
  });

  describe('when UpstreamsList emits `upstream-deleted` event', () => {
    it('refetches upstreams count query', async () => {
      createComponent();

      await findUpstreamsList().vm.$emit('upstream-deleted');

      expect(mavenUpstreamsHandler).toHaveBeenCalledTimes(2);
    });
  });
});
