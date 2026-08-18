import { GlButton, GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import ApplicationsIndex from 'ee/cd/components/applications_index.vue';
import ApplicationCard from 'ee/cd/components/application_card.vue';
import FilterBar from 'ee/cd/components/shared/filter_bar.vue';
import NewApplicationPanel from 'ee/cd/components/new_application_panel.vue';
import {
  STATUS_AWAITING_APPROVAL,
  STATUS_DEGRADED,
  STATUS_DEPLOYING,
  STATUS_HEALTHY,
} from 'ee/cd/constants';
import cdApplicationsQuery from 'ee/cd/graphql/cd_applications.query.graphql';

Vue.use(VueApollo);

describe('ApplicationsIndex', () => {
  let wrapper;

  const makeApplication = ({ id = '1', name = 'app-1', status = STATUS_HEALTHY } = {}) => ({
    id,
    name,
    description: 'description',
    lastDeployedAt: 'last deployed at',
    services: { count: 1 },
    status,
  });

  const buildQueryResponse = (applications) => ({
    data: {
      organization: {
        id: 'gid://gitlab/Organizations::Organization/1',
        cdApplications: {
          nodes: applications,
        },
      },
    },
  });

  const defaultQueryHandler = jest.fn().mockResolvedValue(buildQueryResponse([makeApplication()]));

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findNewApplicationButton = () => wrapper.findComponent(GlButton);
  const findApplicationCards = () => wrapper.findAllComponents(ApplicationCard);
  const findFilterBar = () => wrapper.findComponent(FilterBar);
  const findPanel = () => wrapper.findComponent(NewApplicationPanel);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);

  const createComponent = ({ queryHandler = defaultQueryHandler } = {}) => {
    wrapper = shallowMountExtended(ApplicationsIndex, {
      apolloProvider: createMockApollo([[cdApplicationsQuery, queryHandler]]),
    });
  };

  it('renders the page heading', () => {
    createComponent();

    expect(findPageHeading().props('heading')).toBe('Applications');
  });

  it('renders the New application button', () => {
    createComponent();

    expect(findNewApplicationButton().text()).toBe('New application');
    expect(findNewApplicationButton().props('variant')).toBe('confirm');
  });

  it('renders the applications list', async () => {
    createComponent();
    await waitForPromises();

    expect(findApplicationCards()).toHaveLength(1);
  });

  describe('FilterBar filter', () => {
    describe.each([STATUS_AWAITING_APPROVAL, STATUS_DEGRADED, STATUS_DEPLOYING, STATUS_HEALTHY])(
      'when selecting filter %s',
      (status) => {
        beforeEach(async () => {
          createComponent();

          await findFilterBar().vm.$emit('filter-selected', status);
        });

        it('makes a query to filter by %s', () => {
          expect(defaultQueryHandler).toHaveBeenLastCalledWith({ search: '', statuses: status });
        });
      },
    );
  });

  describe('FilterBar search', () => {
    let queryHandler;

    beforeEach(async () => {
      queryHandler = jest.fn().mockResolvedValue(buildQueryResponse([makeApplication()]));
      createComponent({ queryHandler });
      await waitForPromises();
    });

    it('passes the correct search placeholder to FilterBar', () => {
      expect(findFilterBar().props('searchPlaceholder')).toBe('Search by name or description');
    });

    describe('on initial load', () => {
      it('queries with an empty search variable', () => {
        expect(queryHandler).toHaveBeenCalledWith({ search: '', statuses: null });
      });
    });

    describe('when FilterBar emits search', () => {
      beforeEach(async () => {
        await findFilterBar().vm.$emit('search', 'my-app');
        await waitForPromises();
      });

      it('updates the searchTerm prop', () => {
        expect(findFilterBar().props('searchTerm')).toBe('my-app');
      });

      it('refetches the query with the search variable', () => {
        expect(queryHandler).toHaveBeenCalledWith({ search: 'my-app', statuses: null });
      });
    });

    describe('when FilterBar emits search with surrounding whitespace', () => {
      beforeEach(async () => {
        await findFilterBar().vm.$emit('search', '  my-app  ');
        await waitForPromises();
      });

      it('trims whitespace from the search variable', () => {
        expect(queryHandler).toHaveBeenCalledWith({ search: 'my-app', statuses: null });
      });
    });
  });

  describe('new application panel', () => {
    beforeEach(() => {
      createComponent();
    });

    it('is closed by default', () => {
      expect(findPanel().props('open')).toBe(false);
    });

    it('passes the organization id to the panel', async () => {
      await waitForPromises();

      expect(findPanel().props('organizationId')).toBe(
        'gid://gitlab/Organizations::Organization/1',
      );
    });

    it('opens when the "New application" button is clicked', async () => {
      await findNewApplicationButton().vm.$emit('click');

      expect(findPanel().props('open')).toBe(true);
    });

    it('closes when the panel emits close', async () => {
      await findNewApplicationButton().vm.$emit('click');

      expect(findPanel().props('open')).toBe(true);

      await findPanel().vm.$emit('close');

      expect(findPanel().props('open')).toBe(false);
    });

    it('refetches the applications when the panel emits create', async () => {
      const queryHandler = jest.fn().mockResolvedValue(buildQueryResponse([makeApplication()]));
      createComponent({ queryHandler });
      await waitForPromises();

      expect(queryHandler).toHaveBeenCalledTimes(1);

      await findPanel().vm.$emit('create');
      await waitForPromises();

      expect(queryHandler).toHaveBeenCalledTimes(2);
    });
  });

  describe('loading state', () => {
    it('shows a loading icon and hides the applications list while the query is pending', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findApplicationCards().exists()).toBe(false);
    });

    it('hides the loading icon once the query resolves', async () => {
      createComponent();
      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(false);
      expect(findApplicationCards().exists()).toBe(true);
    });
  });

  describe('empty states', () => {
    describe('when there are no applications and no filters are applied', () => {
      beforeEach(async () => {
        createComponent({ queryHandler: jest.fn().mockResolvedValue(buildQueryResponse([])) });
        await waitForPromises();
      });

      it('shows the "no applications yet" empty state instead of the applications list', () => {
        expect(findApplicationCards().exists()).toBe(false);
        expect(findEmptyState().props()).toMatchObject({
          illustrationName: 'empty-dashboard-md',
          title: 'No applications yet',
          description: 'Create applications to track them and deploy them to environments',
        });
      });

      it('opens the new application panel when the empty state action is clicked', async () => {
        await findEmptyState().findComponent(GlButton).vm.$emit('click');

        expect(findPanel().props('open')).toBe(true);
      });
    });

    describe('when a search term yields no results', () => {
      beforeEach(async () => {
        createComponent({ queryHandler: jest.fn().mockResolvedValue(buildQueryResponse([])) });
        await waitForPromises();

        await findFilterBar().vm.$emit('search', 'no-match');
        await waitForPromises();
      });

      it('shows the "no applications match your filters" empty state', () => {
        expect(findEmptyState().props()).toMatchObject({
          illustrationName: 'empty-search-md',
          title: 'No applications match your filters',
          description: 'To widen your search, change or remove filters above.',
        });
      });

      it('clears the search term and status filter when "Clear filters" is clicked', async () => {
        await findEmptyState().findComponent(GlButton).vm.$emit('click');

        expect(findFilterBar().props('searchTerm')).toBe('');
        expect(findFilterBar().props('selectedFilterId')).toBe(null);
      });
    });

    describe('when a status filter yields no results', () => {
      beforeEach(async () => {
        createComponent({ queryHandler: jest.fn().mockResolvedValue(buildQueryResponse([])) });

        await findFilterBar().vm.$emit('filter-selected', STATUS_DEGRADED);
        await waitForPromises();
      });

      it('shows the "no applications match your filters" empty state', () => {
        expect(findEmptyState().props('title')).toBe('No applications match your filters');
      });
    });
  });
});
