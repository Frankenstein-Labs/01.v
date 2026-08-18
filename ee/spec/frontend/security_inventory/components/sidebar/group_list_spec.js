import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlIntersectionObserver, GlEmptyState } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockClient } from 'helpers/mock_apollo_helper';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import waitForPromises from 'helpers/wait_for_promises';
import SubgroupsQuery from 'ee/security_inventory/graphql/subgroups.query.graphql';
import GroupList from 'ee/security_inventory/components/sidebar/group_list.vue';
import ExpandableGroup from 'ee/security_inventory/components/sidebar/expandable_group.vue';
import { groupWithSubgroups, groupWithoutSubgroups } from '../../mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

const defaultFullPath = 'a-group';

describe('GroupList', () => {
  let wrapper;

  const findSubgroupAt = (i) => wrapper.findAllComponents(ExpandableGroup).at(i);
  const findIntersectionObserver = () => wrapper.findComponent(GlIntersectionObserver);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);

  const createComponent = async ({
    groupFullPath = defaultFullPath,
    activeFullPath = defaultFullPath,
    indentation = 0,
    search = '',
    queryHandler = jest.fn().mockResolvedValue(groupWithSubgroups),
  } = {}) => {
    const mockDefaultClient = createMockClient();
    const mockAppendGroupsClient = createMockClient(
      [[SubgroupsQuery, queryHandler]],
      {},
      { typePolicies: { Query: { fields: { group: { merge: true } } } } },
    );
    wrapper = shallowMountExtended(GroupList, {
      apolloProvider: new VueApollo({
        clients: {
          appendGroupsClient: mockAppendGroupsClient,
        },
        defaultClient: mockDefaultClient,
      }),
      propsData: {
        groupFullPath,
        activeFullPath,
        indentation,
        search,
      },
    });
    await waitForPromises();
  };

  it('with no subgroups, shows empty state', async () => {
    await createComponent({
      queryHandler: jest.fn().mockResolvedValue(groupWithoutSubgroups),
    });

    expect(findEmptyState().text()).toContain('No subgroups found');
  });

  it('shows an expandable group for each subgroup of the main group', async () => {
    await createComponent();

    expect(findSubgroupAt(0).props()).toMatchObject({
      group: {
        fullPath: 'a-group/subgroup-with-projects-and-subgroups',
      },
    });
    expect(findSubgroupAt(1).props()).toMatchObject({
      group: {
        fullPath: 'a-group/subgroup-with-projects',
      },
    });
    expect(findSubgroupAt(2).props()).toMatchObject({
      group: {
        fullPath: 'a-group/subgroup-with-subgroups',
      },
    });
    expect(findSubgroupAt(3).props()).toMatchObject({
      group: {
        fullPath: 'a-group/empty-subgroup',
      },
    });
  });

  it('loads the next page of subgroups when scrolled to the bottom', async () => {
    const queryHandler = jest.fn().mockResolvedValue(groupWithSubgroups);

    await createComponent({ queryHandler });

    expect(queryHandler).toHaveBeenNthCalledWith(
      1,
      expect.objectContaining({ fullPath: 'a-group' }),
    );

    await findIntersectionObserver().vm.$emit('appear');

    expect(queryHandler).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        fullPath: 'a-group',
        after: 'END_CURSOR',
      }),
    );
  });

  it('shows an alert and reports to sentry on error', async () => {
    jest.spyOn(Sentry, 'captureException');
    const queryHandler = jest.fn().mockRejectedValue(new Error('Error'));

    await createComponent({ queryHandler });

    expect(createAlert).toHaveBeenCalledWith(
      expect.objectContaining({
        message: 'An error occurred while fetching subgroups. Please try again.',
      }),
    );
    expect(Sentry.captureException).toHaveBeenCalledWith(new Error('Error'));
  });

  describe('search', () => {
    let queryHandler;

    beforeEach(() => {
      queryHandler = jest.fn().mockResolvedValue(groupWithSubgroups);
    });

    it('sets the search term correctly', async () => {
      const searchTerm = 'group A';

      await createComponent({ queryHandler, search: searchTerm });

      expect(queryHandler).toHaveBeenCalledWith({
        fullPath: defaultFullPath,
        search: searchTerm,
        hasSearch: true,
      });
    });

    it('updates the query when the search term changes', async () => {
      const searchTermInitial = 'group A';
      const searchTermUpdated = 'group B';

      await createComponent({ queryHandler, search: searchTermInitial });

      wrapper.setProps({ search: searchTermUpdated });
      await waitForPromises();

      expect(queryHandler).toHaveBeenCalledWith(
        expect.objectContaining({ search: searchTermUpdated }),
      );
    });

    it('replaces short search term (less than 3 characters) with empty string', async () => {
      const searchTerm = 'gr';

      await createComponent({ queryHandler, search: searchTerm });

      expect(queryHandler).toHaveBeenCalledWith({
        fullPath: defaultFullPath,
        hasSearch: false,
        search: '',
      });
    });

    it('passes correct prop to expandable group', async () => {
      const searchTerm = 'group A';

      await createComponent({ queryHandler, search: searchTerm });

      expect(findSubgroupAt(0).props()).toMatchObject({
        hasSearch: true,
      });
    });
  });
});
