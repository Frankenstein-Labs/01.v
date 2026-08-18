import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlLoadingIcon, GlAlert } from '@gitlab/ui';
import { cloneDeep } from 'lodash-es';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import App from 'ee/analytics/contribution_analytics/components/app.vue';
import GroupMembersTable from 'ee/analytics/contribution_analytics/components/group_members_table.vue';
import contributionsQuery from 'ee/analytics/contribution_analytics/graphql/contributions.query.graphql';
import { contributionAnalyticsFixture } from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('Contribution Analytics App', () => {
  let wrapper;

  const mockApiResponse = ({ response = contributionAnalyticsFixture, endCursor = '' } = {}) => {
    const responseCopy = cloneDeep(response);

    responseCopy.data.group.contributions.pageInfo = {
      endCursor,
      hasNextPage: endCursor !== '',
    };

    return responseCopy;
  };

  const createWrapper = ({ contributionsQueryResolver, props = {} }) => {
    const apolloProvider = createMockApollo(
      [[contributionsQuery, contributionsQueryResolver]],
      {},
      { typePolicies: { Query: { fields: { group: { merge: false } } } } },
    );

    wrapper = shallowMount(App, {
      apolloProvider,
      propsData: {
        fullPath: 'test',
        startDate: '2000-12-10',
        endDate: '2000-12-31',
        dataSourceClickhouse: false,
        ...props,
      },
    });
  };

  const nextPageCursor = 'next';

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findErrorAlert = () => wrapper.findComponent(GlAlert);
  const findGroupMembersTable = () => wrapper.findComponent(GroupMembersTable);

  const expectGroupMembersTableToHaveData = () =>
    expect(findGroupMembersTable().props('contributions')).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          user: expect.objectContaining({
            id: expect.any(String),
            webUrl: expect.any(String),
          }),
        }),
      ]),
    );

  const expectContributionsQueryResolverCalls = (resolver, results) => {
    expect(resolver).toHaveBeenCalledTimes(results.length);
    results.forEach((result) =>
      expect(resolver).toHaveBeenCalledWith({
        fullPath: wrapper.props('fullPath'),
        ...result,
      }),
    );
  };

  it('renders the loading spinner when the request is pending', async () => {
    const contributionsQueryResolver = jest.fn().mockResolvedValue({ data: null });
    createWrapper({ contributionsQueryResolver });

    expect(findLoadingIcon().exists()).toBe(true);
    await waitForPromises();
    expect(findLoadingIcon().exists()).toBe(false);
  });

  it('renders the error alert if the request fails', async () => {
    const contributionsQueryResolver = jest.fn().mockResolvedValue({ data: null });
    createWrapper({ contributionsQueryResolver });
    await waitForPromises();

    expect(Sentry.captureException).toHaveBeenCalled();
    expect(findErrorAlert().exists()).toBe(true);
    expect(findErrorAlert().text()).toEqual(wrapper.vm.$options.i18n.error);
  });

  it('fetches Clickhouse data, using paginated requests when necessary', async () => {
    const contributionsQueryResolver = jest
      .fn()
      .mockResolvedValueOnce(mockApiResponse({ endCursor: nextPageCursor }))
      .mockResolvedValueOnce(mockApiResponse());

    createWrapper({ contributionsQueryResolver, props: { dataSourceClickhouse: true } });
    await waitForPromises();

    expectGroupMembersTableToHaveData();

    expectContributionsQueryResolverCalls(contributionsQueryResolver, [
      {
        startDate: '2000-12-10',
        endDate: '2000-12-31',
        nextPageCursor: '',
      },
      {
        startDate: '2000-12-10',
        endDate: '2000-12-31',
        nextPageCursor,
      },
    ]);
  });

  it('fetches PostgresQL data per week, using paginated requests when necessary', async () => {
    const contributionsQueryResolver = jest
      .fn()
      .mockResolvedValueOnce(mockApiResponse({ endCursor: nextPageCursor }))
      .mockResolvedValueOnce(mockApiResponse())
      .mockResolvedValueOnce(mockApiResponse())
      .mockResolvedValueOnce(mockApiResponse({ endCursor: nextPageCursor }))
      .mockResolvedValueOnce(mockApiResponse());

    createWrapper({ contributionsQueryResolver });
    await waitForPromises();

    expectGroupMembersTableToHaveData();
    expectContributionsQueryResolverCalls(contributionsQueryResolver, [
      {
        startDate: '2000-12-10',
        endDate: '2000-12-17',
        nextPageCursor: '',
      },
      {
        startDate: '2000-12-10',
        endDate: '2000-12-17',
        nextPageCursor,
      },
      {
        startDate: '2000-12-18',
        endDate: '2000-12-25',
        nextPageCursor: '',
      },
      {
        startDate: '2000-12-26',
        endDate: '2000-12-31',
        nextPageCursor: '',
      },
      {
        startDate: '2000-12-26',
        endDate: '2000-12-31',
        nextPageCursor,
      },
    ]);
  });
});
