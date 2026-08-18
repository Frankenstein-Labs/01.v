import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlEmptyState } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import EnvironmentsIndex from 'ee/cd/components/environments_index.vue';
import EnvironmentList from 'ee/cd/components/environment_list.vue';
import NewEnvironmentPanel from 'ee/cd/components/new_environment_panel.vue';
import FilterBar from 'ee/cd/components/shared/filter_bar.vue';
import cdEnvironmentsQuery from 'ee/cd/graphql/cd_environments.query.graphql';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import {
  buildEnvironmentsQueryResponse,
  mockCdEnvironments,
  mockCdEnvironmentsNextPage,
} from './mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('EnvironmentsIndex', () => {
  let wrapper;

  const pageSize = 50;
  const endCursor = 'end-cursor';

  let queryHandler;

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findFilterBar = () => wrapper.findComponent(FilterBar);
  const findEnvironmentList = () => wrapper.findComponent(EnvironmentList);
  const findRegisterButton = () => wrapper.findComponentByTestId('register-environment-button');
  const findNewEnvironmentPanel = () => wrapper.findComponent(NewEnvironmentPanel);
  const findPageLoader = () => wrapper.findComponentByTestId('page-loader');
  const findFilterEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findClearFiltersButton = () => wrapper.findComponentByTestId('clear-filters-button');

  const createComponent = ({ handler } = {}) => {
    queryHandler = handler ?? jest.fn().mockResolvedValue(buildEnvironmentsQueryResponse());

    wrapper = shallowMountExtended(EnvironmentsIndex, {
      apolloProvider: createMockApollo([[cdEnvironmentsQuery, queryHandler]]),
    });
  };

  beforeEach(async () => {
    createComponent();
    await waitForPromises();
  });

  describe('page heading', () => {
    it('renders the Environments title', () => {
      expect(findPageHeading().props('heading')).toBe('Environments');
    });

    it('renders the Register environment button', () => {
      const button = findRegisterButton();

      expect(button.text()).toBe('Register environment');
      expect(button.props('variant')).toBe('confirm');
    });
  });

  describe('filter bar', () => {
    it('passes the environment tier filters to the filter bar', () => {
      expect(findFilterBar().props('filters')).toEqual([
        { id: 'ALL', text: 'All types' },
        { id: 'DEVELOPMENT', text: 'Development' },
        { id: 'QA', text: 'QA' },
        { id: 'STAGING', text: 'Staging' },
        { id: 'PRODUCTION', text: 'Production' },
      ]);
    });
  });

  describe('loading state', () => {
    it('renders the large page loader while the first load is in flight', () => {
      createComponent();

      expect(findPageLoader().props('size')).toBe('lg');
      expect(findEnvironmentList().exists()).toBe(false);
    });

    it('hides the page loader and stops the list loading once the first load resolves', () => {
      expect(findPageLoader().exists()).toBe(false);
      expect(findEnvironmentList().props('loading')).toBe(false);
    });

    describe.each([
      ['a tier filter', 'filter-selected', 'PRODUCTION'],
      ['a search', 'search', 'prod'],
    ])('when %s is in progress', (_, event, payload) => {
      beforeEach(async () => {
        // The second call never resolves, so the filtering stays in flight and
        // the loading state it triggers is observable.
        createComponent({
          handler: jest
            .fn()
            .mockResolvedValueOnce(buildEnvironmentsQueryResponse())
            .mockReturnValueOnce(new Promise(() => {})),
        });
        await waitForPromises();

        findFilterBar().vm.$emit(event, payload);
        await waitForPromises();
      });

      it('puts the list in a loading state and does not render the page loader', () => {
        expect(findEnvironmentList().props('loading')).toBe(true);
        expect(findPageLoader().exists()).toBe(false);
      });

      it('keeps the filter bar interactive', () => {
        expect(findFilterBar().exists()).toBe(true);
      });
    });
  });

  describe('query variables', () => {
    it('requests the first page of every environment on the first load', () => {
      expect(queryHandler).toHaveBeenCalledWith({ search: '', tier: null, first: pageSize });
    });

    describe('when the user searches', () => {
      beforeEach(async () => {
        findFilterBar().vm.$emit('search', '  prod  ');
        await waitForPromises();
      });

      it('passes the trimmed search term', () => {
        expect(queryHandler).toHaveBeenLastCalledWith({
          search: 'prod',
          tier: null,
          first: pageSize,
        });
      });
    });

    describe('when the user selects a tier', () => {
      beforeEach(async () => {
        findFilterBar().vm.$emit('filter-selected', 'STAGING');
        await waitForPromises();
      });

      it('passes the selected tier', () => {
        expect(queryHandler).toHaveBeenLastCalledWith({
          search: '',
          tier: 'STAGING',
          first: pageSize,
        });
      });

      describe('when the user selects all types again', () => {
        beforeEach(async () => {
          findFilterBar().vm.$emit('search', 'prod');
          findFilterBar().vm.$emit('filter-selected', 'ALL');
          await waitForPromises();
        });

        it('passes no tier', () => {
          expect(findFilterBar().props('selectedFilterId')).toBe('ALL');
          expect(queryHandler).toHaveBeenLastCalledWith({
            search: 'prod',
            tier: null,
            first: pageSize,
          });
        });
      });
    });
  });

  describe('when the filters match no environments', () => {
    beforeEach(async () => {
      findFilterBar().vm.$emit('search', 'no-such-environment');
      await waitForPromises();
    });

    it('renders the no results empty state instead of the list', () => {
      expect(findFilterEmptyState().props('title')).toBe('No environments match your filters');
      expect(findEnvironmentList().exists()).toBe(false);
    });

    describe('when the clear filters button is clicked', () => {
      beforeEach(async () => {
        findClearFiltersButton().vm.$emit('click');
        await waitForPromises();
      });

      it('clears the search term', () => {
        expect(findFilterBar().props('searchTerm')).toBe('');
      });

      it('renders the list again', () => {
        expect(findEnvironmentList().exists()).toBe(true);
      });
    });
  });

  describe('when there are no environments', () => {
    it('renders the list with no environments', () => {
      expect(findEnvironmentList().props('environments')).toEqual([]);
    });
  });

  describe('when the query returns environments', () => {
    beforeEach(async () => {
      createComponent({
        handler: jest.fn().mockResolvedValue(buildEnvironmentsQueryResponse(mockCdEnvironments)),
      });
      await waitForPromises();
    });

    it('passes the environments to the list', () => {
      expect(findEnvironmentList().props('environments')).toHaveLength(2);
      expect(findEnvironmentList().props('environments')).toMatchObject([
        { name: 'prod-eu-west-1' },
        { name: 'staging-us-east-1' },
      ]);
    });

    it('tells the list there is no next page', () => {
      expect(findEnvironmentList().props('hasNextPage')).toBe(false);
    });
  });

  describe('pagination', () => {
    const createComponentWithNextPage = async ({ nextPageHandler } = {}) => {
      createComponent({
        handler: jest
          .fn()
          .mockResolvedValueOnce(
            buildEnvironmentsQueryResponse(mockCdEnvironments, { hasNextPage: true, endCursor }),
          )
          .mockImplementationOnce(
            nextPageHandler ??
              (() => Promise.resolve(buildEnvironmentsQueryResponse(mockCdEnvironmentsNextPage))),
          ),
      });
      await waitForPromises();
    };

    describe('when there is a next page', () => {
      beforeEach(() => createComponentWithNextPage());

      it('tells the list there is a next page', () => {
        expect(findEnvironmentList().props('hasNextPage')).toBe(true);
        expect(findEnvironmentList().props('loadingMore')).toBe(false);
      });

      describe('when the list requests more environments', () => {
        beforeEach(async () => {
          findEnvironmentList().vm.$emit('load-more');
          await waitForPromises();
        });

        it('requests the next page from the last cursor', () => {
          expect(queryHandler).toHaveBeenLastCalledWith({
            search: '',
            tier: null,
            first: pageSize,
            after: endCursor,
          });
        });

        it('appends the next page to the environments already on screen', () => {
          expect(findEnvironmentList().props('environments')).toMatchObject([
            { name: 'prod-eu-west-1' },
            { name: 'staging-us-east-1' },
            { name: 'qa-eu-west-2' },
          ]);
        });

        it('tells the list there are no more pages', () => {
          expect(findEnvironmentList().props('hasNextPage')).toBe(false);
          expect(findEnvironmentList().props('loadingMore')).toBe(false);
        });
      });

      describe('while the next page is in flight', () => {
        beforeEach(async () => {
          await createComponentWithNextPage({ nextPageHandler: () => new Promise(() => {}) });

          findEnvironmentList().vm.$emit('load-more');
          await waitForPromises();
        });

        it('keeps the loaded environments on screen and marks the list as loading more', () => {
          expect(findEnvironmentList().props('loadingMore')).toBe(true);
          expect(findEnvironmentList().props('loading')).toBe(false);
          expect(findEnvironmentList().props('environments')).toHaveLength(2);
        });

        describe('when the list requests more environments again', () => {
          beforeEach(async () => {
            findEnvironmentList().vm.$emit('load-more');
            await waitForPromises();
          });

          it('does not request the same page twice', () => {
            expect(queryHandler).toHaveBeenCalledTimes(2);
          });
        });
      });
    });

    describe('when loading the next page fails', () => {
      beforeEach(async () => {
        await createComponentWithNextPage({
          nextPageHandler: () => Promise.reject(new Error('GraphQL error')),
        });

        findEnvironmentList().vm.$emit('load-more');
        await waitForPromises();
      });

      it('reports the exception to Sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
      });

      it('stops the loading state and keeps the loaded environments', () => {
        expect(findEnvironmentList().props('loadingMore')).toBe(false);
        expect(findEnvironmentList().props('environments')).toHaveLength(2);
      });
    });
  });

  describe('when the environments query fails', () => {
    beforeEach(async () => {
      createComponent({ handler: jest.fn().mockRejectedValue(new Error('GraphQL error')) });
      await waitForPromises();
    });

    it('reports the exception to Sentry', () => {
      expect(Sentry.captureException).toHaveBeenCalledWith(new Error('GraphQL error'));
    });

    it('renders the list with no environments', () => {
      expect(findEnvironmentList().props('environments')).toEqual([]);
    });
  });

  describe('register environment panel', () => {
    it('renders the panel closed by default', () => {
      expect(findNewEnvironmentPanel().props('open')).toBe(false);
    });

    describe('when the register button is clicked', () => {
      beforeEach(async () => {
        await findRegisterButton().vm.$emit('click');
      });

      it('opens the panel', () => {
        expect(findNewEnvironmentPanel().props('open')).toBe(true);
      });

      describe('when the panel emits close', () => {
        beforeEach(async () => {
          await findNewEnvironmentPanel().vm.$emit('close');
        });

        it('closes the panel', () => {
          expect(findNewEnvironmentPanel().props('open')).toBe(false);
        });
      });
    });

    it('passes the active query variables so the panel writes to the right cache entry', async () => {
      findFilterBar().vm.$emit('filter-selected', 'STAGING');
      await waitForPromises();

      expect(findNewEnvironmentPanel().props('queryVariables')).toEqual({
        search: '',
        tier: 'STAGING',
        first: pageSize,
      });
    });

    describe('when the environment list emits register', () => {
      beforeEach(async () => {
        await findEnvironmentList().vm.$emit('register');
      });

      it('opens the panel', () => {
        expect(findNewEnvironmentPanel().props('open')).toBe(true);
      });
    });
  });
});
