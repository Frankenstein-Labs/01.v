import { GlDisclosureDropdown, GlModal } from '@gitlab/ui';
import { RouterLinkStub } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import IterationCadenceListItem from 'ee/iterations/components/iteration_cadence_list_item.vue';
import TimeboxStatusBadge from 'ee/iterations/components/timebox_status_badge.vue';
import { CADENCE_AND_DUE_DATE_DESC } from 'ee/iterations/constants';
import groupIterationsInCadenceQuery from 'ee/iterations/queries/group_iterations_in_cadence.query.graphql';
import projectIterationsInCadenceQuery from 'ee/iterations/queries/project_iterations_in_cadence.query.graphql';
import { getIterationPeriod } from 'ee/iterations/utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { NAMESPACE_GROUP, NAMESPACE_PROJECT } from '~/issues/constants';
import { automaticIterationCadence, nonEmptyGroupIterationsSuccess } from '../mock_data';

describe('IterationCadenceListItem component', () => {
  Vue.use(VueApollo);

  let wrapper;

  const fullPath = 'gitlab-org';
  const iterations = [
    {
      dueDate: '2021-08-14',
      id: 'gid://gitlab/Iteration/41',
      scopedPath: '/groups/group1/-/iterations/41',
      startDate: '2021-08-13',
      state: 'upcoming',
      title: 'My title 44',
      webPath: '/groups/group1/-/iterations/41',
      __typename: 'Iteration',
    },
    {
      id: 'gid://gitlab/Iteration/42',
      scopedPath: '/groups/group1/-/iterations/42',
      startDate: '2021-08-15',
      dueDate: '2021-08-20',
      state: 'upcoming',
      title: null,
      webPath: '/groups/group1/-/iterations/42',
      __typename: 'Iteration',
    },
  ];
  const startCursor = 'MQ';
  const endCursor = 'MjA';
  const querySuccessResponse = {
    data: {
      namespace: {
        id: '1',
        iterations: {
          nodes: iterations,
          pageInfo: {
            __typename: 'PageInfo',
            hasNextPage: true,
            hasPreviousPage: false,
            startCursor,
            endCursor,
          },
        },
      },
    },
  };
  const queryEmptyResponse = {
    data: {
      namespace: {
        id: '1',
        iterations: {
          nodes: [],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
          },
        },
      },
    },
  };

  const modalShowSpy = jest.fn();
  const querySuccessHandler = jest.fn().mockResolvedValue(querySuccessResponse);

  function createComponent({
    props = {},
    canCreateIteration,
    canEditCadence,
    currentRoute,
    namespaceType = NAMESPACE_GROUP,
    query = groupIterationsInCadenceQuery,
    queryHandler = querySuccessHandler,
  } = {}) {
    wrapper = mountExtended(IterationCadenceListItem, {
      apolloProvider: createMockApollo([[query, queryHandler]]),
      mocks: {
        $router: {
          push: jest.fn(),
          currentRoute,
        },
      },
      stubs: {
        GlModal: stubComponent(GlModal, {
          methods: {
            show: modalShowSpy,
          },
        }),
        RouterLink: RouterLinkStub,
        CrudComponent,
      },
      provide: {
        fullPath,
        canCreateIteration,
        canEditCadence,
        namespaceType,
      },
      propsData: {
        title: automaticIterationCadence.title,
        cadenceId: automaticIterationCadence.id,
        automatic: true,
        iterationState: 'opened',
        ...props,
      },
    });

    return nextTick();
  }

  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findDisclosureDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findAddIterationButton = () => wrapper.findByTestId('add-cadence');
  const findIterationItemText = (i) => wrapper.findAllByTestId('iteration-item').at(i).text();
  const findDurationBadge = () => wrapper.findByTestId('duration-badge');
  const expand = (cadence = automaticIterationCadence) =>
    wrapper.findByRole('button', { text: cadence.title }).trigger('click');

  it('does not query iterations when component mounted', async () => {
    await createComponent();

    expect(querySuccessHandler).not.toHaveBeenCalled();
  });

  it.each([
    {
      namespaceType: NAMESPACE_GROUP,
      query: groupIterationsInCadenceQuery,
      iterationState: 'closed',
    },
    {
      namespaceType: NAMESPACE_PROJECT,
      query: projectIterationsInCadenceQuery,
      iterationState: 'closed',
    },
    {
      namespaceType: NAMESPACE_GROUP,
      query: groupIterationsInCadenceQuery,
      iterationState: 'all',
    },
    {
      namespaceType: NAMESPACE_PROJECT,
      query: projectIterationsInCadenceQuery,
      iterationState: 'all',
    },
  ])('uses DESC sort order for $iterationState iterations on $namespaceType', async (params) => {
    const queryHandler = jest.fn().mockResolvedValue(queryEmptyResponse);
    await createComponent({
      queryHandler,
      props: {
        iterationState: params.iterationState,
      },
      query: params.query,
      namespaceType: params.namespaceType,
    });
    expand();
    await waitForPromises();

    expect(queryHandler).toHaveBeenCalledWith(
      expect.objectContaining({ sort: CADENCE_AND_DUE_DATE_DESC }),
    );
  });

  it.each`
    iterationState | text
    ${'opened'}    | ${'No open iterations.'}
    ${'closed'}    | ${'No closed iterations.'}
    ${'all'}       | ${'No iterations in cadence.'}
  `(
    'shows empty text when no results for list of %s iterations',
    async ({ iterationState, text }) => {
      await createComponent({
        queryHandler: jest.fn().mockResolvedValue(queryEmptyResponse),
        props: {
          iterationState,
        },
      });
      expand();
      await waitForPromises();

      expect(findCrudComponent().props('is-loading')).toBe(undefined);
      expect(wrapper.text()).toContain(text);
    },
  );

  it('hides Add iteration button for automatic cadence', async () => {
    await createComponent({
      canCreateIteration: true,
      canEditCadence: true,
    });
    expand();
    await waitForPromises();

    expect(findAddIterationButton().exists()).toBe(false);
  });

  it.each([
    ['hides', false],
    ['shows', true],
  ])(
    '%s Add iteration button when canCreateIteration is %s for manual cadence',
    async (_, canCreateIteration) => {
      await createComponent({
        props: {
          automatic: false,
        },
        canCreateIteration,
        canEditCadence: true,
        queryHandler: jest.fn().mockResolvedValue(queryEmptyResponse),
      });
      expand();
      await waitForPromises();

      expect(findAddIterationButton().exists()).toBe(canCreateIteration);
    },
  );

  describe('duration badge', () => {
    it('does not show duration badge for manual cadence', async () => {
      await createComponent({
        props: {
          automatic: false,
          durationInWeeks: 2,
        },
      });

      expect(findDurationBadge().exists()).toBe(false);
    });

    it('shows duration badge for automatic cadence', async () => {
      await createComponent({
        props: {
          automatic: true,
          durationInWeeks: 2,
        },
      });

      expect(findDurationBadge().exists()).toBe(true);
    });
  });

  const expectIterationItemToHavePeriod = () => {
    iterations.forEach(({ startDate, dueDate }, i) => {
      const containedText = findIterationItemText(i);

      expect(containedText).toContain(getIterationPeriod({ startDate, dueDate }));
    });
  };

  it('shows iteration dates after loading', async () => {
    await createComponent();
    expand();
    await waitForPromises();

    expectIterationItemToHavePeriod();
  });

  it('automatically expands for newly created cadence', async () => {
    await createComponent({
      currentRoute: {
        query: { createdCadenceId: getIdFromGraphQLId(automaticIterationCadence.id) },
      },
    });
    await waitForPromises();

    expectIterationItemToHavePeriod();
  });

  it('loads project iterations for Project namespaceType', async () => {
    await createComponent({
      namespaceType: NAMESPACE_PROJECT,
      query: projectIterationsInCadenceQuery,
    });
    expand();
    await waitForPromises();

    expectIterationItemToHavePeriod();
  });

  it('shows alert on query error', async () => {
    await createComponent({
      queryHandler: jest.fn().mockRejectedValue(queryEmptyResponse),
    });
    await expand();
    await waitForPromises();

    expect(findCrudComponent().props('is-loading')).toBe(undefined);
    expect(wrapper.text()).toContain('Error loading iterations');
  });

  const findLoadMoreButton = () => wrapper.findComponentByTestId('load-more-iterations');

  it('shows the Load more button and fetches the next page with the end cursor on click', async () => {
    const queryHandler = jest
      .fn()
      .mockResolvedValueOnce(querySuccessResponse)
      .mockResolvedValueOnce(nonEmptyGroupIterationsSuccess);
    await createComponent({ queryHandler });
    expand();
    await waitForPromises();

    expect(queryHandler).toHaveBeenNthCalledWith(
      1,
      expect.not.objectContaining({ afterCursor: endCursor }),
    );
    expect(findLoadMoreButton().exists()).toBe(true);

    await findLoadMoreButton().trigger('click');

    expect(queryHandler).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({ afterCursor: endCursor }),
    );
  });

  it('shows a loading state on the Load more button while fetching the next page', async () => {
    const queryHandler = jest
      .fn()
      .mockResolvedValueOnce(querySuccessResponse)
      .mockReturnValueOnce(new Promise(() => {}));
    await createComponent({ queryHandler });
    expand();
    await waitForPromises();

    expect(findLoadMoreButton().props('loading')).toBe(false);

    await findLoadMoreButton().trigger('click');

    expect(findLoadMoreButton().props('loading')).toBe(true);
  });

  it('hides load more button when there is no next page', async () => {
    await createComponent({
      queryHandler: jest.fn().mockResolvedValue({
        data: {
          namespace: {
            ...querySuccessResponse.data.namespace,
            iterations: {
              ...querySuccessResponse.data.namespace.iterations,
              pageInfo: {
                ...querySuccessResponse.data.namespace.iterations.pageInfo,
                hasNextPage: false,
              },
            },
          },
        },
      }),
    });
    expand();
    await waitForPromises();

    expect(findLoadMoreButton().exists()).toBe(false);
  });

  const findPaginationLegend = () => wrapper.findByTestId('iterations-pagination-legend');

  it('shows the iteration count legend regardless of pagination state', async () => {
    await createComponent({
      queryHandler: jest.fn().mockResolvedValue({
        data: {
          namespace: {
            ...querySuccessResponse.data.namespace,
            iterations: {
              ...querySuccessResponse.data.namespace.iterations,
              pageInfo: {
                ...querySuccessResponse.data.namespace.iterations.pageInfo,
                hasNextPage: false,
              },
            },
          },
        },
      }),
    });
    expand();
    await waitForPromises();

    expect(findPaginationLegend().text()).toBe('Showing 2 iterations');
  });

  describe('deleting cadence', () => {
    describe('canEditCadence = false', () => {
      beforeEach(async () => {
        await createComponent({
          canEditCadence: false,
        });
      });

      it('hides dropdown and delete button', () => {
        expect(findDisclosureDropdown().exists()).toBe(false);
      });
    });

    describe('canEditCadence = true', () => {
      beforeEach(() => {
        createComponent({
          canEditCadence: true,
        });
      });

      it('shows delete button', () => {
        expect(findDisclosureDropdown().exists()).toBe(true);
      });

      it('opens confirmation modal to delete cadence', () => {
        wrapper.findByTestId('delete-cadence').trigger('click');

        expect(modalShowSpy).toHaveBeenCalled();
      });

      it('emits delete-cadence event with cadence ID', () => {
        wrapper.findComponent(GlModal).vm.$emit('ok');

        expect(wrapper.emitted('delete-cadence')).toEqual([[automaticIterationCadence.id]]);
      });
    });
  });

  it('hides dropdown when canEditCadence is false', async () => {
    await createComponent({ canEditCadence: false });

    expect(findDisclosureDropdown().exists()).toBe(false);
  });

  it('shows dropdown when canEditCadence is true', async () => {
    await createComponent({ canEditCadence: true });

    expect(findDisclosureDropdown().exists()).toBe(true);
  });

  it.each([
    ['hides', false],
    ['shows', true],
  ])('%s status badge when showStateBadge is %s', async (_, showStateBadge) => {
    await createComponent({ props: { showStateBadge } });
    expand();
    await waitForPromises();

    expect(wrapper.findComponent(TimeboxStatusBadge).exists()).toBe(showStateBadge);
  });
});
