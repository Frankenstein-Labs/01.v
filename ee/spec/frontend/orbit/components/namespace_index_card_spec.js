import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import NamespaceIndexCard from 'ee/orbit/components/namespace_index_card.vue';
import { fetchGraphStatus } from 'ee/orbit/api/orbit_api';
import namespaceDescendantsQuery from 'ee/orbit/graphql/queries/namespace_descendants.query.graphql';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

jest.mock('ee/orbit/api/orbit_api');
jest.mock('~/alert');
jest.mock('~/sentry/sentry_browser_wrapper');

const STATUS_POLLING_INTERVAL_MS = 20000;

describe('NamespaceIndexCard', () => {
  let wrapper;
  let descendantsHandler;

  const namespace = {
    fullPath: 'gitlab-org',
  };

  const graphStatus = {
    projects: { indexed: 2, total_known: 3 },
    domains: [
      {
        name: 'sdlc',
        items: [
          { name: 'Group', count: 4 },
          { name: 'Project', count: 2 },
        ],
      },
      {
        name: 'code',
        items: [{ name: 'File', count: 10 }],
      },
    ],
    indexing: {
      state: 'indexed',
      last_completed_at: '2026-04-15T01:00:00Z',
    },
  };

  const namespaceChildren = {
    descendantGroups: {
      nodes: [{ id: 'gid://gitlab/Group/2', name: 'Frontend', fullPath: 'gitlab-org/frontend' }],
    },
    projects: {
      nodes: [{ id: 'gid://gitlab/Project/3', name: 'GitLab', fullPath: 'gitlab-org/gitlab' }],
    },
  };

  const createWrapper = ({ status = graphStatus } = {}) => {
    descendantsHandler = jest.fn().mockResolvedValue({
      data: {
        group: namespaceChildren,
      },
    });

    const apolloProvider = createMockApollo([[namespaceDescendantsQuery, descendantsHandler]]);
    fetchGraphStatus.mockResolvedValue({ data: status });

    wrapper = shallowMountExtended(NamespaceIndexCard, {
      apolloProvider,
      propsData: {
        namespace,
      },
    });
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  afterEach(() => {
    wrapper?.destroy();
    jest.useRealTimers();
  });

  it('loads graph status for the namespace full path on mount', async () => {
    createWrapper();
    await waitForPromises();

    expect(fetchGraphStatus).toHaveBeenCalledWith('gitlab-org', {
      signal: expect.any(AbortSignal),
    });
    expect(wrapper.vm.graphStatus).toEqual(graphStatus);
  });

  it('aborts the in-flight request before starting a new one', async () => {
    const abortSpy = jest.spyOn(AbortController.prototype, 'abort');
    createWrapper();
    await waitForPromises();
    abortSpy.mockClear();

    wrapper.vm.onFilterSelect('gitlab-org/gitlab');
    await waitForPromises();

    expect(abortSpy).toHaveBeenCalledTimes(1);
  });

  it('aborts the in-flight request on unmount', async () => {
    const abortSpy = jest.spyOn(AbortController.prototype, 'abort');
    createWrapper();
    await waitForPromises();
    abortSpy.mockClear();

    wrapper.vm.$options.beforeUnmount.call(wrapper.vm);

    expect(abortSpy).toHaveBeenCalledTimes(1);
  });

  it('ignores cancellation rejections without reporting an error', async () => {
    createWrapper();
    await waitForPromises();
    fetchGraphStatus.mockRejectedValueOnce({ code: 'ERR_CANCELED' });

    wrapper.vm.onFilterSelect('gitlab-org/gitlab');
    await waitForPromises();

    expect(Sentry.captureException).not.toHaveBeenCalled();
    expect(createAlert).not.toHaveBeenCalled();
  });

  it('polls graph status every 20 seconds', async () => {
    jest.useFakeTimers();
    createWrapper();
    await waitForPromises();
    fetchGraphStatus.mockClear();

    jest.advanceTimersByTime(STATUS_POLLING_INTERVAL_MS);
    await waitForPromises();

    expect(fetchGraphStatus).toHaveBeenCalledWith('gitlab-org', {
      signal: expect.any(AbortSignal),
    });
  });

  it('renders counts from the graph status endpoint response shape', async () => {
    createWrapper();
    await waitForPromises();

    expect(wrapper.vm.entityCount).toBe(16);
    expect(wrapper.vm.projectIndexDisplay).toBe('2 of 3 projects indexed');
    expect(wrapper.vm.lastIndexedDisplay).toBe('Last indexed: 2026-04-15 01:00:00 UTC');
  });

  it('does not render a relationships count', async () => {
    createWrapper();
    await waitForPromises();

    expect(wrapper.text()).not.toContain('relationships');
  });

  it('uses the singular project indexed label', async () => {
    createWrapper({
      status: {
        ...graphStatus,
        projects: { indexed: 1, total_known: 0 },
      },
    });
    await waitForPromises();

    expect(wrapper.vm.projectIndexDisplay).toBe('1 project indexed');
  });

  it('loads graph status for the selected descendant path', async () => {
    createWrapper();
    await waitForPromises();
    fetchGraphStatus.mockClear();

    wrapper.vm.onFilterSelect('gitlab-org/gitlab');
    await waitForPromises();

    expect(fetchGraphStatus).toHaveBeenCalledWith('gitlab-org/gitlab', {
      signal: expect.any(AbortSignal),
    });
  });

  it('reloads the root namespace graph status when the scope filter is reset', async () => {
    createWrapper();
    await waitForPromises();
    wrapper.vm.onFilterSelect('gitlab-org/gitlab');
    await waitForPromises();
    fetchGraphStatus.mockClear();

    wrapper.vm.onFilterClear();
    await waitForPromises();

    expect(wrapper.vm.selectedFilter).toBe('all');
    expect(fetchGraphStatus).toHaveBeenCalledWith('gitlab-org', {
      signal: expect.any(AbortSignal),
    });
  });
});
