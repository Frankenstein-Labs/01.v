import { shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { logError } from '~/lib/logger';
import getAgentsWithMappingStatusQuery from 'ee/workspaces/agent_mapping/graphql/queries/get_agents_with_mapping_status.query.graphql';
import GetAgentsWithAuthorizationStatusQuery from 'ee/workspaces/agent_mapping/components/get_agents_with_mapping_status_query.vue';
import {
  AGENT_MAPPING_STATUS_MAPPED,
  AGENT_MAPPING_STATUS_UNMAPPED,
} from 'ee/workspaces/agent_mapping/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { GET_AGENTS_WITH_MAPPING_STATUS_QUERY_RESULT } from '../../mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/logger');

describe('workspaces/agent_mapping/components/get_agents_with_mapping_status_query.vue', () => {
  let getAgentsWithMappingStatusQueryHandler;
  let wrapper;
  const NAMESPACE = 'gitlab-org/gitlab';

  const buildWrapper = async ({ propsData = {}, scopedSlots = {} } = {}) => {
    const apolloProvider = createMockApollo([
      [getAgentsWithMappingStatusQuery, getAgentsWithMappingStatusQueryHandler],
    ]);

    wrapper = shallowMount(GetAgentsWithAuthorizationStatusQuery, {
      apolloProvider,
      propsData: {
        ...propsData,
      },
      scopedSlots: {
        ...scopedSlots,
      },
    });

    await waitForPromises();
  };
  const buildWrapperWithNamespace = () => buildWrapper({ propsData: { namespace: NAMESPACE } });

  const setupAgentsWithMappingStatusQueryHandler = (responses) => {
    getAgentsWithMappingStatusQueryHandler.mockResolvedValueOnce(responses);
  };

  beforeEach(() => {
    getAgentsWithMappingStatusQueryHandler = jest.fn();
    logError.mockReset();
  });

  it('exposes apollo loading state in the default slot', async () => {
    let loadingState = null;

    await buildWrapper({
      propsData: { namespace: NAMESPACE },
      scopedSlots: {
        default: (props) => {
          loadingState = props.loading;
          return null;
        },
      },
    });

    expect(loadingState).toBe(false);
  });

  describe('when namespace path is provided', () => {
    it('executes getAgentsWithAuthorizationStatusQuery query', async () => {
      await buildWrapperWithNamespace();

      expect(getAgentsWithMappingStatusQueryHandler).toHaveBeenCalledWith({
        namespace: NAMESPACE,
      });
    });

    describe('when the query is successful', () => {
      beforeEach(() => {
        setupAgentsWithMappingStatusQueryHandler(GET_AGENTS_WITH_MAPPING_STATUS_QUERY_RESULT);
      });

      it('triggers result event with the agents list', async () => {
        await buildWrapperWithNamespace();

        expect(wrapper.emitted('result')).toEqual([
          [
            {
              namespaceId: GET_AGENTS_WITH_MAPPING_STATUS_QUERY_RESULT.data.namespace.id,
              agents: [
                {
                  id: 'gid://gitlab/Clusters::Agent/1',
                  name: 'root-group-agent',
                  project: {
                    id: 'gid://gitlab/Project/101',
                    name: 'GitLab Agent One',
                  },
                  mappingStatus: AGENT_MAPPING_STATUS_MAPPED,
                  connections: {
                    nodes: [
                      {
                        connectedAt: '2023-04-29T18:24:34Z',
                      },
                    ],
                  },
                },
                {
                  id: 'gid://gitlab/Clusters::Agent/2',
                  name: 'root-group-agent-2',
                  project: {
                    name: 'GitLab Agent Two',
                    id: 'gid://gitlab/Project/102',
                  },
                  mappingStatus: AGENT_MAPPING_STATUS_UNMAPPED,
                  connections: {
                    nodes: [
                      {
                        connectedAt: '2023-04-29T18:24:34Z',
                      },
                    ],
                  },
                },
              ],
            },
          ],
        ]);
      });
    });

    describe('when the query fails', () => {
      const error = new Error();

      beforeEach(() => {
        getAgentsWithMappingStatusQueryHandler.mockReset();
        getAgentsWithMappingStatusQueryHandler.mockRejectedValueOnce(error);
      });

      it('logs the error', async () => {
        expect(logError).not.toHaveBeenCalled();

        await buildWrapperWithNamespace();

        expect(logError).toHaveBeenCalledWith(error);
      });

      it('does not emit result event', async () => {
        await buildWrapperWithNamespace();

        expect(wrapper.emitted('result')).toBe(undefined);
      });

      it('emits error event', async () => {
        await buildWrapperWithNamespace();

        expect(wrapper.emitted('error')).toEqual([[{ error }]]);
      });
    });
  });

  describe('when namespace path is not provided', () => {
    it('does not getAgentsWithAuthorizationStatusQuery query', async () => {
      setupAgentsWithMappingStatusQueryHandler(GET_AGENTS_WITH_MAPPING_STATUS_QUERY_RESULT);
      await buildWrapper();

      expect(getAgentsWithMappingStatusQueryHandler).not.toHaveBeenCalled();
    });
  });
});
