import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import organizationsGraphQlResponse from 'test_fixtures/graphql/organizations/organizations.query.graphql.json';
import organizationsQuery from '~/organizations/shared/graphql/queries/organizations.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import GeoSiteFormOrganizations from 'ee/geo_site_form/components/geo_site_form_organizations.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { SELECTIVE_SYNC_ORGANIZATIONS } from 'ee/geo_site_form/constants';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('GeoSiteFormOrganizations', () => {
  let wrapper;
  let mockHandler;
  let mockApollo;

  const {
    data: { organizations },
  } = organizationsGraphQlResponse;

  const defaultProps = {
    selectedOrganizationIds: [getIdFromGraphQLId(organizations.nodes[0].id)],
  };

  const createMockResponse = ({ nodes, pageInfo = {} } = {}) => {
    return {
      data: {
        organizations: {
          nodes: nodes ?? organizations.nodes,
          pageInfo: { ...organizations.pageInfo, ...pageInfo },
        },
      },
    };
  };

  const responseWithoutNextPage = createMockResponse({ pageInfo: { hasNextPage: false } });
  const responseWithNextPage = createMockResponse({
    pageInfo: { hasNextPage: true, endCursor: 'cursor' },
  });

  const createComponent = ({
    handler = jest.fn().mockResolvedValue(responseWithoutNextPage),
    props = {},
  } = {}) => {
    mockApollo = createMockApollo([[organizationsQuery, handler]]);
    mockHandler = handler;

    wrapper = shallowMount(GeoSiteFormOrganizations, {
      apolloProvider: mockApollo,
      propsData: { ...defaultProps, ...props },
    });
  };

  const findGlCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  it('renders listbox with correct props', () => {
    createComponent();

    expect(findGlCollapsibleListbox().props()).toMatchObject({
      items: [],
      selected: defaultProps.selectedOrganizationIds,
      searching: true,
      infiniteScrollLoading: false,
      noResultsText: 'Nothing found…',
      toggleText: '1 organization selected',
      multiple: true,
      infiniteScroll: true,
      searchable: true,
      headerText: 'Select organizations',
      resetButtonLabel: 'Clear all',
    });
  });

  it('make organizations API call', () => {
    createComponent();

    expect(mockHandler).toHaveBeenCalledWith({ search: '' });
  });

  describe('when organizations API call is successful', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('loads organizations as listbox option', () => {
      const expectedItems = organizations.nodes.map((node) => ({
        text: node.name,
        value: getIdFromGraphQLId(node.id),
      }));

      expect(findGlCollapsibleListbox().props('items')).toEqual(expectedItems);
      expect(findGlCollapsibleListbox().props('searching')).toBe(false);
    });

    it('stops loading state', () => {
      expect(findGlCollapsibleListbox().props('searching')).toBe(false);
      expect(findGlCollapsibleListbox().props('infiniteScrollLoading')).toBe(false);
    });
  });

  describe('when organizations API call fails', () => {
    const error = new Error();

    beforeEach(async () => {
      createComponent({ handler: jest.fn().mockRejectedValue(error) });
      await waitForPromises();
    });

    it('does not update listbox option', () => {
      expect(findGlCollapsibleListbox().props('items')).toEqual([]);
      expect(findGlCollapsibleListbox().props('searching')).toBe(false);
    });

    it('renders error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: "There was an error fetching the Site's Organizations",
        error,
        captureError: true,
      });
    });

    it('stops loading state', () => {
      expect(findGlCollapsibleListbox().props('searching')).toBe(false);
      expect(findGlCollapsibleListbox().props('infiniteScrollLoading')).toBe(false);
    });
  });

  describe.each`
    selectedItems | dropdownTitle
    ${0}          | ${'Select organizations to replicate'}
    ${1}          | ${'1 organization selected'}
    ${3}          | ${'3 organizations selected'}
  `('when $selectedItems organizations are selected', ({ selectedItems, dropdownTitle }) => {
    beforeEach(() => {
      const selectedOrganizationIds = organizations.nodes
        .slice(0, selectedItems)
        .map((node) => getIdFromGraphQLId(node.id));

      createComponent({ props: { selectedOrganizationIds } });
    });

    it(`displays "${dropdownTitle}"`, () => {
      expect(findGlCollapsibleListbox().props('toggleText')).toBe(dropdownTitle);
    });
  });

  describe('when listbox emits `search` event', () => {
    it('refetches organizations with search term', async () => {
      createComponent();

      findGlCollapsibleListbox().vm.$emit('search', 'searchTerm');
      await waitForPromises();

      expect(mockHandler).toHaveBeenCalledWith({ search: 'searchTerm' });
    });
  });

  describe('when listbox emits `select` event', () => {
    beforeEach(() => {
      createComponent();

      findGlCollapsibleListbox().vm.$emit('select', 1);
    });

    it('emits `update-sync-options`', () => {
      expect(wrapper.emitted('update-sync-options')).toEqual([
        [{ key: SELECTIVE_SYNC_ORGANIZATIONS, value: 1 }],
      ]);
    });
  });

  describe('when listbox emits `reset` event', () => {
    beforeEach(() => {
      createComponent();

      findGlCollapsibleListbox().vm.$emit('reset');
    });

    it('emits `update-sync-options` with empty array', () => {
      expect(wrapper.emitted('update-sync-options')).toEqual([
        [{ key: SELECTIVE_SYNC_ORGANIZATIONS, value: [] }],
      ]);
    });
  });

  describe('when listbox emits `bottom-reached` event', () => {
    describe('when has no next page', () => {
      beforeEach(async () => {
        createComponent({ handler: jest.fn().mockResolvedValue(responseWithoutNextPage) });

        await waitForPromises();
        mockHandler.mockClear();

        findGlCollapsibleListbox().vm.$emit('bottom-reached');
      });

      it('does not fetch more organizations', async () => {
        await waitForPromises();

        expect(mockHandler).not.toHaveBeenCalled();
      });

      it('does not start loading state', () => {
        expect(findGlCollapsibleListbox().props('searching')).toBe(false);
        expect(findGlCollapsibleListbox().props('infiniteScrollLoading')).toBe(false);
      });
    });

    describe('when has next page', () => {
      beforeEach(async () => {
        createComponent({ handler: jest.fn().mockResolvedValue(responseWithNextPage) });

        findGlCollapsibleListbox().vm.$emit('search', 'searchTerm');
        await waitForPromises();

        findGlCollapsibleListbox().vm.$emit('bottom-reached');
      });

      it('starts loading state', () => {
        expect(findGlCollapsibleListbox().props('infiniteScrollLoading')).toBe(true);
        expect(findGlCollapsibleListbox().props('searching')).toBe(false);
      });

      describe('when loading succeeds', () => {
        beforeEach(async () => {
          await waitForPromises();
        });

        it('fetches more organizations', () => {
          expect(mockHandler).toHaveBeenCalledWith({
            search: 'searchTerm',
            after: 'cursor',
          });
        });

        it('stops loading state', () => {
          expect(findGlCollapsibleListbox().props('searching')).toBe(false);
          expect(findGlCollapsibleListbox().props('infiniteScrollLoading')).toBe(false);
        });
      });
    });
  });
});
